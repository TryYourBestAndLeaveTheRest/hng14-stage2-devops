# hng14-stage2-devops

Production-ready containerized microservices job processor with CI/CD.

## Services

- `frontend` (Node.js/Express): submit and check jobs
- `api` (FastAPI): create jobs and return status
- `worker` (Python): consume queue and process jobs
- `redis` (queue + state store)

## Prerequisites

- Docker 24+
- Docker Compose v2+
- Git
- Python 3.12+ (optional for local lint/test)
- Node.js 22+ (optional for local lint)

## Quick Start (Clean Machine)

1. Clone your fork and enter project directory.

```bash
git clone <YOUR_FORK_URL>
cd hng14-stage2-devops
```

2. Prepare environment file.

```bash
cp .env.example .env
```

3. Build and start full stack.

```bash
docker compose up -d --build
```

4. Verify containers are healthy.

```bash
docker compose ps
```

Successful startup looks like:
- `redis`, `api`, `worker`, and `frontend` are running
- health status is `healthy` for services with health checks

5. Submit a job through frontend.

```bash
curl -s -X POST http://127.0.0.1:3000/submit
```

Expected response:

```json
{"job_id":"<uuid>"}
```

6. Poll status until completion.

```bash
curl -s http://127.0.0.1:3000/status/<job_id>
```

Expected final status:

```json
{"job_id":"<uuid>","status":"completed"}
```

7. Stop and clean up.

```bash
docker compose down -v --remove-orphans
```

## Environment Variables

All runtime configuration is driven by environment variables in `.env`.

```dotenv
API_PORT=8000
FRONTEND_PORT=3000
API_URL=http://api:8000
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=CHANGE_ME
INTERNAL_NETWORK_NAME=jobapp_internal
REDIS_CPU_LIMIT=0.50
REDIS_MEM_LIMIT=256m
API_CPU_LIMIT=0.50
API_MEM_LIMIT=256m
WORKER_CPU_LIMIT=0.50
WORKER_MEM_LIMIT=256m
FRONTEND_CPU_LIMIT=0.50
FRONTEND_MEM_LIMIT=256m
```

## Local Lint and Unit Tests

Python lint and tests:

```bash
pip install -r api/requirements.txt -r api/requirements-dev.txt
flake8 api worker
pytest api/tests --cov=api --cov-report=term-missing --cov-report=xml
```

Frontend lint:

```bash
cd frontend
npm install
npm run lint
```

## CI/CD Pipeline

Workflow file: `.github/workflows/ci-cd.yml`

Execution order is strictly enforced:
1. `lint`
2. `test`
3. `build`
4. `security scan`
5. `integration test`
6. `deploy` (pushes to `main` only)

### Stage Summary

- **Lint**: `flake8`, `eslint`, and `hadolint`
- **Test**: API unit tests (Redis mocked) + coverage artifact upload
- **Build**: Build API/worker/frontend images, tag with `${GITHUB_SHA}` and `latest`, push to local registry service
- **Security scan**: Trivy image scan, fail on CRITICAL, upload SARIF artifacts
- **Integration test**: Start full stack, submit job via frontend, poll to `completed`, always tear down
- **Deploy**: Scripted rolling update with 60s health gate and rollback-safe behavior

## Deployment Rollout Logic

Deploy uses `scripts/rolling_update.sh`:
- Starts candidate container on a temporary port
- Waits up to 60 seconds for health endpoint success
- If unhealthy, aborts and keeps old container running
- If healthy, swaps old container for new one

## Required Deliverables Included

- `Dockerfile` for each service
- `docker-compose.yml`
- `.github/workflows/ci-cd.yml`
- `.env.example`
- `FIXES.md`
- Updated application code and tests
