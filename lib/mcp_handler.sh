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

	mcp_method=$(printf '%s
' "$mcp_req" | jq -r '.method // empty')
	mcp_id=$(printf '%s
' "$mcp_req" | jq -c '.id // null')

	case "$mcp_method" in
	initialize)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":true},"resources":{"listChanged":true,"subscribe":true},"logging":{},"prompts":{"listChanged":true}},"serverInfo":{"name":"%s","version":"%s"}}}
' "$mcp_id" "$mcp_srv_name" "$mcp_srv_ver"
		return 0
		;;
	notifications/initialized | initialized | notifications/tools/list_changed | notifications/resources/list_changed | notifications/prompts/list_changed | notifications/roots/list_changed | notifications/resources/updated | notifications/cancelled | notifications/progress)
		return 0
		;;
	notifications/message)
		mcp_level=$(printf '%s
' "$mcp_req" | jq -r '.params.level // "info"')
		mcp_msg=$(printf '%s
' "$mcp_req" | jq -r '.params.data // ""')
		printf '[%s] %s
' "$mcp_level" "$mcp_msg" >&2
		return 0
		;;
	ping | logging/setLevel | resources/subscribe | resources/unsubscribe)
		printf '{"jsonrpc":"2.0","id":%s,"result":{}}
' "$mcp_id"
		return 0
		;;
	roots/list)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"roots":[{"uri":"%s","name":"Workspace"}]}}
' "$mcp_id" "$mcp_root_uri"
		return 0
		;;
	prompts/list)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"prompts":[{"name":"test_prompt","description":"A test prompt","arguments":[{"name":"arg1","description":"An argument","required":true}]}]}}
' "$mcp_id"
		return 0
		;;
	prompts/get)
		mcp_pname=$(printf '%s
' "$mcp_req" | jq -r '.params.name // empty')
		if [ "$mcp_pname" = "test_prompt" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"description":"A test prompt","messages":[{"role":"user","content":{"type":"text","text":"Please test this"}}]}}
' "$mcp_id"
		else
			printf '{"jsonrpc":"2.0","id":%s,"error":{"code":-32602,"message":"Invalid prompt"}}
' "$mcp_id"
		fi
		return 0
		;;
	completion/complete)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"completion":{"values":[],"total":0,"hasMore":false}}}
' "$mcp_id"
		return 0
		;;
	sampling/createMessage)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"role":"assistant","content":{"type":"text","text":"Sampled message"},"model":"test-model","stopReason":"endTurn"}}
' "$mcp_id"
		return 0
		;;
	resources/list)
		mcp_cursor=$(printf '%s
' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resources":[]}}
' "$mcp_id"
		else
			printf '{"jsonrpc":"2.0","id":%s,"result":{"resources":[{"uri":"%s","name":"%s","mimeType":"application/json"}],"nextCursor":"next"}}
' "$mcp_id" "$mcp_res_uri" "$mcp_res_name"
		fi
		return 0
		;;
	resources/templates/list)
		printf '{"jsonrpc":"2.0","id":%s,"result":{"resourceTemplates":[]}}
' "$mcp_id"
		return 0
		;;
	resources/read)
		mcp_uri=$(printf '%s
' "$mcp_req" | jq -r '.params.uri // empty')
		if [ "$mcp_uri" = "$mcp_res_uri" ]; then
			mcp_escaped=$(printf '%s' "$mcp_res_text" | jq -R -s '.')
			printf '{"jsonrpc":"2.0","id":%s,"result":{"contents":[{"uri":"%s","mimeType":"application/json","text":%s}]}}
' "$mcp_id" "$mcp_res_uri" "$mcp_escaped"
		else
			printf '{"jsonrpc":"2.0","id":%s,"error":{"code":-32602,"message":"Invalid URI"}}
' "$mcp_id"
		fi
		return 0
		;;
	tools/list)
		mcp_cursor=$(printf '%s
' "$mcp_req" | jq -r '.params.cursor // empty')
		if [ "$mcp_cursor" = "next" ]; then
			printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":[]}}
' "$mcp_id"
		else
			printf '{"jsonrpc":"2.0","id":%s,"result":{"tools":%s,"nextCursor":"next"}}
' "$mcp_id" "$mcp_tools"
		fi
		return 0
		;;
	esac
	return 1
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
