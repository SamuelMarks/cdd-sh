#!/bin/sh
set -eu

echo "Testing Server CORS functionality..."

rm -rf temp-cors
mkdir -p temp-cors

./bin/cdd-sh from_openapi to_server -i ../petstore.json -o temp-cors/server

PORT=8117 sh temp-cors/server/src/server.sh --ephemeral </dev/null >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2

res=$(curl -s -v -X OPTIONS http://localhost:8117/pet/findByStatus 2>&1)
if ! printf "%s" "$res" | grep -qi "Access-Control-Allow-Origin: \*"; then
	echo "FAIL: OPTIONS preflight did not return CORS headers"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

echo "CORS tests passed!"
kill $SERVER_PID 2>/dev/null || true
rm -rf temp-cors
