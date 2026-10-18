#!/bin/sh
# @file src/server/parse.sh
# @description Parses a generated server script and its route dispatcher into the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_server parses a server.sh file and its accompanying router.sh into the OpenAPI AST.
# @param $1: file_path - Path to the server.sh script.
handle_parse_server() {
	file_path="${1:-server.sh}"
	if [ ! -f "${file_path}" ]; then return 1; fi

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi": "3.2.0", "info": {"title": "Parsed API", "version": "0.0.4"}}' >"${ast}"; fi

	tools_json_raw=$(awk -v sq="'" '
      BEGIN { in_tools = 0; tools_data = "" }
      index($0, "tools_json=" sq "[") > 0 {
          in_tools = 1
          s = substr($0, index($0, sq) + 1)
          if (substr(s, length(s), 1) == sq) {
              tools_data = substr(s, 1, length(s) - 1)
              in_tools = 0
              print tools_data
              exit
          }
          tools_data = s
          next
      }
      in_tools == 1 {
          idx = index($0, sq)
          if (idx > 0) {
              tools_data = tools_data substr($0, 1, idx - 1)
              in_tools = 0
              print tools_data
              exit
          } else {
              tools_data = tools_data $0
          }
      }
    ' "$file_path")

	if [ -z "$tools_json_raw" ]; then
		tools_json_raw="[]"
	fi

	server_dir=$(dirname -- "$file_path")
	router_file="$file_path"
	if [ -f "${server_dir}/routes/router.sh" ]; then
		router_file="${server_dir}/routes/router.sh"
	elif [ -f "${server_dir}/../routes/router.sh" ]; then
		router_file="${server_dir}/../routes/router.sh"
	fi

	routes_json_raw=$(awk -v dq='"' '
      BEGIN {
          printf "["
          first = 1
          path = ""
          method = ""
      }
      # Match case pattern: "METHOD:/path"|"METHOD:/path*"
      /"[A-Z]+:\/[^"]*"/ {
          line = $0
          sub(/^[^"]*"/, "", line)
          sub(/".*$/, "", line)
          colon = index(line, ":")
          if (colon > 0) {
              method = tolower(substr(line, 1, colon - 1))
              path = substr(line, colon + 1)
          }
      }
      # Match legacy if/elif [ "$path" = "/..." ] && [ "$method" = "..." ]
      index($0, dq "$path" dq " = " dq) > 0 && index($0, dq "$method" dq " = " dq) > 0 {
          line = $0
          p_pat = dq "$path" dq " = " dq
          p_start = index(line, p_pat)
          if (p_start > 0) {
              rest = substr(line, p_start + length(p_pat))
              p_end = index(rest, dq)
              path = substr(rest, 1, p_end - 1)
          }
          m_pat = dq "$method" dq " = " dq
          m_start = index(line, m_pat)
          if (m_start > 0) {
              rest = substr(line, m_start + length(m_pat))
              m_end = index(rest, dq)
              method = tolower(substr(rest, 1, m_end - 1))
          }
      }
      /res=\$\(dao_\$\{ACTIVE_DAO\}_/ {
          line = $0
          prefix = "res=$(dao_${ACTIVE_DAO}_"
          idx = index(line, prefix)
          if (idx > 0 && path != "" && method != "") {
              rest = substr(line, idx + length(prefix))
              end_idx = index(rest, ")")
              if (end_idx > 0) {
                  op_id = substr(rest, 1, end_idx - 1)
                  if (!first) printf ","
                  first = 0
                  printf "{%smethod%s:%s%s%s,%spath%s:%s%s%s,%soperationId%s:%s%s%s}", dq, dq, dq, method, dq, dq, dq, dq, path, dq, dq, dq, dq, op_id, dq
                  path = ""
                  method = ""
              }
          }
      }
      END {
          printf "]\n"
      }
    ' "$router_file")

	parsed_paths=$(printf '%s\n' "$tools_json_raw" | jq --argjson routes "$routes_json_raw" '
      . as $tools |
      if ($routes | length) > 0 then
        reduce $routes[] as $route (
          {"paths": {}};
          .paths[$route.path] = (.paths[$route.path] // {}) + {
            ($route.method): (
              ($tools | map(select(.name == $route.operationId))[0] // {}) as $tool |
              {
                operationId: $route.operationId,
                summary: ($tool.description // ""),
                parameters: (
                  if $tool.inputSchema and $tool.inputSchema.properties then
                    $tool.inputSchema.properties | to_entries | map(
                      . as $entry |
                      if ($route.path | contains("{" + $entry.key + "}")) then
                        {name: $entry.key, in: "path", required: true, schema: $entry.value}
                      elif ($entry.key == "body") then
                        empty
                      else
                        {name: $entry.key, in: "query", required: (($tool.inputSchema.required // []) | contains([$entry.key])), schema: $entry.value}
                      end
                    )
                  else [] end
                ),
                requestBody: (
                  if $tool.inputSchema and $tool.inputSchema.properties and $tool.inputSchema.properties.body then
                    {
                      content: {
                        "application/json": {
                          schema: $tool.inputSchema.properties.body
                        }
                      }
                    }
                  else null end
                )
              } | with_entries(select(.value != null and .value != []))
            )
          }
        )
      elif ($tools | length) > 0 then
        reduce $tools[] as $tool (
          {"paths": {}};
          .paths["/" + $tool.name] = {
            "post": {
              operationId: $tool.name,
              summary: ($tool.description // "")
            }
          }
        )
      else
        {"paths": {}}
      end
    ')

	jq --argjson newpaths "$parsed_paths" '.paths = ((.paths // {}) * ($newpaths.paths // {}))' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"

	arazzo_srv_raw=$(awk -v sq="'" '
		/^ARAZZO_SERVER_JSON=/ {
			aj = substr($0, 20)
			if (substr(aj, 1, 1) == sq) aj = substr(aj, 2)
			if (substr(aj, length(aj), 1) == sq) aj = substr(aj, 1, length(aj) - 1)
			gsub(sq "\\\\" sq sq, sq, aj)
			gsub(sq "\\" sq sq, sq, aj)
			if (aj != "\"\"") print aj
		}
	' "$file_path")

	if [ -n "$arazzo_srv_raw" ] && printf '%s' "$arazzo_srv_raw" | jq -e '.' >/dev/null 2>&1; then
		norm_arz=$(printf '%s' "$arazzo_srv_raw" | jq -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "arazzo"; normalize_arazzo_root')
		jq --argjson arz "$norm_arz" '. * $arz' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	elif [ -f "${server_dir}/workflows.sh" ] && type handle_parse_workflows >/dev/null 2>&1; then
		handle_parse_workflows "${server_dir}/workflows.sh"
	fi
}
