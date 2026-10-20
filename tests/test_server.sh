#!/bin/sh
# @file tests/test_server.sh
# @description Integration tests for the generated HTTP and MCP SSE server.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")" && pwd)/test_helpers.sh"

# cleanup_server_test removes temporary generated server artifacts.
# @param none
# @return Returns 0.
cleanup_server_test() {
	rm -rf tests/out
}
trap cleanup_server_test EXIT INT TERM

# Generate the Server
rm -rf tests/out
mkdir -p tests/out
./bin/cdd-sh from_openapi to_sdk_cli -i tests/test.json -o tests/out
./bin/cdd-sh from_openapi to_server --ephemeral --seed -i tests/test.json -o tests/out

if [ ! -f tests/out/src/server.sh ]; then
	echo "FAIL: server.sh not generated"
	exit 1
fi

cat <<'MOCK' >tests/out/src/server_mock_test.sh
#!/bin/sh
set -e
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/../../.." && pwd)/tests/test_helpers.sh"

PORT=$(allocate_free_port 18101)
SERVER_PID=""
trap 'cleanup_server_pid "${SERVER_PID:-}" "${PORT:-}"' EXIT INT TERM

PORT="${PORT}" sh tests/out/src/server.sh >/dev/null 2>&1 &
SERVER_PID=$!
wait_for_port "${PORT}" 50

fail() {
  echo "FAIL: $1"
  exit 1
}

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"initialize"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "protocolVersion"; then
  fail "Server initialize: $resp"
fi

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' --max-time 2 || true)

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "get_users"; then
  fail "Server tools/list: $resp"
fi

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Authorization: Bearer my-test-token" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' --max-time 2 || true)
if ! echo "$resp" | grep -q "content" && ! echo "$resp" | grep -q "isError"; then
  fail "Server tools/call: $resp"
fi

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":4,"method":"resources/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "resources"; then
  fail "Server resources/list: $resp"
fi

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":5,"method":"roots/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "roots"; then
  fail "Server roots/list: $resp"
fi

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":6,"method":"ping"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "result"; then
  fail "Server ping: $resp"
fi

curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"notifications/message","params":{"level":"info","data":"test log"}}' --max-time 2 >/dev/null || true

echo "Server generation test passed!"
MOCK

sh tests/out/src/server_mock_test.sh || exit 1

cat <<'MOCK_STUB' >tests/out/src/server_stub_test.sh
#!/bin/sh
set -e
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/../../.." && pwd)/tests/test_helpers.sh"

PORT=$(allocate_free_port 18102)
SERVER_PID=""
trap 'cleanup_server_pid "${SERVER_PID:-}" "${PORT:-}"' EXIT INT TERM

PORT="${PORT}" DATABASE_URL="" sh tests/out/src/server.sh >/dev/null 2>&1 &
SERVER_PID=$!
wait_for_port "${PORT}" 50

fail() {
  echo "FAIL STUB: $1"
  exit 1
}

resp=$(curl -s -X POST "http://127.0.0.1:${PORT}/mcp/message" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' --max-time 2 || true)
if ! echo "$resp" | grep -q "\"isError\": true"; then
  fail "Server stub tools/call should return error: $resp"
fi

echo "Server STUB generation test passed!"
MOCK_STUB

sh tests/out/src/server_stub_test.sh || exit 1

cat <<'MOCK_UNIT' >tests/out/src/server_unit_test.sh
#!/bin/sh
set -e

export DATABASE_URL=""
res_stub=$(CDD_SSE_PATH="/mcp/message" CDD_SSE_METHOD="POST" CDD_SSE_AUTH="" CDD_SSE_BODY='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' sh tests/out/src/server.sh --handler || true)
if ! echo "$res_stub" | grep -q "isError\": true"; then
  echo "FAIL: Stub DAO DI injection failed."
  exit 1
fi

export DATABASE_URL=$(mktemp -d "${TMPDIR:-/tmp}/cdd_test_db.XXXXXX")
res_concrete=$(CDD_SSE_PATH="/mcp/message" CDD_SSE_METHOD="POST" CDD_SSE_AUTH="" CDD_SSE_BODY='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' sh tests/out/src/server.sh --handler || true)
if echo "$res_concrete" | grep -q "isError\": true"; then
  echo "FAIL: Concrete DAO DI injection failed."
  exit 1
fi
rm -rf "$DATABASE_URL"

echo "Server UNIT tests passed!"
MOCK_UNIT

sh tests/out/src/server_unit_test.sh || exit 1

cat <<'MOCK_SEED' >tests/out/src/server_seed_test.sh
#!/bin/sh
set -e
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/../../.." && pwd)/tests/test_helpers.sh"

export DATABASE_URL=$(mktemp -d "${TMPDIR:-/tmp}/cdd_test_db.XXXXXX")

PORT=$(allocate_free_port 18105)
PORT="${PORT}" CDD_EPHEMERAL="1" CDD_SEED="1" sh tests/out/src/server.sh --seed --ephemeral --handler </dev/null >/dev/null 2>&1 || true

GENERATED_DB_DIR=$(ls -td "${TMPDIR:-/tmp}"/cdd_ephemeral_db_* /tmp/cdd_ephemeral_db_* 2>/dev/null | head -n 1)

if [ -z "$GENERATED_DB_DIR" ] || [ ! -f "$GENERATED_DB_DIR/seed.sql" ]; then
  echo "FAIL: Seed script was not generated in $GENERATED_DB_DIR"
  exit 1
fi

if ! grep -q "INSERT INTO users" "$GENERATED_DB_DIR/seed.sql"; then
  echo "FAIL: Seed script missing INSERT logic"
  exit 1
fi

if ! grep -q "CREATE TABLE IF NOT EXISTS user" "$GENERATED_DB_DIR/schema.sql"; then
  echo "FAIL: Schema script missing dynamic table creation from OpenAPI components.schemas"
  exit 1
fi

rm -rf "$GENERATED_DB_DIR"
rm -rf "$DATABASE_URL"

echo "Server SEED generation test passed!"
MOCK_SEED

sh tests/out/src/server_seed_test.sh || exit 1
