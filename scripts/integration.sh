#!/bin/bash
set -e

# Use environment variable or default
PORT=${FRONTEND_PORT:-3000}

# Wait for service
echo "Waiting for frontend on port $PORT..."
until curl -sf http://127.0.0.1:$PORT/health; do
  sleep 2
done

echo "Submitting job..."
RESPONSE=$(curl -sf -X POST "http://127.0.0.1:$PORT/submit")
echo "Submit response: $RESPONSE"

JOB_ID=$(echo "$RESPONSE" | jq -r '.job_id')

if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
  echo "Failed to create job"
  exit 1
fi

echo "Polling job: $JOB_ID"

STATUS="queued"
for _ in $(seq 1 30); do
  RESPONSE=$(curl -sf "http://127.0.0.1:$PORT/status/${JOB_ID}")
  echo "Status response: $RESPONSE"

  STATUS=$(echo "$RESPONSE" | jq -r '.status')

  if [[ "$STATUS" == "completed" ]]; then
    break
  fi

  sleep 2
done

if [[ "$STATUS" != "completed" ]]; then
  echo "Job did not complete. Final status: $STATUS"
  exit 1
fi

echo "Integration test passed!"
