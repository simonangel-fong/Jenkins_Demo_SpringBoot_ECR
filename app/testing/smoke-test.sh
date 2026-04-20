#!/bin/sh
set -eu

IMAGE_NAME="${1:?Usage: smoke-test.sh <image_name>}"

CONTAINER_NAME="${CONTAINER_NAME:-hello-world-api-smoke}"
HOST_PORT="${HOST_PORT:-18080}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
SMOKE_PATH="${SMOKE_PATH:-/actuator/health}"
APP_URL="http://127.0.0.1:${HOST_PORT}${SMOKE_PATH}"
EXPECTED_TEXT="${EXPECTED_TEXT:-}"
MAX_RETRIES="${MAX_RETRIES:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

echo "Starting smoke test for image: ${IMAGE_NAME}"
echo "Container name: ${CONTAINER_NAME}"
echo "App URL: ${APP_URL}"

cleanup() {
    echo "Cleaning up container..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d \
--name "${CONTAINER_NAME}" \
-p "${HOST_PORT}:${CONTAINER_PORT}" \
"${IMAGE_NAME}" >/dev/null

echo "Waiting for application to become ready..."

i=1
while [ "$i" -le "${MAX_RETRIES}" ]; do
    response="$(curl -fsS "${APP_URL}" 2>/dev/null || true)"
    
    if [ -n "${response}" ]; then
        if [ -z "${EXPECTED_TEXT}" ]; then
            echo "Smoke test passed: endpoint responded successfully"
            echo "${response}"
            exit 0
        fi
        
        if printf '%s' "${response}" | grep -F "${EXPECTED_TEXT}" >/dev/null 2>&1; then
            echo "Smoke test passed: expected text found"
            echo "${response}"
            exit 0
        fi
    fi
    
    echo "Attempt ${i}/${MAX_RETRIES}: application not ready yet"
    sleep "${SLEEP_SECONDS}"
    i=$((i + 1))
done

echo "Smoke test failed: application did not become healthy"
echo "Container logs:"
docker logs "${CONTAINER_NAME}" || true
exit 1