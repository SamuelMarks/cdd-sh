#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
if [ "${SCRIPT_NAME-}" ]; then this_file="${SCRIPT_NAME}"; elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else this_file="${0}"; fi
case "${STACK+x}" in *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_emit_sdk generates the SDK code with native MCP bindings.
# This assumes the target is also shell for our test harness.
handle_emit_sdk() {
	output_file="$1"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n"
		printf "# @openapi_sdk_start\n"
		printf "MCP_CLI_BIN=\"./bin/sdk-cli\"\n"
		printf "mcp_get_tools() {\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}' | \$MCP_CLI_BIN mcp | jq -r '.result.tools'\n"
		printf "}\n"
		printf "mcp_execute_tool() {\n"
		printf "  tool_name=\"\$1\"\n"
		printf "  args=\"\$2\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"'\$tool_name'\",\"arguments\":'\$args'}}' | \$MCP_CLI_BIN mcp | jq -r '.result.content[0].text'\n"
		printf "}\n"
		printf "mcp_get_resources() {\n"
		printf "  cursor=\"\${1:-}\"\n"
		printf "  if [ -n \"\$cursor\" ]; then\n"
		printf "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/list\",\"params\":{\"cursor\":\"'\$cursor'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "  else\n"
		printf "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/list\"}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "  fi\n"
		printf "}\n"
		printf "mcp_read_resource() {\n"
		printf "  uri=\"\$1\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/read\",\"params\":{\"uri\":\"'\$uri'\"}}' | \$MCP_CLI_BIN mcp | jq -r '.result.contents[0].text'\n"
		printf "}\n"
		printf "mcp_get_resource_templates() {\n"
		printf "  cursor=\"\${1:-}\"\n"
		printf "  if [ -n \"\$cursor\" ]; then\n"
		printf "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/templates/list\",\"params\":{\"cursor\":\"'\$cursor'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "  else\n"
		printf "    echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/templates/list\"}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "  fi\n"
		printf "}\n"
		printf "mcp_subscribe_resource() {\n"
		printf "  uri=\"\$1\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/subscribe\",\"params\":{\"uri\":\"'\$uri'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result // .error'\n"
		printf "}\n"
		printf "mcp_unsubscribe_resource() {\n"
		printf "  uri=\"\$1\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"resources/unsubscribe\",\"params\":{\"uri\":\"'\$uri'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result // .error'\n"
		printf "}\n"
		printf "mcp_ping() {\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}' | \$MCP_CLI_BIN mcp | jq -r '.result | if . == {} then \"ok\" else \"error\" end'\n"
		printf "}\n"
		printf "mcp_get_prompts() {\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"prompts/list\"}' | \$MCP_CLI_BIN mcp | jq -r '.result.prompts'\n"
		printf "}\n"
		printf "mcp_get_roots() {\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"roots/list\"}' | \$MCP_CLI_BIN mcp | jq -r '.result.roots'\n"
		printf "}\n"
		printf "mcp_get_prompt() {\n"
		printf "  name=\"\$1\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"prompts/get\",\"params\":{\"name\":\"'\$name'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result // .error'\n"
		printf "}\n"
		printf "mcp_complete() {\n"
		printf "  ref_type=\"\$1\"\n"
		printf "  ref_name=\"\$2\"\n"
		printf "  arg_name=\"\$3\"\n"
		printf "  arg_value=\"\$4\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"completion/complete\",\"params\":{\"ref\":{\"type\":\"'\$ref_type'\",\"name\":\"'\$ref_name'\"},\"argument\":{\"name\":\"'\$arg_name'\",\"value\":\"'\$arg_value'\"}}}' | \$MCP_CLI_BIN mcp | jq -c '.result.completion'\n"
		printf "}\n"
		printf "mcp_create_message() {\n"
		printf "  messages=\"\$1\"\n"
		printf "  max_tokens=\"\$2\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"sampling/createMessage\",\"params\":{\"messages\":'\$messages',\"maxTokens\":'\$max_tokens'}}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "}\n"
		printf "mcp_set_logging_level() {\n"
		printf "  level=\"\$1\"\n"
		printf "  echo '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"logging/setLevel\",\"params\":{\"level\":\"'\$level'\"}}' | \$MCP_CLI_BIN mcp | jq -c '.result'\n"
		printf "}\n"
		printf "# @openapi_sdk_end\n"
	} >"${output_file}.tmp"

	if [ -f "${output_file}" ]; then
		awk -v new_file="${output_file}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" <"${output_file}" >"${output_file}.merged"
		mv "${output_file}.merged" "${output_file}"
		rm -f "${output_file}.tmp"
	else
		mv "${output_file}.tmp" "${output_file}"
	fi
	chmod +x "${output_file}"
}
