#!/bin/sh
set -eu

# Generate the SDK
rm -rf tests/out
mkdir -p tests/out
./bin/cdd-sh from_openapi to_sdk -i tests/test.json -o tests/out
# and CLI since it depends on it internally
./bin/cdd-sh from_openapi to_sdk_cli -i tests/test.json -o tests/out

if [ ! -f tests/out/src/sdk.sh ]; then
	echo "FAIL: sdk.sh not generated"
	exit 1
fi

# shellcheck disable=SC1091
. tests/out/src/sdk.sh

export MCP_CLI_BIN="./tests/out/bin/sdk-cli"
tools=$(mcp_get_tools)
if ! echo "$tools" | grep -q "genull_nullsers"; then
	echo "FAIL: mcp_get_tools did not return correct JSON"
	exit 1
fi

res=$(mcp_execute_tool "genull_nullsers" "{}")
if ! echo "$res" | grep -q "Executing genull_nullsers"; then
	echo "FAIL: mcp_execute_tool did not return tool output"
	exit 1
fi

echo "SDK MCP integration test passed!"
