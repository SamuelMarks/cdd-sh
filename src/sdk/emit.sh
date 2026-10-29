#!/bin/sh
# @file src/sdk/emit.sh
# @description Emits the POSIX shell MCP client SDK bindings from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_sdk generates the SDK code with native MCP bindings.
# @param $1: output_file - The destination path for the generated SDK script.
handle_emit_sdk() {
	output_file="$1"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	printf '%s\n' '#!/bin/sh
# @file sdk.sh
# @description Auto-generated HTTP transport and MCP client SDK bindings.
# @openapi_sdk_start
# http_request executes an HTTP request using curl.
# @param $@: args - Arguments forwarded to curl.
http_request() {
  curl "$@"
}
MCP_CLI_BIN="./bin/sdk-cli"
# mcp_get_tools retrieves the list of available MCP tools from the CLI server.
# @param $1: cursor - Optional pagination cursor.
mcp_get_tools() {
  cursor="${1:-}"
  if [ -n "$cursor" ]; then
    jq -c -n --arg cursor "$cursor" '\''{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"cursor":$cursor}}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.tools'\''
  else
    echo '\''{"jsonrpc":"2.0","id":1,"method":"tools/list"}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.tools'\''
  fi
}
# mcp_execute_tool invokes a named MCP tool with a JSON arguments object.
# @param $1: tool_name - The name of the MCP tool to call.
# @param $2: args - JSON object of tool arguments.
mcp_execute_tool() {
  tool_name="$1"
  args="${2:-}"
  if [ -z "$args" ]; then args="{}"; fi
  jq -c -n --arg name "$tool_name" --argjson args "$args" '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":$name,"arguments":$args}}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.content[0].text'\''
}
# mcp_get_resources lists available MCP resources with optional pagination cursor.
# @param $1: cursor - Optional pagination cursor.
mcp_get_resources() {
  cursor="${1:-}"
  if [ -n "$cursor" ]; then
    jq -c -n --arg cursor "$cursor" '\''{"jsonrpc":"2.0","id":1,"method":"resources/list","params":{"cursor":$cursor}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
  else
    echo '\''{"jsonrpc":"2.0","id":1,"method":"resources/list"}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
  fi
}
# mcp_read_resource reads the text content of an MCP resource by URI.
# @param $1: uri - The resource URI to read.
mcp_read_resource() {
  uri="$1"
  jq -c -n --arg uri "$uri" '\''{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":$uri}}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.contents[0].text'\''
}
# mcp_get_resource_templates lists available MCP resource templates.
# @param $1: cursor - Optional pagination cursor.
mcp_get_resource_templates() {
  cursor="${1:-}"
  if [ -n "$cursor" ]; then
    jq -c -n --arg cursor "$cursor" '\''{"jsonrpc":"2.0","id":1,"method":"resources/templates/list","params":{"cursor":$cursor}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
  else
    echo '\''{"jsonrpc":"2.0","id":1,"method":"resources/templates/list"}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
  fi
}
# mcp_subscribe_resource subscribes to updates for a specific MCP resource URI.
# @param $1: uri - The resource URI to subscribe to.
mcp_subscribe_resource() {
  uri="$1"
  jq -c -n --arg uri "$uri" '\''{"jsonrpc":"2.0","id":1,"method":"resources/subscribe","params":{"uri":$uri}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result // .error'\''
}
# mcp_unsubscribe_resource unsubscribes from updates for a specific MCP resource URI.
# @param $1: uri - The resource URI to unsubscribe from.
mcp_unsubscribe_resource() {
  uri="$1"
  jq -c -n --arg uri "$uri" '\''{"jsonrpc":"2.0","id":1,"method":"resources/unsubscribe","params":{"uri":$uri}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result // .error'\''
}
# mcp_ping sends a JSON-RPC ping request to the MCP server and returns "ok" on success.
# @param none
mcp_ping() {
  echo '\''{"jsonrpc":"2.0","id":1,"method":"ping"}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result | if . == {} then "ok" else "error" end'\''
}
# mcp_get_prompts retrieves the list of available MCP prompts.
# @param $1: cursor - Optional pagination cursor.
mcp_get_prompts() {
  cursor="${1:-}"
  if [ -n "$cursor" ]; then
    jq -c -n --arg cursor "$cursor" '\''{"jsonrpc":"2.0","id":1,"method":"prompts/list","params":{"cursor":$cursor}}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.prompts'\''
  else
    echo '\''{"jsonrpc":"2.0","id":1,"method":"prompts/list"}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.prompts'\''
  fi
}
# mcp_get_roots retrieves the list of configured workspace roots from the MCP server.
# @param none
mcp_get_roots() {
  echo '\''{"jsonrpc":"2.0","id":1,"method":"roots/list"}'\'' | $MCP_CLI_BIN mcp | jq -r '\''.result.roots'\''
}
# mcp_get_prompt fetches a specific prompt template by name and optional arguments JSON.
# @param $1: name - The prompt name to retrieve.
# @param $2: arguments - Optional JSON object of prompt arguments.
mcp_get_prompt() {
  name="$1"
  args="${2:-}"
  if [ -z "$args" ]; then args="{}"; fi
  jq -c -n --arg name "$name" --argjson args "$args" '\''{"jsonrpc":"2.0","id":1,"method":"prompts/get","params":{"name":$name,"arguments":$args}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result // .error'\''
}
# mcp_complete requests argument autocompletion suggestions from the MCP server.
# @param $1: ref_type - Reference type (e.g. ref/prompt or ref/resource).
# @param $2: ref_name - Reference name.
# @param $3: arg_name - Argument name being completed.
# @param $4: arg_value - Partial argument value.
mcp_complete() {
  ref_type="$1"
  ref_name="$2"
  arg_name="$3"
  arg_value="$4"
  jq -c -n --arg rt "$ref_type" --arg rn "$ref_name" --arg an "$arg_name" --arg av "$arg_value" '\''{"jsonrpc":"2.0","id":1,"method":"completion/complete","params":{"ref":{"type":$rt,"name":$rn},"argument":{"name":$an,"value":$av}}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result.completion'\''
}
# mcp_create_message sends a sampling/createMessage request to the MCP server.
# @param $1: messages - JSON array of conversation messages.
# @param $2: max_tokens - Maximum tokens to sample.
# @param $3: system_prompt - Optional system prompt string.
mcp_create_message() {
  messages="$1"
  max_tokens="$2"
  sys_prompt="${3:-You are a helpful assistant}"
  jq -c -n --argjson messages "$messages" --argjson max_tokens "$max_tokens" --arg sp "$sys_prompt" '\''{"jsonrpc":"2.0","id":1,"method":"sampling/createMessage","params":{"messages":$messages,"maxTokens":$max_tokens,"systemPrompt":$sp,"includeContext":"thisServer","temperature":0.7,"stopSequences":["STOP"],"metadata":{}}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
}
# mcp_set_logging_level sets the minimum logging level on the MCP server.
# @param $1: level - The log level string (e.g. info, debug, error).
mcp_set_logging_level() {
  level="$1"
  jq -c -n --arg level "$level" '\''{"jsonrpc":"2.0","id":1,"method":"logging/setLevel","params":{"level":$level}}'\'' | $MCP_CLI_BIN mcp | jq -c '\''.result'\''
}
# @openapi_sdk_end' >"${output_file}.tmp"

	merge_or_move_emitted_file "${output_file}" "1"
}
