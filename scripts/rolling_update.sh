#!/usr/bin/env bash
set -euo pipefail

IMAGE_BASE="${IMAGE_BASE:-localhost:5000/api}"
NEW_IMAGE_TAG="${NEW_IMAGE_TAG:-${GITHUB_SHA:-latest}}"
OLD_IMAGE_TAG="${OLD_IMAGE_TAG:-latest}"
OLD_NAME="${OLD_NAME:-api_current}"
NEW_NAME="${NEW_NAME:-api_candidate}"
NETWORK_NAME="${NETWORK_NAME:-jobapp_internal}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:18000/health}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"

# Ensure there is an old container to keep running if update fails.
if ! docker ps --format '{{.Names}}' | grep -qx "${OLD_NAME}"; then
  docker rm -f "${OLD_NAME}" >/dev/null 2>&1 || true
  docker run -d \
    --name "${OLD_NAME}" \
    --network "${NETWORK_NAME}" \
    -e REDIS_HOST="${REDIS_HOST}" \
    -e REDIS_PORT="${REDIS_PORT}" \
    -e REDIS_DB="${REDIS_DB}" \
    -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
    -p 8000:8000 \
    "${IMAGE_BASE}:${OLD_IMAGE_TAG}" >/dev/null
fi

docker rm -f "${NEW_NAME}" >/dev/null 2>&1 || true
docker run -d \
  --name "${NEW_NAME}" \
  --network "${NETWORK_NAME}" \
  -e REDIS_HOST="${REDIS_HOST}" \
  -e REDIS_PORT="${REDIS_PORT}" \
  -e REDIS_DB="${REDIS_DB}" \
  -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
  -p 18000:8000 \
  "${IMAGE_BASE}:${NEW_IMAGE_TAG}" >/dev/null

passed=0
for _ in $(seq 1 "${TIMEOUT_SECONDS}"); do
  if curl -fsS "${HEALTH_URL}" >/dev/null; then
    passed=1
    break
  fi
  sleep 1
done

if [[ "${passed}" -ne 1 ]]; then
  docker rm -f "${NEW_NAME}" >/dev/null 2>&1 || true
  echo "New container failed health check within ${TIMEOUT_SECONDS}s. Old container is still running."
  exit 1
fi

docker rm -f "${OLD_NAME}" >/dev/null 2>&1 || true
docker rename "${NEW_NAME}" "${OLD_NAME}"

echo "Rolling update completed successfully."
