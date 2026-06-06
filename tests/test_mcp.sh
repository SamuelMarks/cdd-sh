#!/bin/sh
set -eu

# Generate the CLI
rm -rf tests/out
mkdir -p tests/out
./bin/cdd-sh from_openapi to_sdk_cli -i tests/test.json -o tests/out

# initialize
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"protocolVersion"'; then
	echo "FAIL: initialize"
	echo "$res"
	exit 1
fi

# tools/list
echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/list"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"tools":'; then
	echo "FAIL: tools/list"
	echo "$res"
	exit 1
fi

# tools/call
echo '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "genull_nullsers", "arguments": {}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"content"'; then
	echo "FAIL: tools/call"
	echo "$res"
	exit 1
fi

# tools/call with error
echo '{"jsonrpc": "2.0", "id": 3.1, "method": "tools/call", "params": {"name": "invalid_tool", "arguments": {}}}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"isError":true'; then
	echo "FAIL: tools/call error handling"
	echo "$res"
	exit 1
fi

# HTTP Header parsing test (Content-Length)
BODY='{"jsonrpc": "2.0", "id": 4, "method": "tools/list"}'
LEN=$(printf "%s" "$BODY" | wc -c | tr -d ' ')
printf "Content-Length: %d\r\n\r\n%s" "$LEN" "$BODY" >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"tools":'; then
	echo "FAIL: header parsing"
	echo "$res"
	exit 1
fi

# Unknown / Invalid method
echo '{"jsonrpc": "2.0", "id": 5, "method": "unknown_method"}' >tests/out/mcp_in.txt
res=$(tests/out/bin/sdk-cli mcp <tests/out/mcp_in.txt)
if ! echo "$res" | grep -q '"error":{"code":-32601'; then
	echo "FAIL: unknown method handling"
	echo "$res"
	exit 1
fi

echo "MCP test passed!"
