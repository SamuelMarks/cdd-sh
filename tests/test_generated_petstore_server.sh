#!/bin/sh
# @file tests/test_generated_petstore_server.sh
# @description Generates and validates composable Petstore servers and SDKs for Swagger 2.0 and OpenAPI 3.x.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")" && pwd)/test_helpers.sh"

TYPE="$1"
SPEC="$2"

if [ ! -f "$SPEC" ]; then
	echo "Warning: $SPEC not found, skipping."
	exit 0
fi

OUT_SERVER="temp-server-$TYPE"
OUT_SDK="temp-sdk-$TYPE"
PORT=$(allocate_free_port 18111)
SERVER_PID=""

# cleanup_petstore_srv terminates the generated Petstore server and removes temporary directories.
# @param none
# @return Returns 0.
cleanup_petstore_srv() {
	cleanup_server_pid "${SERVER_PID:-}" "${PORT:-}"
	rm -rf "$OUT_SERVER" "$OUT_SDK"
}
trap cleanup_petstore_srv EXIT INT TERM

rm -rf "$OUT_SERVER" "$OUT_SDK"

echo "Generating Server for $TYPE..."
./bin/cdd-sh from_openapi to_server -i "$SPEC" -o "$OUT_SERVER"

echo "Generating SDK for $TYPE..."
./bin/cdd-sh from_openapi to_sdk -i "$SPEC" -o "$OUT_SDK"

# Assert composability
if [ ! -d "$OUT_SERVER/src/models" ] || [ ! -d "$OUT_SERVER/src/routes" ] || [ ! -d "$OUT_SERVER/src/mocks" ] || [ ! -d "$OUT_SERVER/tests" ]; then
	echo "FAIL: Expected server composable directories (models, routes, mocks, tests) not found!"
	exit 1
fi

echo "Starting generated server on port $PORT..."
PORT=$PORT sh "$OUT_SERVER/src/server.sh" --ephemeral </dev/null >/dev/null 2>&1 &
SERVER_PID=$!
wait_for_port "$PORT" 50

export BASE_URL="http://127.0.0.1:$PORT"

echo "Running generated server tests..."
if ! sh "$OUT_SERVER/tests/run_all.sh"; then
	echo "FAIL: Generated server tests failed"
	exit 1
fi

echo "Testing SDK against generated server ($BASE_URL)..."
# shellcheck disable=SC1091
. "$OUT_SDK/src/routes.sh"

res=$(findPetsByStatus "available" 2>&1 || echo "ERROR")
if ! printf "%s" "$res" | jq -e 'type == "object" or type == "array"' >/dev/null 2>&1; then
	echo "FAIL: SDK findPetsByStatus against generated server did not return valid JSON object/array (returned: $res)"
	exit 1
fi

echo "$TYPE generated server SDK test passed!"
