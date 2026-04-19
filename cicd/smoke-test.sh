#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-hello-world-api:local}"
CONTAINER_NAME="hello-world-api-smoke"
HOST_PORT="${HOST_PORT:-8080}"
APP_URL="http://localhost:${HOST_PORT}/health"

echo "Starting smoke test for image: ${IMAGE_NAME}"

# Cleanup from previous runs if needed
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Start container
docker run -d \
--name "${CONTAINER_NAME}" \
-p "${HOST_PORT}:8080" \
"${IMAGE_NAME}" >/dev/null

cleanup() {
    echo "Cleaning up container..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Waiting for application to become ready..."

for i in {1..20}; do
    response="$(curl -s "${APP_URL}" || true)"
    if [ "${response}" = "OK" ]; then
        echo "Smoke test passed: /health returned OK"
        exit 0
    fi
    
    echo "Attempt ${i}/20: app not ready yet"
    sleep 2
done

echo "Smoke test failed: /health did not return OK"
docker logs "${CONTAINER_NAME}" || true
exit 1