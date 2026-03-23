#!/bin/sh
set -feu
if [ "${SCRIPT_NAME-}" ]; then this_file="${SCRIPT_NAME}"; elif [ "${BASH_SOURCE-}" ]; then this_file="${BASH_SOURCE[0]}"; set -o pipefail; else this_file="${0}"; fi
case "${STACK+x}" in *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd -- "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

handle_emit_cli() {
  output_file="$1"
  ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
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
      (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"); "_") | gsub("[{}]"; ""))" end) as $opId |
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
    jq -r '
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
      (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"); "_") | gsub("[{}]"; ""))" end) as $opId |
      ((.parameters // []) + ($root.paths[$path].parameters // []) | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
      "  \($opId))\n" +
      "    while [ \$# -gt 0 ]; do\n" +
      "      case \"\$1\" in\n" +
      ([
        $params[] |
        "        --\(.name)) export \(.name | gsub("-"; "_"))=\"\$2\"; shift 2;;"
      ] | join("\n")) +
      (if .requestBody then "\n        --body) export requestBody=\"\$2\"; shift 2;;" else "" end) +
      "\n        *) echo \"Unknown flag \$1\"; exit 1;;\n" +
      "      esac\n" +
      "    done\n" +
      "    echo \"Executing \($opId)...\"\n" +
      "    ;;"
      else empty end
    ' "${ast}"
    printf "  *) usage; exit 1;;\nesac\n"
    printf "# @openapi_cli_end\n"
  } > "${output_file}.tmp"
  
  if [ -f "${output_file}" ]; then
    awk -v new_file="${output_file}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" "${output_file}" > "${output_file}.merged"
    mv "${output_file}.merged" "${output_file}"
    rm -f "${output_file}.tmp"
  else
    mv "${output_file}.tmp" "${output_file}"
  fi
  chmod +x "${output_file}"
}
