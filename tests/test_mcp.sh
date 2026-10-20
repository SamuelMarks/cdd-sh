#!/bin/sh
# @file tests/test_mcp.sh
# @description Integration tests for the Model Context Protocol (MCP) stdio servers.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"

# cleanup_mcp_test removes temporary MCP test outputs.
# @param none
# @return Returns 0.
cleanup_mcp_test() {
	rm -rf tests/out tests/out2 tests/out_arz tests/out_spec.json tests/out_arazzo.json
}
trap cleanup_mcp_test EXIT INT TERM

# Generate the CLI
cleanup_mcp_test
mkdir -p tests/out
./bin/cdd-sh from_openapi to_sdk_cli -i tests/test.json -o tests/out

# initialize
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"protocolVersion"'; then
	echo "FAIL: initialize"
	printf "%s\n" "$res"
	exit 1
fi

# tools/list
echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"tools":'; then
	echo "FAIL: tools/list"
	printf "%s\n" "$res"
	exit 1
fi

# tools/call
echo '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "get_users", "arguments": {}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"content"'; then
	echo "FAIL: tools/call"
	printf "%s\n" "$res"
	exit 1
fi

# tools/call with error
echo '{"jsonrpc": "2.0", "id": 3.1, "method": "tools/call", "params": {"name": "invalid_tool", "arguments": {}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"isError":true'; then
	echo "FAIL: tools/call error handling"
	printf "%s\n" "$res"
	exit 1
fi

# HTTP Header parsing test (Content-Length)
BODY='{"jsonrpc": "2.0", "id": 4, "method": "tools/list"}'
LEN=$(printf "%s" "$BODY" | wc -c | tr -d ' ')
printf "Content-Length: %d\r\n\r\n%s" "$LEN" "$BODY" >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"tools":'; then
	echo "FAIL: header parsing"
	printf "%s\n" "$res"
	exit 1
fi

# ping
echo '{"jsonrpc": "2.0", "id": 6, "method": "ping"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"result":{}'; then
	echo "FAIL: ping"
	printf "%s\n" "$res"
	exit 1
fi

# prompts/list
echo '{"jsonrpc": "2.0", "id": 7, "method": "prompts/list"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"test_prompt"'; then
	echo "FAIL: prompts/list"
	printf "%s\n" "$res"
	exit 1
fi

# prompts/get
echo '{"jsonrpc": "2.0", "id": 8, "method": "prompts/get", "params": {"name": "test_prompt"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"Please test this"'; then
	echo "FAIL: prompts/get"
	printf "%s\n" "$res"
	exit 1
fi

# completion/complete
echo '{"jsonrpc": "2.0", "id": 9, "method": "completion/complete", "params": {"ref": {"type": "ref_type", "name": "ref_name"}, "argument": {"name": "arg_name", "value": "val"}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"completion":{'; then
	echo "FAIL: completion/complete"
	printf "%s\n" "$res"
	exit 1
fi

# sampling/createMessage
echo '{"jsonrpc": "2.0", "id": 10, "method": "sampling/createMessage", "params": {"messages": [{"role": "user", "content": {"type": "text", "text": "test"}}], "maxTokens": 100, "modelPreferences": {"costPriority": 0.5, "hints": [{"name": "test-model"}]}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"Sampled message"'; then
	echo "FAIL: sampling/createMessage"
	printf "%s\n" "$res"
	exit 1
fi

# logging/setLevel
echo '{"jsonrpc": "2.0", "id": 11, "method": "logging/setLevel", "params": {"level": "debug"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"result":{}'; then
	echo "FAIL: logging/setLevel"
	printf "%s\n" "$res"
	exit 1
fi

# pagination test (resources/list with cursor)
echo '{"jsonrpc": "2.0", "id": 12, "method": "resources/list", "params": {"cursor": "next"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"resources":\[\]'; then
	echo "FAIL: resources/list with cursor"
	printf "%s\n" "$res"
	exit 1
