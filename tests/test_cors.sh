#!/bin/sh
# @file tests/test_cors.sh
# @description Tests HTTP OPTIONS preflight CORS headers on the generated server.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")" && pwd)/test_helpers.sh"

echo "Testing Server CORS functionality..."

SPEC_FILE="../petstore.json"
if [ ! -f "${SPEC_FILE}" ]; then
	SPEC_FILE="tests/test.json"
fi

CORS_PORT=$(allocate_free_port 18117)
SERVER_PID=""

# cleanup_cors terminates the CORS test server and removes temporary directories.
# @param none
# @return Returns 0.
cleanup_cors() {
	cleanup_server_pid "${SERVER_PID:-}" "${CORS_PORT:-}"
	rm -rf temp-cors
}
trap cleanup_cors EXIT INT TERM

rm -rf temp-cors
mkdir -p temp-cors

./bin/cdd-sh from_openapi to_server -i "${SPEC_FILE}" -o temp-cors/server

PORT="${CORS_PORT}" sh temp-cors/server/src/server.sh --ephemeral </dev/null >/dev/null 2>&1 &
SERVER_PID=$!
wait_for_port "${CORS_PORT}" 50

res=$(curl -s -v -X OPTIONS "http://127.0.0.1:${CORS_PORT}/users" 2>&1)
if ! printf "%s" "$res" | grep -qi "Access-Control-Allow-Origin: \*"; then
	echo "FAIL: OPTIONS preflight did not return CORS headers"
	exit 1
fi

echo "CORS tests passed!"
