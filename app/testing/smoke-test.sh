#!/bin/sh
set -eu

IMAGE_NAME="${1:?Usage: smoke-test.sh <image_name>}"

CONTAINER_NAME="${CONTAINER_NAME:-hello-world-api-smoke}"
HOST_PORT="${HOST_PORT:-18080}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
SMOKE_PATH="${SMOKE_PATH:-/health}"
EXPECTED_TEXT="${EXPECTED_TEXT:-}"
MAX_RETRIES="${MAX_RETRIES:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

echo "=========================================="
echo "Smoke Test Configuration"
echo "=========================================="
echo "Image: ${IMAGE_NAME}"
echo "Container name: ${CONTAINER_NAME}"
echo "Host port: ${HOST_PORT}"
echo "Container port: ${CONTAINER_PORT}"
echo "Health path: ${SMOKE_PATH}"
echo "Expected text: ${EXPECTED_TEXT:-(any response)}"
echo "Max retries: ${MAX_RETRIES}"
echo "Retry interval: ${SLEEP_SECONDS}s"
echo "=========================================="

cleanup() {
    echo "Cleaning up container..."
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Remove any existing container
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

# Start container
echo "Starting container..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    "${IMAGE_NAME}" \
    >/dev/null 2>&1

# Give container time to start
echo "Waiting for container to initialize..."
sleep 2

# Get container details for debugging
echo ""
echo "Container Details:"
docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.ID}}\t{{.Status}}\t{{.Ports}}"

# Try to get container IP (useful for debugging networking issues)
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CONTAINER_NAME}" 2>/dev/null || echo "")
if [ -n "${CONTAINER_IP}" ]; then
    echo "Container IP: ${CONTAINER_IP}"
    echo "You can also test: curl http://${CONTAINER_IP}:${CONTAINER_PORT}${SMOKE_PATH}"
fi

echo ""
echo "=========================================="
echo "Health Check: Polling ${SMOKE_PATH}"
echo "=========================================="

# Poll the health endpoint
i=1
while [ "$i" -le "${MAX_RETRIES}" ]; do
    echo "Attempt $i/${MAX_RETRIES}..."
    
    # Try to curl the endpoint
    # Use verbose mode to see if connection is successful
    response="$(curl -s -w "\n%{http_code}" "http://127.0.0.1:${HOST_PORT}${SMOKE_PATH}" 2>/dev/null || echo -e "\n000")"
    
    # Extract HTTP status code (last line)
    http_code="$(printf '%s' "${response}" | tail -1)"
    
    # Extract response body (all lines except last)
    body="$(printf '%s' "${response}" | sed '$d')"
    
    echo "  HTTP Status: ${http_code}"
    
    # Check if we got a successful response
    if [ "${http_code}" -eq 200 ] 2>/dev/null; then
        echo "  Response: ${body}"
        
        # If no expected text specified, any 200 is success
        if [ -z "${EXPECTED_TEXT}" ]; then
            echo ""
            echo "=========================================="
            echo "✓ SMOKE TEST PASSED"
            echo "=========================================="
            echo "Endpoint responded successfully (HTTP 200)"
            echo "${body}"
            exit 0
        fi
        
        # If expected text is specified, check for it
        if printf '%s' "${body}" | grep -F "${EXPECTED_TEXT}" >/dev/null 2>&1; then
            echo ""
            echo "=========================================="
            echo "✓ SMOKE TEST PASSED"
            echo "=========================================="
            echo "Expected text found in response"
            echo "${body}"
            exit 0
        else
            echo "  Expected text not found, continuing..."
        fi
    else
        # Connection failed or non-200 status
        if [ -z "${body}" ]; then
            echo "  Unable to connect (curl failed)"
        else
            echo "  Unexpected status code: ${http_code}"
        fi
    fi
    
    sleep "${SLEEP_SECONDS}"
    i=$((i + 1))
done

echo ""
echo "=========================================="
echo "✗ SMOKE TEST FAILED"
echo "=========================================="
echo "Application did not become healthy after ${MAX_RETRIES} attempts"
echo ""
echo "Debugging Information:"
echo "=========================================="

# Check if container is still running
CONTAINER_STATUS=$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")
echo "Container running: ${CONTAINER_STATUS}"

# Show container logs
echo ""
echo "Container Logs:"
echo "---"
docker logs "${CONTAINER_NAME}" 2>/dev/null || echo "(no logs available)"
echo "---"

# Try to diagnose networking issues
echo ""
echo "Network Diagnostics:"
echo "---"

# Check if curl can resolve localhost
if command -v curl >/dev/null 2>&1; then
    echo "Testing localhost resolution..."
    curl -v "http://127.0.0.1:${HOST_PORT}${SMOKE_PATH}" 2>&1 | head -20 || true
fi

# Show port mapping
echo ""
echo "Port Mapping:"
docker port "${CONTAINER_NAME}" 2>/dev/null || echo "(no port mapping)"

echo "---"
echo ""
echo "Possible causes:"
echo "1. Application inside container failed to start"
echo "2. Application is listening on wrong port (should be ${CONTAINER_PORT})"
echo "3. Docker networking issue (check container logs above)"
echo "4. Health endpoint path is incorrect (check --health-path)"
echo "5. In CI/Docker-in-Docker: networking isolation issue"
echo ""

exit 1