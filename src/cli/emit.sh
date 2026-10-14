#!/bin/sh
# @file src/cli/emit.sh
# @description Emits the POSIX shell CLI and MCP stdio interface from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/mcp_handler.sh"

# handle_emit_cli generates the CLI application from the AST.
# @param $1: output_file - The destination path for the generated CLI script.
handle_emit_cli() {
	output_file="$1"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n"
		printf "# @openapi_cli_start\n"
		jq -r '
      .info as $info |
      "VERSION=\"\($info.version // "0.0.0")\"\n" +
      "TITLE=\"\($info.title // "CLI")\"\n" +
      "SUMMARY=\"\($info.summary // "")\"\n" +
      "DESCRIPTION=\"\($info.description // "")\"\n" +
      "TOS=\"\($info.termsOfService // "")\"\n" +
      "LICENSE=\"\($info.license.name // "")\"\n" +
      "LICENSE_URL=\"\($info.license.url // "")\"\n" +
      "LICENSE_ID=\"\($info.license.identifier // "")\"\n" +
      "CONTACT_NAME=\"\($info.contact.name // "")\"\n" +
      "CONTACT_URL=\"\($info.contact.url // "")\"\n" +
      "CONTACT_EMAIL=\"\($info.contact.email // "")\"\n" +
      "DIALECT=\"\(.jsonSchemaDialect // "")\"\n" +
      "OPENAPI_JSON=\"" + (del(.openapi, .info, .paths, .jsonSchemaDialect, .servers) | @json) + "\"\n"
    ' "${ast}"

		emit_mcp_handler_func
		printf "\n"

		printf "usage() {\n"
		printf "  echo \"\$TITLE - \$VERSION\"\n"
		printf "  echo \"\$SUMMARY\"\n"
		printf "  echo \"\$DESCRIPTION\"\n"
		printf "  echo \"Usage: \$0 [global-options] <command> [args]\"\n"
		printf "  echo \"Global Options:\"\n"
		printf "  echo \"  --server <url|name>   Set base server URL\"\n"
		printf "  echo \"Commands:\"\n"

		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "openapi";
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
      get_op_id($method; $path) as $opId |
      (if .summary == null then "Call \($method | ascii_upcase) \($path)" else .summary end) as $desc |
      "  echo \"  \($opId) - \($desc)\""
      else empty end
    ' "${ast}"

		printf "}\n"

		printf 'if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi\n'
		printf 'if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then echo "$VERSION"; exit 0; fi\n'

		printf 'SERVER_URL=""\n'
		printf 'if [ "${1:-}" = "--server" ]; then SERVER_URL="$2"; shift 2; fi\n'

		printf 'CMD="${1:-}"\n'
		printf "[ -z \"\$CMD\" ] && usage && exit 1\n"
		printf "shift\n"
		printf "case \"\$CMD\" in\n"

		tools_json_sh=$(jq -c -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "openapi"; emit_mcp_tools' "${ast}" | jq -R -r '@sh')

		cat <<EOF
  mcp)
    tools_json=${tools_json_sh}
    while read -r line || [ -n "\$line" ]; do
      if echo "\$line" | grep -qi "^Content-Length:"; then
        read -r _
        content_length=\$(echo "\$line" | awk '{print \$2}' | tr -d '\r\n')
        line=\$(dd bs=1 count="\$content_length" 2>/dev/null)
      elif echo "\$line" | grep -qi "^[A-Za-z-]\+: "; then
        continue
      elif [ -z "\$(echo "\$line" | tr -d '\r\n')" ]; then
        continue
      fi
      method=\$(echo "\$line" | jq -r '.method // empty')
      id=\$(echo "\$line" | jq -r '.id // null')
      if mcp_out=\$(mcp_handle_common "\$line" "\$TITLE" "\$VERSION" "openapi://spec" "OpenAPI Spec" "\$OPENAPI_JSON" "\$tools_json" "file://\$(pwd)"); then
        if [ -n "\$mcp_out" ]; then
          printf '%s\n' "\$mcp_out"
        fi
      elif [ "\$method" = "tools/call" ]; then
        tool_name=\$(echo "\$line" | jq -r '.params.name')
        args=\$(echo "\$line" | jq -c '.params.arguments // {}')
        
        eval_args=\$(echo "\$args" | jq -r 'to_entries | map("--" + .key + " " + (.value | tostring | @sh)) | join(" ")')
        
        set +e
        res=\$(eval "\$0 \$tool_name \$eval_args" 2>&1)
        exit_code=\$?
        set -e
        
        res_escaped=\$(printf "%s" "\$res" | jq -R -s '.')
        if [ "\$exit_code" -ne 0 ]; then
          printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":true,"content":[{"type":"text","text":%s}]}}\n' "\$id" "\$res_escaped"
        else
          printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":false,"content":[{"type":"text","text":%s}]}}\n' "\$id" "\$res_escaped"
        fi
      else
        if [ "\$id" != "null" ]; then
          echo "{\"jsonrpc\":\"2.0\",\"id\":\$id,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}"
        fi
      fi
    done
    ;;
EOF
		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "openapi";
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
      get_op_id($method; $path) as $opId |
      ((.parameters // []) + ($root.paths[$path].parameters // []) | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
      "  \($opId))\n" +
      "    while [ $# -gt 0 ]; do\n" +
      "      case \"$1\" in\n" +
      ([
        $params[] |
        "        --\(.name)) export \(.name | gsub("-"; "_"))=\"$2\"; shift 2;;"
      ] | join("\n")) +
      (if .requestBody then "\n        --body) export requestBody=\"$2\"; shift 2;;" else "" end) +
      "\n        *) echo \"Unknown flag $1\"; exit 1;;\n" +
      "      esac\n" +
      "    done\n" +
      "    echo \"Executing \($opId)...\"\n" +
      "    ;;"
      else empty end
    ' "${ast}"
		printf "  *) usage; exit 1;;\nesac\n"
		printf "# @openapi_cli_end\n"
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
