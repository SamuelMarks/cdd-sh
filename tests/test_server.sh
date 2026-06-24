#!/bin/sh
set -eu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	THIS_FILE="${BASH_SOURCE[0]}"
	set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
	eval 'THIS_FILE="${(%):-%x}"'
	set -o pipefail
else
	THIS_FILE="${0}"
fi

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

run_server() {
  PORT="8101" sh tests/out/src/server.sh
}

run_server >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2 # Give server more time to start up

fail() {
  echo "FAIL: $1"
  kill $SERVER_PID 2>/dev/null || true
  pkill -f cdd_sse_ 2>/dev/null || true
  kill $(lsof -t -i:8101) 2>/dev/null || true
  exit 1
}

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"initialize"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "protocolVersion"; then
  fail "Server initialize: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' --max-time 2 || true)
# notifications return empty response usually, just ensure it doesn't crash
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "get_users"; then
  fail "Server tools/list: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Authorization: Bearer my-test-token" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' --max-time 2 || true)
if ! echo "$resp" | grep -q "content" && ! echo "$resp" | grep -q "isError"; then
  fail "Server tools/call: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":4,"method":"resources/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "resources"; then
  fail "Server resources/list: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":5,"method":"roots/list"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "roots"; then
  fail "Server roots/list: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":6,"method":"ping"}' --max-time 2 || true)
if ! echo "$resp" | grep -q "result"; then
  fail "Server ping: $resp"
fi
sleep 0.5

curl -s -X POST http://localhost:8101/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"notifications/message","params":{"level":"info","data":"test log"}}' --max-time 2 >/dev/null || true

echo "Server generation test passed!"
kill $SERVER_PID 2>/dev/null || true
pkill -f cdd_sse_ 2>/dev/null || true
kill $(lsof -t -i:8101) 2>/dev/null || true
MOCK

sh tests/out/src/server_mock_test.sh || exit 1

cat <<'MOCK_STUB' >tests/out/src/server_stub_test.sh
#!/bin/sh
set -e

run_server() {
  PORT="8102" DATABASE_URL="" sh tests/out/src/server.sh
}

run_server >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

fail() {
  echo "FAIL STUB: $1"
  kill $SERVER_PID 2>/dev/null || true
  pkill -f cdd_sse_ 2>/dev/null || true
  exit 1
}

resp=$(curl -s -X POST http://localhost:8102/mcp/message -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_users","arguments":{}}}' --max-time 2 || true)
if ! echo "$resp" | grep -q "\"isError\": true"; then
  fail "Server stub tools/call should return error: $resp"
fi

echo "Server STUB generation test passed!"
kill $SERVER_PID 2>/dev/null || true
pkill -f cdd_sse_ 2>/dev/null || true
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

export DATABASE_URL="/tmp/cdd_test_db_$$"
mkdir -p "$DATABASE_URL"
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

export DATABASE_URL="/tmp/cdd_test_db_$$"
mkdir -p "$DATABASE_URL"

# Call the server with --seed




PORT="8105" CDD_EPHEMERAL="1" CDD_SEED="1" sh tests/out/src/server.sh --seed --ephemeral --handler </dev/null >/dev/null 2>&1 &
PID=$!
sleep 1
kill $PID 2>/dev/null || true






GENERATED_DB_DIR=$(ls -td /tmp/cdd_ephemeral_db_* | head -n 1)

if [ ! -f "$GENERATED_DB_DIR/seed.sql" ]; then
  echo "FAIL: Seed script was not generated in $GENERATED_DB_DIR"
  exit 1
fi

if ! grep -q "INSERT INTO users" "$GENERATED_DB_DIR/seed.sql"; then
  echo "FAIL: Seed script missing INSERT logic"
  exit 1
fi

rm -rf "$GENERATED_DB_DIR"
rm -rf "$DATABASE_URL"

echo "Server SEED generation test passed!"
MOCK_SEED

sh tests/out/src/server_seed_test.sh || exit 1
