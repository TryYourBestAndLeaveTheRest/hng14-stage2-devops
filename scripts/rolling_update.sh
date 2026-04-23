#!/usr/bin/env bash
set -Eeuo pipefail

# Enable debug logs if DEBUG=1
[[ "${DEBUG:-0}" == "1" ]] && set -x

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
  log "ERROR: $*"
  exit 1
}

# ---- Config ----
IMAGE_BASE="${IMAGE_BASE:-localhost:5000/api}"
NEW_IMAGE_TAG="${NEW_IMAGE_TAG:-${GITHUB_SHA:-latest}}"
OLD_IMAGE_TAG="${OLD_IMAGE_TAG:-latest}"
OLD_NAME="${OLD_NAME:-api_current}"
NEW_NAME="${NEW_NAME:-api_candidate}"
NETWORK_NAME="${NETWORK_NAME:-jobapp_internal}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:18000/health}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"

# ---- Validate required env vars ----
: "${REDIS_HOST:?REDIS_HOST is required}"
: "${REDIS_PORT:?REDIS_PORT is required}"
: "${REDIS_DB:?REDIS_DB is required}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD is required}"

log "Using image: ${IMAGE_BASE}:${NEW_IMAGE_TAG}"

# ---- Ensure network exists ----
if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
  log "Creating network ${NETWORK_NAME}"
  docker network create "${NETWORK_NAME}" || die "Failed to create network"
fi

# ---- Pull image explicitly ----
log "Pulling image..."
docker pull "${IMAGE_BASE}:${NEW_IMAGE_TAG}" || die "Failed to pull image"

# ---- Ensure old container exists ----
if ! docker ps --format '{{.Names}}' | grep -qx "${OLD_NAME}"; then
  log "Old container not running. Starting fallback container..."

  docker rm -f "${OLD_NAME}" >/dev/null 2>&1 || true

  docker run -d \
    --name "${OLD_NAME}" \
    --network "${NETWORK_NAME}" \
    -e REDIS_HOST="${REDIS_HOST}" \
    -e REDIS_PORT="${REDIS_PORT}" \
    -e REDIS_DB="${REDIS_DB}" \
    -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
    -p 8000:8000 \
    "${IMAGE_BASE}:${OLD_IMAGE_TAG}" \
    || die "Failed to start old container"
fi

# ---- Clean up any previous candidate ----
docker rm -f "${NEW_NAME}" >/dev/null 2>&1 || true

# ---- Start new container ----
log "Starting new container..."

docker run -d \
  --name "${NEW_NAME}" \
  --network "${NETWORK_NAME}" \
  -e REDIS_HOST="${REDIS_HOST}" \
  -e REDIS_PORT="${REDIS_PORT}" \
  -e REDIS_DB="${REDIS_DB}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -p 18000:8000 \
  "${IMAGE_BASE}:${NEW_IMAGE_TAG}" \
  || die "docker run failed (check port, network, or image)"

# ---- Health check ----
log "Waiting for health check at ${HEALTH_URL}..."

passed=0
for ((i=0; i<TIMEOUT_SECONDS; i++)); do
  if curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
    passed=1
    break
  fi
  sleep 1
done

if [[ "${passed}" -ne 1 ]]; then
  log "Health check failed. Showing container logs:"
  docker logs "${NEW_NAME}" || true

  docker rm -f "${NEW_NAME}" >/dev/null 2>&1 || true
  die "New container failed health check within ${TIMEOUT_SECONDS}s"
fi

# ---- Safe swap ----
log "Swapping containers..."

docker rename "${OLD_NAME}" "${OLD_NAME}_backup" || true

docker rename "${NEW_NAME}" "${OLD_NAME}" \
  || {
    log "Rename failed. Attempting rollback..."
    docker rename "${OLD_NAME}_backup" "${OLD_NAME}" || true
    die "Failed to promote new container"
  }

docker rm -f "${OLD_NAME}_backup" >/dev/null 2>&1 || true

log "✅ Rolling update completed successfully."