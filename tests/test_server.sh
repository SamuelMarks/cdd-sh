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
./bin/cdd-sh from_openapi to_server -i tests/test.json -o tests/out

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
if ! echo "$resp" | grep -q "genull_nullsers"; then
  fail "Server tools/list: $resp"
fi
sleep 0.5

resp=$(curl -s -X POST http://localhost:8101/mcp/message -H "Authorization: Bearer my-test-token" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"genull_nullsers","arguments":{}}}' --max-time 2 || true)
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
