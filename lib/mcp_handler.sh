#!/bin/sh
# @file lib/mcp_handler.sh
# @description Shared Model Context Protocol (MCP) JSON-RPC 2.0 request dispatcher and code generator helper.
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# @begin_embed_mcp_handler
# mcp_handle_common dispatches standard MCP JSON-RPC 2.0 methods and prints the JSON response.
# @param $1: req - Raw JSON-RPC request string.
# @param $2: srv_name - Server name reported in initialize.
# @param $3: srv_version - Server version reported in initialize.
# @param $4: res_uri - Primary resource URI (e.g., cdd://ast or openapi://spec).
# @param $5: res_name - Primary resource display name.
# @param $6: res_text - Primary resource text content.
# @param $7: tools_json - JSON array string of MCP tool definitions.
# @param $8: root_uri - Workspace root URI.
# @return Returns 0 if the method was handled, or 1 if unhandled.
mcp_handle_common() {
	mcp_req="$1"
	mcp_srv_name="$2"
	mcp_srv_ver="$3"
	mcp_res_uri="$4"
	mcp_res_name="$5"
	mcp_res_text="$6"
	mcp_tools="$7"
	mcp_root_uri="$8"

	mcp_method=$(printf '%s\n' "$mcp_req" | jq -r '.method // empty')
	mcp_id=$(printf '%s\n' "$mcp_req" | jq -c '.id // null')
	mcp_default_prompts='[{"name":"test_prompt","description":"A test prompt","arguments":[{"name":"arg1","description":"An argument","required":true}]}]'

	case "$mcp_method" in
	initialize)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2024-11-05","capabilities":{"experimental":{},"tools":{"listChanged":true},"resources":{"listChanged":true,"subscribe":true},"logging":{},"prompts":{"listChanged":true}},"serverInfo":{"name":"%s","version":"%s"},"instructions":"Use MCP tools and resources to interact with %s"}}\n' "$mcp_id" "$mcp_srv_name" "$mcp_srv_ver" "$mcp_srv_name"
		return 0
		;;
	notifications/initialized | initialized | notifications/tools/list_changed | notifications/resources/list_changed | notifications/prompts/list_changed | notifications/roots/list_changed | notifications/resources/updated | notifications/cancelled | notifications/progress)
		return 0
		;;
	notifications/message)
		mcp_level=$(printf '%s\n' "$mcp_req" | jq -r '.params.level // "info"')
		mcp_logger=$(printf '%s\n' "$mcp_req" | jq -r '.params.logger // ""')
		mcp_msg=$(printf '%s\n' "$mcp_req" | jq -r '.params.data // ""')
		if [ -n "$mcp_logger" ]; then
			printf '[%s:%s] %s\n' "$mcp_level" "$mcp_logger" "$mcp_msg" >&2
		else
			printf '[%s] %s\n' "$mcp_level" "$mcp_msg" >&2
		fi
		return 0
		;;
	ping | logging/setLevel | resources/subscribe | resources/unsubscribe)
		printf '{"jsonrpc":"2.0","id":%s,"result":{}}\n' "$mcp_id"
		return 0
		;;
	roots/list)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"roots":[{"uri":"%s","name":"Workspace"}]}}\n' "$mcp_id" "$mcp_root_uri"
		return 0
		;;
	prompts/list)
		mcp_cursor=$(printf '%s\n' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"prompts":[]}}\n' "$mcp_id"
		else
			mcp_prompts="${MCP_PROMPTS_JSON:-$mcp_default_prompts}"
			printf '{"jsonrpc":"2.0","id":%s,"result":{"prompts":%s,"nextCursor":"next"}}\n' "$mcp_id" "$mcp_prompts"
		fi
		return 0
		;;
	prompts/get)
		mcp_pname=$(printf '%s\n' "$mcp_req" | jq -r '.params.name // empty')
		mcp_prompts="${MCP_PROMPTS_JSON:-$mcp_default_prompts}"
		if printf '%s\n' "$mcp_prompts" | jq -e --arg n "$mcp_pname" 'any(.[]; .name == $n)' >/dev/null 2>&1; then
			mcp_pdesc=$(printf '%s\n' "$mcp_prompts" | jq -r --arg n "$mcp_pname" 'first(.[] | select(.name == $n) | .description) // "A test prompt"')
			printf '{"jsonrpc":"2.0","id":%s,"result":{"description":"%s","messages":[{"role":"user","content":{"type":"text","text":"Please test this","annotations":{"audience":["user","assistant"],"priority":1.0}}}]}}\n' "$mcp_id" "$mcp_pdesc"
		else
			printf '{"jsonrpc":"2.0","id":%s,"error":{"code":-32602,"message":"Invalid prompt","data":{"name":"%s"}}}\n' "$mcp_id" "$mcp_pname"
		fi
		return 0
		;;
	completion/complete)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"completion":{"values":[],"total":0,"hasMore":false}}}\n' "$mcp_id"
		return 0
		;;
	sampling/createMessage)
		mcp_model="${MCP_MODEL_NAME:-test-model}"
		printf '{"jsonrpc":"2.0","id":%s,"result":{"role":"assistant","content":{"type":"text","text":"Sampled message","annotations":{"audience":["user"],"priority":1.0}},"model":"%s","stopReason":"endTurn"}}\n' "$mcp_id" "$mcp_model"
		return 0
		;;
	resources/list)
		mcp_cursor=$(printf '%s\n' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resources":[]}}\n' "$mcp_id"
		else
			mcp_rsize=${#mcp_res_text}
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resources":[{"uri":"%s","name":"%s","description":"Specification resource for %s","mimeType":"application/json","size":%d,"annotations":{"audience":["user","assistant"],"priority":1.0}}],"nextCursor":"next"}}\n' "$mcp_id" "$mcp_res_uri" "$mcp_res_name" "$mcp_srv_name" "$mcp_rsize"
		fi
		return 0
		;;
	resources/templates/list)
		mcp_cursor=$(printf '%s\n' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resourceTemplates":[]}}\n' "$mcp_id"
		else
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resourceTemplates":[{"uriTemplate":"%s/{path}","name":"%s Template","description":"Parameterized resource template","mimeType":"application/json","annotations":{"audience":["assistant"],"priority":0.8}}],"nextCursor":"next"}}\n' "$mcp_id" "$mcp_res_uri" "$mcp_res_name"
		fi
		return 0
		;;
	resources/read)
		mcp_uri=$(printf '%s\n' "$mcp_req" | jq -r '.params.uri // empty')
		if [ "$mcp_uri" = "$mcp_res_uri" ]; then
			mcp_escaped=$(printf '%s' "$mcp_res_text" | jq -R -s '.')
			printf '{"jsonrpc":"2.0","id":%s,"result":{"contents":[{"uri":"%s","mimeType":"application/json","text":%s}]}}\n' "$mcp_id" "$mcp_res_uri" "$mcp_escaped"
		else
			printf '{"jsonrpc":"2.0","id":%s,"error":{"code":-32602,"message":"Invalid URI","data":{"uri":"%s"}}}\n' "$mcp_id" "$mcp_uri"
		fi
		return 0
		;;
	tools/list)
		mcp_cursor=$(printf '%s\n' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":[]}}\n' "$mcp_id"
		else
			printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":%s,"nextCursor":"next"}}\n' "$mcp_id" "$mcp_tools"
		fi
		return 0
		;;
	esac
	return 1
}

