#!/bin/sh
# @file tests/test_serve_rpc.sh
# @description Integration tests for the HTTP JSON-RPC 2.0 server mode.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
rm -rf tests/out/spec.json tests/out/sdk tests/out/docs.json
mkdir -p tests/out
./bin/cdd-sh serve_json_rpc --port 8089 >/dev/null 2>&1 &
PID=$!
sleep 1

cleanup_rpc() {
	pkill -f "nc -l 8089" 2>/dev/null || true
	pkill -f "serve_json_rpc" 2>/dev/null || true
	kill "$PID" 2>/dev/null || true
	rm -f /tmp/cdd_rpc_* 2>/dev/null || true
}
trap cleanup_rpc EXIT

res1=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"to_openapi","params":{"file":"tests/test.json","out":"tests/out/spec.json"},"id":1}' http://localhost:8089)
if ! printf "%s\n" "$res1" | jq -e '.jsonrpc == "2.0" and .id == "1"' >/dev/null; then
	echo "FAIL: serve_json_rpc to_openapi invalid response: $res1"
	exit 1
fi
if [ ! -f tests/out/spec.json ] || ! jq -e '.paths["/users"].get' tests/out/spec.json >/dev/null; then
	echo "FAIL: serve_json_rpc to_openapi did not create valid tests/out/spec.json"
	exit 1
fi

res2=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"from_openapi","params":{"spec":"tests/test.json","out":"tests/out/sdk","tests":true,"no_github_actions":true,"no_installable_package":true},"id":2}' http://localhost:8089)
if ! printf "%s\n" "$res2" | jq -e '.jsonrpc == "2.0" and .id == "2"' >/dev/null; then
	echo "FAIL: serve_json_rpc from_openapi invalid response: $res2"
	exit 1
fi
if [ ! -f tests/out/sdk/src/routes.sh ]; then
	echo "FAIL: serve_json_rpc from_openapi did not generate tests/out/sdk/src/routes.sh"
	exit 1
fi

res3=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"to_docs_json","params":{"spec":"tests/test.json","out":"tests/out/docs.json"},"id":3}' http://localhost:8089)
if ! printf "%s\n" "$res3" | jq -e '.jsonrpc == "2.0" and .id == "3"' >/dev/null; then
	echo "FAIL: serve_json_rpc to_docs_json invalid response: $res3"
	exit 1
fi
if [ ! -f tests/out/docs.json ] || ! jq -e '.endpoints["/users"].get' tests/out/docs.json >/dev/null; then
	echo "FAIL: serve_json_rpc to_docs_json did not create valid tests/out/docs.json"
	exit 1
fi

res4=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"--version","id":4}' http://localhost:8089)
if ! printf "%s\n" "$res4" | jq -e '.result == "0.0.4"' >/dev/null; then
	echo "FAIL: serve_json_rpc --version did not return 0.0.4: $res4"
	exit 1
fi

res5=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"invalid","id":5}' http://localhost:8089)
if ! printf "%s\n" "$res5" | jq -e '.error.code == -32601' >/dev/null; then
	echo "FAIL: serve_json_rpc invalid method did not return -32601 error: $res5"
	exit 1
fi

res6=$(curl -s -i -X POST -H "Content-Type: application/json" -d 'invalid json' http://localhost:8089 2>&1 || true)
if ! printf "%s\n" "$res6" | grep -q "400 Bad Request"; then
	echo "FAIL: serve_json_rpc invalid json did not return 400 Bad Request: $res6"
	exit 1
fi

echo "serve_json_rpc tests passed!"
