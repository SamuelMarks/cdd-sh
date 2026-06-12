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
mkdir -p tests/out
./bin/cdd-sh serve_json_rpc --port 8089 >/dev/null 2>&1 &
PID=$!
sleep 1

curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"to_openapi","params":{"file":"tests/test.json","out":"tests/out/spec.json"},"id":1}' http://localhost:8089 >/dev/null || true
curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"from_openapi","params":{"spec":"tests/test.json","out":"tests/out/sdk","tests":true,"no_github_actions":true,"no_installable_package":true},"id":2}' http://localhost:8089 >/dev/null || true
curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"to_docs_json","params":{"spec":"tests/test.json","out":"tests/out/docs.json"},"id":3}' http://localhost:8089 >/dev/null || true
curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"--version","id":4}' http://localhost:8089 >/dev/null || true
curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"invalid","id":5}' http://localhost:8089 >/dev/null || true
curl -s -X POST -H "Content-Type: application/json" -d 'invalid json' http://localhost:8089 >/dev/null || true

pkill -f "nc -l 8089" || true
pkill -f "serve_json_rpc" || true
kill $PID || true
rm -f /tmp/cdd_rpc_* || true