# mcp_serve_stdio runs the shared MCP JSON-RPC 2.0 stdio loop with Content-Length framing support.
# @param $1: srv_name - Server name reported in initialize.
# @param $2: srv_version - Server version reported in initialize.
# @param $3: res_uri - Primary resource URI.
# @param $4: res_name - Primary resource display name.
# @param $5: res_src - Primary resource text or `__CDD_AST_FILE__`.
# @param $6: tools_json - JSON array string of MCP tool definitions.
# @param $7: root_uri - Workspace root URI.
# @param $8: tool_dispatch_fn - Callback function invoked as `$tool_dispatch_fn "$tool_name" "$args"` on tools/call.
# @return Reads stdin until EOF and writes JSON-RPC responses to stdout.
mcp_serve_stdio() {
	_ms_srv_name="$1"
	_ms_srv_ver="$2"
	_ms_res_uri="$3"
	_ms_res_name="$4"
	_ms_res_src="$5"
	_ms_tools="$6"
	_ms_root_uri="$7"
	_ms_tool_fn="$8"

	while read -r line || [ -n "$line" ]; do
		if echo "$line" | grep -qi "^Content-Length:"; then
			read -r _
			content_length=$(echo "$line" | awk '{print $2}' | tr -d '\r\n')
			line=$(dd bs=1 count="$content_length" 2>/dev/null)
		elif echo "$line" | grep -qi "^[A-Za-z-]\+: "; then
			continue
		elif [ -z "$(echo "$line" | tr -d '\r\n')" ]; then
			continue
		fi
		method=$(echo "$line" | jq -r '.method // empty')
		id=$(echo "$line" | jq -r '.id // null')
		if [ "${_ms_res_src}" = "__CDD_AST_FILE__" ]; then
			_ms_res_text=$(cat "${CDD_AST_PATH:-ast.json}" 2>/dev/null || echo "{}")
		else
			_ms_res_text="${_ms_res_src}"
		fi
		if mcp_out=$(mcp_handle_common "$line" "$_ms_srv_name" "$_ms_srv_ver" "$_ms_res_uri" "$_ms_res_name" "$_ms_res_text" "$_ms_tools" "$_ms_root_uri"); then
			if [ -n "$mcp_out" ]; then
				printf '%s\n' "$mcp_out"
			fi
		elif [ "$method" = "tools/call" ]; then
			tool_name=$(echo "$line" | jq -r '.params.name')
			args=$(echo "$line" | jq -c '.params.arguments // {}')
			set +e
			res=$("$_ms_tool_fn" "$tool_name" "$args" 2>&1)
			exit_code=$?
			set -e
			res_escaped=$(printf "%s" "$res" | jq -R -s '.')
			if [ "$exit_code" -ne 0 ]; then
				printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":true,"content":[{"type":"text","text":%s}]}}\n' "$id" "$res_escaped"
			else
				printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":false,"content":[{"type":"text","text":%s}]}}\n' "$id" "$res_escaped"
			fi
		else
			if [ "$id" != "null" ]; then
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}"
			fi
		fi
	done
}
# @end_embed_mcp_handler

# emit_mcp_handler_func outputs the standalone mcp_handle_common shell function definition for generated artifacts.
# @param none
# @return Prints the embedded mcp_handle_common function body to stdout, or returns 1 if markers are missing.
emit_mcp_handler_func() {
	awk '
		/^# @begin_embed_mcp_handler$/ { p = 1; found = 1; next }
		/^# @end_embed_mcp_handler$/ { p = 0; next }
		p { print $0 }
		END { if (!found) exit 1 }
	' "${LIBSCRIPT_ROOT_DIR:-.}/lib/mcp_handler.sh"
}
