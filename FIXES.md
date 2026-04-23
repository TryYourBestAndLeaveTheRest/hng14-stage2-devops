# FIXES

| File | Line | Problem | Fix |
|---|---:|---|---|
| api/main.py | 14 | Redis host was hardcoded to localhost, which fails in containers. | Switched to env-driven Redis client config (`REDIS_HOST`, `REDIS_PORT`, `REDIS_DB`, `REDIS_PASSWORD`) with `decode_responses=True`. |
| api/main.py | 31 | API queued jobs to a singular key (`job`) with brittle naming. | Standardized queue key to `jobs` for API/worker consistency. |
| api/main.py | 39 | Not-found response returned 200 with an error payload. | Changed to `HTTPException(status_code=404, detail="not found")`. |
| api/main.py | 23 | No API health endpoint for orchestration checks. | Added `/health` route that verifies Redis connectivity with `PING`. |
| worker/worker.py | 12 | Worker Redis host was hardcoded to localhost. | Switched worker Redis connection to environment variables. |
| worker/worker.py | 38 | Worker consumed from key `job`, inconsistent with API queue. | Updated consumer queue key to `jobs`. |
| worker/worker.py | 23 | Worker had no graceful shutdown handling for SIGTERM/SIGINT. | Added signal handlers and controlled loop exit for clean stop. |
| frontend/app.js | 6 | Frontend API URL was hardcoded to localhost. | Replaced with `API_URL` env variable fallback to service DNS URL. |
| frontend/app.js | 7 | Frontend port was hardcoded to 3000. | Added `PORT` environment variable support. |
| frontend/app.js | 12 | Frontend lacked health endpoint for healthcheck probes. | Added `/health` route returning 200 status JSON. |
| api/.env | 1 | Secret-bearing `.env` file was committed to repository. | Removed `api/.env`, added root `.gitignore` to block `.env*` files, and introduced `.env.example` placeholders. |
| docker-compose.yml | 3 | No runtime orchestration existed for all services. | Added full Compose stack with named internal network, health-gated startup, and Redis not exposed to host. |
| docker-compose.yml | 15 | No resource limits for Redis service. | Added CPU and memory limits from environment variables. |
| docker-compose.yml | 39 | No resource limits for API service. | Added CPU and memory limits from environment variables. |
| docker-compose.yml | 58 | No resource limits for worker service. | Added CPU and memory limits from environment variables. |
| docker-compose.yml | 80 | No resource limits for frontend service. | Added CPU and memory limits from environment variables. |
| .github/workflows/ci-cd.yml | 53 | No CI stage gating existed. | Added strict `needs` chain in required order: lint -> test -> build -> security scan -> integration test -> deploy. |
| .github/workflows/ci-cd.yml | 121 | No security scanning for produced images. | Added Trivy image scans with CRITICAL failure gate and SARIF artifacts. |
| .github/workflows/ci-cd.yml | 161 | No end-to-end validation of full stack behavior. | Added integration stage to start stack, submit job via frontend, poll status, assert completion, and always tear down. |
| scripts/rolling_update.sh | 1 | No deployment rollback-safe update logic existed. | Added scripted rolling update that keeps old container running unless new one passes health check within 60 seconds. |
