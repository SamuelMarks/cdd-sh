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

# handle_emit_cli generates the CLI application from the AST.
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

		printf "usage() {\n"
		printf "  echo \"\$TITLE - \$VERSION\"\n"
		printf "  echo \"\$SUMMARY\"\n"
		printf "  echo \"\$DESCRIPTION\"\n"
		printf "  echo \"Usage: \$0 [global-options] <command> [args]\"\n"
		printf "  echo \"Global Options:\"\n"
		printf "  echo \"  --server <url|name>   Set base server URL\"\n"
		printf "  echo \"Commands:\"\n"

		jq -r '
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
      (if .operationId then (.operationId | gsub("([a-z])([A-Z])"; "\(.captures[0].string)_\(.captures[1].string)") | ascii_downcase) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
      (if .summary == null then "Call \($method | ascii_upcase) \($path)" else .summary end) as $desc |
      "  echo \"  \($opId) - \($desc)\""
      else empty end
    ' "${ast}"

		printf "}\n"

		printf "if [ \"${1:-}\" = \"--help\" ] || [ \"${1:-}\" = \"-h\" ]; then usage; exit 0; fi\n"
		printf "if [ \"${1:-}\" = \"--version\" ] || [ \"${1:-}\" = \"-v\" ]; then echo \"\$VERSION\"; exit 0; fi\n"

		printf "SERVER_URL=\"\"\n"
		printf "if [ \"${1:-}\" = \"--server\" ]; then SERVER_URL=\"\$2\"; shift 2; fi\n"

		printf "CMD=\"\${1:-}\"\n"
		printf "[ -z \"\$CMD\" ] && usage && exit 1\n"
		printf "shift\n"
		printf "case \"\$CMD\" in\n"
		cat <<'EOF'
  mcp)
    while read -r line || [ -n "$line" ]; do
      if echo "$line" | grep -qi "^Content-Length:"; then
        read -r empty_line
        content_length=$(echo "$line" | awk '{print $2}' | tr -d '\r\n')
        line=$(dd bs=1 count="$content_length" 2>/dev/null)
      elif echo "$line" | grep -qi "^[A-Za-z-]\+: "; then
        continue
      elif [ -z "$(echo "$line" | tr -d '\r\n')" ]; then
        continue
      fi
      method=$(echo "$line" | jq -r '.method // empty')
      id=$(echo "$line" | jq -r '.id // null')
      if [ "$method" = "initialize" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{\"listChanged\":true},\"resources\":{\"listChanged\":true,\"subscribe\":true},\"logging\":{},\"prompts\":{\"listChanged\":true}},\"serverInfo\":{\"name\":\"$TITLE\",\"version\":\"$VERSION\"}}}"
      elif [ "$method" = "notifications/initialized" ] || [ "$method" = "initialized" ]; then
        : # Do nothing for initialized notification
      elif [ "$method" = "notifications/tools/list_changed" ] || [ "$method" = "notifications/resources/list_changed" ] || [ "$method" = "notifications/prompts/list_changed" ] || [ "$method" = "notifications/roots/list_changed" ] || [ "$method" = "notifications/resources/updated" ]; then
        : # Do nothing for list changed notifications
      elif [ "$method" = "notifications/cancelled" ] || [ "$method" = "notifications/progress" ]; then
        : # Do nothing for cancelled/progress notification
      elif [ "$method" = "notifications/message" ]; then
        level=$(echo "$line" | jq -r '.params.level // "info"')
        msg=$(echo "$line" | jq -r '.params.data // ""')
        echo "[$level] $msg" >&2

      elif [ "$method" = "ping" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      elif [ "$method" = "roots/list" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"roots\":[{\"uri\":\"file://$(pwd)\",\"name\":\"Workspace\"}]}}" 
      elif [ "$method" = "prompts/list" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"prompts\":[{\"name\":\"test_prompt\",\"description\":\"A test prompt\",\"arguments\":[{\"name\":\"arg1\",\"description\":\"An argument\",\"required\":true}]}]}}"
      elif [ "$method" = "prompts/get" ]; then
        prompt_name=$(echo "$line" | jq -r '.params.name // empty')
        if [ "$prompt_name" = "test_prompt" ]; then
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"description\":\"A test prompt\",\"messages\":[{\"role\":\"user\",\"content\":{\"type\":\"text\",\"text\":\"Please test this\"}}]}}"
        else
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32602,\"message\":\"Invalid prompt\"}}"
        fi
      elif [ "$method" = "completion/complete" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"completion\":{\"values\":[],\"total\":0,\"hasMore\":false}}}"
      elif [ "$method" = "sampling/createMessage" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"role\":\"assistant\",\"content\":{\"type\":\"text\",\"text\":\"Sampled message\"},\"model\":\"test-model\",\"stopReason\":\"endTurn\"}}"
      elif [ "$method" = "logging/setLevel" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
      elif [ "$method" = "resources/list" ]; then
        cursor=$(echo "$line" | jq -r '.params.cursor // empty')
        if [ "$cursor" = "next" ]; then
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resources\":[]}}"
        else
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resources\":[{\"uri\":\"openapi://spec\",\"name\":\"OpenAPI Spec\",\"mimeType\":\"application/json\"}],\"nextCursor\":\"next\"}}"
        fi
      elif [ "$method" = "resources/templates/list" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resourceTemplates\":[]}}"
      elif [ "$method" = "resources/subscribe" ] || [ "$method" = "resources/unsubscribe" ]; then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"  
      elif [ "$method" = "resources/read" ]; then
        uri=$(echo "$line" | jq -r '.params.uri')
        if [ "$uri" = "openapi://spec" ]; then
          spec_escaped=$(printf "%s" "$OPENAPI_JSON" | jq -R -s '.')
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"contents\":[{\"uri\":\"openapi://spec\",\"mimeType\":\"application/json\",\"text\":$spec_escaped}]}}"
        else
          echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32602,\"message\":\"Invalid URI\"}}"
        fi
      elif [ "$method" = "tools/list" ]; then
EOF

		# Generate the static JSON string for tools/list
		tools_json=$(jq -c '
		  if .paths then
		    [
		      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
		      (if .operationId then (.operationId | gsub("([a-z])([A-Z])"; "\(.captures[0].string)_\(.captures[1].string)") | ascii_downcase) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
		      {
		        name: $opId,
		        description: (.summary // "Call \($method) \($path)"),
		        inputSchema: {
		          type: "object",
		          properties: (
		            ((.parameters // []) | map({(.name): {type: (.schema.type // "string")}})) | add // {}
		          ),
		          required: (
		            ((.parameters // []) | map(select(.required == true) | .name)) // []
		          )
		        }
		      }
		    ]
		  else
		    []
		  end
		' "${ast}")

		cat <<EOF
        tools_json='$(echo "$tools_json" | sed "s/'/'\\\\''/g")'
        cursor=\$(echo "\$line" | jq -r '.params.cursor // empty'); if [ "\$cursor" = "next" ]; then echo "{\"jsonrpc\":\"2.0\",\"id\":\$id,\"result\":{\"tools\":[]}}"; else echo "{\"jsonrpc\":\"2.0\",\"id\":\$id,\"result\":{\"tools\":\$tools_json,\"nextCursor\":\"next\"}}"; fi
      elif [ "\$method" = "tools/call" ]; then
        tool_name=\$(echo "\$line" | jq -r '.params.name')
        args=\$(echo "\$line" | jq -c '.params.arguments // {}')
        
        eval_args=\$(echo "\$args" | jq -r 'to_entries | map("--\(.key) '\''\(.value)'\''") | join(" ")')
        
        # We capture the exit status
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
		jq -r '
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
      (if .operationId then (.operationId | gsub("([a-z])([A-Z])"; "\(.captures[0].string)_\(.captures[1].string)") | ascii_downcase) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
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