fi

# roots/list
echo '{"jsonrpc": "2.0", "id": 13, "method": "roots/list"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"roots":'; then
	echo "FAIL: roots/list"
	printf "%s\n" "$res"
	exit 1
fi

# resources/templates/list
echo '{"jsonrpc": "2.0", "id": 14, "method": "resources/templates/list"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"resourceTemplates":\['; then
	echo "FAIL: resources/templates/list"
	printf "%s\n" "$res"
	exit 1
fi

# resources/subscribe
echo '{"jsonrpc": "2.0", "id": 15, "method": "resources/subscribe", "params": {"uri": "openapi://spec"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"result":{}'; then
	echo "FAIL: resources/subscribe"
	printf "%s\n" "$res"
	exit 1
fi

# resources/unsubscribe
echo '{"jsonrpc": "2.0", "id": 16, "method": "resources/unsubscribe", "params": {"uri": "openapi://spec"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"result":{}'; then
	echo "FAIL: resources/unsubscribe"
	printf "%s\n" "$res"
	exit 1
fi

# notifications
echo '{"jsonrpc": "2.0", "method": "notifications/tools/list_changed"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if [ -n "$res" ]; then
	echo "FAIL: notifications"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "method": "notifications/roots/list_changed"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if [ -n "$res" ]; then
	echo "FAIL: notifications/roots/list_changed"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": "123", "reason": "timeout"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if [ -n "$res" ]; then
	echo "FAIL: notifications/cancelled"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "method": "notifications/progress", "params": {"progressToken": "token1", "progress": 50, "total": 100}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if [ -n "$res" ]; then
	echo "FAIL: notifications/progress"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "method": "notifications/message", "params": {"level": "info", "data": "A test message"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt 2>tests/out/mcp_err.txt)
if [ -n "$res" ]; then
	echo "FAIL: notifications/message stdout should be empty"
	printf "%s\n" "$res"
	exit 1
fi
if ! grep -q "\[info\] A test message" tests/out/mcp_err.txt; then
	echo "FAIL: notifications/message did not log to stderr"
	cat tests/out/mcp_err.txt
	exit 1
fi

# Unknown / Invalid method
echo '{"jsonrpc": "2.0", "id": 5, "method": "unknown_method"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"error":{"code":-32601'; then
	echo "FAIL: unknown method handling"
	printf "%s\n" "$res"
	exit 1
fi

echo "MCP test passed!"

# cdd.sh Generator MCP tests
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize"}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | grep -q '"protocolVersion"'; then
	echo "FAIL: cdd-sh mcp initialize"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | grep -q 'to_openapi'; then
	echo "FAIL: cdd-sh mcp tools/list"
	printf "%s\n" "$res"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 3, "method": "ping"}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | grep -q '"result":{}'; then
	echo "FAIL: cdd-sh mcp ping"
	printf "%s\n" "$res"
	exit 1
fi

echo "Generator MCP test passed!"

# More MCP missing branches
echo '{"jsonrpc": "2.0", "method": "initialized"}' >tests/out/mcp_in.txt
tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt >/dev/null

echo '{"jsonrpc": "2.0", "method": "notifications/initialized"}' >tests/out/mcp_in.txt
tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt >/dev/null

echo '{"jsonrpc": "2.0", "method": "notifications/prompts/list_changed"}' >tests/out/mcp_in.txt
tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt >/dev/null

echo '{"jsonrpc": "2.0", "method": "notifications/resources/list_changed"}' >tests/out/mcp_in.txt
tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt >/dev/null

echo '{"jsonrpc": "2.0", "method": "notifications/resources/updated"}' >tests/out/mcp_in.txt
tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt >/dev/null

