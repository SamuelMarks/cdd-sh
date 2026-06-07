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

res=$(mcp_ping)
if [ "$res" != "ok" ]; then
	echo "FAIL: mcp_ping did not return ok"
	exit 1
fi

res=$(mcp_get_prompts)
if ! echo "$res" | grep -q 'test_prompt'; then
	echo "FAIL: mcp_get_prompts did not return test_prompt"
	echo "$res"
	exit 1
fi

res=$(mcp_get_prompt "test_prompt")
if ! echo "$res" | grep -q "Please test this"; then
	echo "FAIL: mcp_get_prompt did not return mock message"
	echo "$res"
	exit 1
fi

res=$(mcp_complete "t" "n" "an" "av")
if ! echo "$res" | grep -q "values"; then
	echo "FAIL: mcp_complete did not return valid result"
	exit 1
fi

res=$(mcp_create_message '[{"role": "user", "content": {"type": "text", "text": "hello"}}]' "100")
if ! echo "$res" | grep -q "Sampled message"; then
	echo "FAIL: mcp_create_message did not return valid result"
	exit 1
fi

res=$(mcp_set_logging_level "info")
if ! echo "$res" | grep -q "{}"; then
	echo "FAIL: mcp_set_logging_level did not return valid result"
	exit 1
fi

res=$(mcp_get_resources "next")
if ! echo "$res" | grep -q '"resources":\[\]'; then
	echo "FAIL: mcp_get_resources with cursor did not return valid result"
	exit 1
fi

res=$(mcp_get_resource_templates)
if ! echo "$res" | grep -q '"resourceTemplates":\['; then
	echo "FAIL: mcp_get_resource_templates did not return valid result"
	exit 1
fi

res=$(mcp_subscribe_resource "file:///test")
if ! echo "$res" | grep -q "{}"; then
	echo "FAIL: mcp_subscribe_resource did not return valid result"
	exit 1
fi

res=$(mcp_unsubscribe_resource "file:///test")
if ! echo "$res" | grep -q "{}"; then
	echo "FAIL: mcp_unsubscribe_resource did not return valid result"
	exit 1
fi

res=$(mcp_get_roots)
if ! echo "$res" | grep -q 'Workspace'; then
	echo "FAIL: mcp_get_roots did not return valid result"
	exit 1
fi