echo '{"jsonrpc": "2.0", "id": 101, "method": "resources/read", "params": {"uri": "openapi://spec"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"contents":'; then
	echo "FAIL: resources/read openapi://spec"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 102, "method": "resources/read", "params": {"uri": "invalid"}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! printf "%s\n" "$res" | grep -q '"error":'; then
	echo "FAIL: resources/read invalid"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 103, "method": "tools/call", "params": {"name": "from_openapi", "arguments": {"subcmd": "to_sdk", "input": "tests/test.json", "output": "tests/out2", "tests": true}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp from_openapi (tests=true) failed: $res"
	exit 1
fi
if [ ! -f tests/out2/src/routes.sh ] || [ ! -f tests/out2/tests/test_routes.sh ]; then
	echo "FAIL: cdd-sh mcp from_openapi (tests=true) did not emit routes.sh and test_routes.sh"
	exit 1
fi

rm -rf tests/out2
echo '{"jsonrpc": "2.0", "id": 104, "method": "tools/call", "params": {"name": "from_openapi", "arguments": {"subcmd": "to_sdk", "input": "tests/test.json", "output": "tests/out2", "tests": false}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp from_openapi (tests=false) failed: $res"
	exit 1
fi
if [ ! -f tests/out2/src/routes.sh ] || [ -f tests/out2/tests/test_routes.sh ]; then
	echo "FAIL: cdd-sh mcp from_openapi (tests=false) unexpected files"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 105, "method": "tools/call", "params": {"name": "to_openapi", "arguments": {"input": "tests/test.json", "output": "tests/out_spec.json"}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp to_openapi failed: $res"
	exit 1
fi
if [ ! -f tests/out_spec.json ] || ! jq -e '.paths["/users"].get' tests/out_spec.json >/dev/null; then
	echo "FAIL: cdd-sh mcp to_openapi did not emit valid tests/out_spec.json"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 106, "method": "tools/call", "params": {"name": "from_arazzo", "arguments": {"subcmd": "to_sdk", "input": "tests/test_arazzo.json", "output": "tests/out_arz", "tests": true}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp from_arazzo (tests=true) failed: $res"
	exit 1
fi
if [ ! -f tests/out_arz/src/workflows.sh ] || [ ! -f tests/out_arz/tests/test_workflows.sh ]; then
	echo "FAIL: cdd-sh mcp from_arazzo (tests=true) did not emit workflows.sh and test_workflows.sh"
	exit 1
fi

rm -rf tests/out_arz
echo '{"jsonrpc": "2.0", "id": 107, "method": "tools/call", "params": {"name": "from_arazzo", "arguments": {"subcmd": "to_sdk", "input": "tests/test_arazzo.json", "output": "tests/out_arz", "tests": false}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp from_arazzo (tests=false) failed: $res"
	exit 1
fi
if [ ! -f tests/out_arz/src/workflows.sh ]; then
	echo "FAIL: cdd-sh mcp from_arazzo (tests=false) did not emit workflows.sh"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 108, "method": "tools/call", "params": {"name": "to_arazzo", "arguments": {"input": "tests/out_arz/src/workflows.sh", "output": "tests/out_arazzo.json"}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == false' >/dev/null; then
	echo "FAIL: cdd-sh mcp to_arazzo failed: $res"
	exit 1
fi
if [ ! -f tests/out_arazzo.json ] || ! jq -e '.workflows | length == 2' tests/out_arazzo.json >/dev/null; then
	echo "FAIL: cdd-sh mcp to_arazzo did not emit valid tests/out_arazzo.json"
	exit 1
fi

echo '{"jsonrpc": "2.0", "id": 109, "method": "tools/call", "params": {"name": "nonexistent_tool", "arguments": {}}}' >tests/out/mcp_cdd_in.txt
res=$(./bin/cdd-sh mcp <tests/out/mcp_cdd_in.txt)
if ! printf "%s\n" "$res" | jq -e '.result.isError == true' >/dev/null; then
	echo "FAIL: cdd-sh mcp nonexistent_tool should return isError=true: $res"
	exit 1
fi
