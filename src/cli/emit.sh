#!/bin/sh
# @file src/cli/emit.sh
# @description Emits the POSIX shell CLI, Arazzo workflow runner, and MCP stdio interface from the unified AST.
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
		printf "# @file %s\n" "${output_file##*/}"
		printf "# @description Auto-generated CLI, workflow runner, and MCP server.\n"
		printf "# shellcheck disable=SC2016,SC2034,SC1091\n"
		printf "# @openapi_cli_start\n"
		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "arazzo";
      (.info // .arazzoInfo // {}) as $info |
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
      "ARAZZO_VERSION=\"\(.arazzo // "")\"\n" +
      "OPENAPI_JSON=" + (del(.openapi, .info, .paths, .jsonSchemaDialect, .servers, .arazzo, .arazzoSelf, .arazzoInfo, .sourceDescriptions, .workflows, .arazzoComponents, .arazzoExtensions, .x_resolved_sources) | tojson | @sh) + "\n" +
      (if (.workflows and (.workflows | length) > 0) or .arazzo then
        "ARAZZO_JSON=" + (extract_arazzo_spec | tojson | @sh) + "\n"
      else
        "ARAZZO_JSON=\"\"\n"
      end)
    ' "${ast}"

		cat <<'INNER_EOF'
_CLI_DIR="$(cd "$(dirname -- "$0")" && pwd)"
if [ -f "${_CLI_DIR}/../src/workflows.sh" ]; then
  # shellcheck disable=SC1091
  . "${_CLI_DIR}/../src/workflows.sh"
elif [ -f "${_CLI_DIR}/workflows.sh" ]; then
  # shellcheck disable=SC1091
  . "${_CLI_DIR}/workflows.sh"
fi
INNER_EOF
		printf "\n"
		emit_mcp_handler_func
		printf "\n"

		cat <<'INNER_EOF'
# cli_mcp_tool_dispatch dispatches MCP tools/call requests to workflows or CLI operation commands.
# @param $1: tool_name - The invoked MCP tool name.
# @param $2: args - JSON object string of tool arguments.
# @return Prints the tool execution output and returns its exit status.
cli_mcp_tool_dispatch() {
  _cli_tname="$1"
  _cli_targs="$2"
  case "${_cli_tname}" in
    workflow_*)
      _mcp_wf_id="${_cli_tname#workflow_}"
      "$0" workflow run "$_mcp_wf_id" --inputs "$_cli_targs"
      ;;
    *)
      eval_args=$(printf '%s\n' "$_cli_targs" | jq -r 'to_entries | map(select(.key | test("^[a-zA-Z0-9_-]+$")) | "--" + .key + " " + (.value | tostring | @sh)) | join(" ")')
      eval "\"$0\" \"$_cli_tname\" $eval_args"
      ;;
  esac
}
INNER_EOF

		printf "# usage prints CLI help information.\n"
		printf "# @param none\n"
		printf "usage() {\n"
		printf "  echo \"\$TITLE - \$VERSION\"\n"
		printf "  echo \"\$SUMMARY\"\n"
		printf "  echo \"\$DESCRIPTION\"\n"
		printf "  echo \"Usage: \$0 [global-options] <command> [args]\"\n"
		printf "  echo \"Global Options:\"\n"
		printf "  echo \"  --server <url|name>   Set base server URL\"\n"
		printf "  echo \"Commands:\"\n"
		printf "  echo \"  workflow              List or run Arazzo 1.1.0 workflows\"\n"

		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "openapi";
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path |
      (if .value."$ref" and $root.components and $root.components.pathItems then ($root.components.pathItems[.value."$ref" | sub("^#/components/pathItems/"; "")] // .value) else .value end) |
      ((to_entries | map(select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers" and .key != "$ref" and .key != "additionalOperations"))) +
       (if .additionalOperations then (.additionalOperations | to_entries) else [] end))[] |
      .key as $method | .value |
      get_op_id($method; $path) as $opId |
      (if .summary == null then "Call \($method | ascii_upcase) \($path)" else .summary end) as $desc |
      "  echo \"  \($opId) - \($desc)\""
      else empty end
    ' "${ast}"

		printf "}\n"

		printf 'if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi\n'
		printf 'if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then echo "$VERSION"; exit 0; fi\n'

		printf 'SERVER_URL=""\n'
		printf 'if [ "${1:-}" = "--server" ]; then\n'
		printf '  SERVER_URL="$2"; export BASE_URL="$2"; shift 2\n'
		printf '  if [ -f "${_CLI_DIR}/../src/routes.sh" ]; then . "${_CLI_DIR}/../src/routes.sh"; elif [ -f "${_CLI_DIR}/routes.sh" ]; then . "${_CLI_DIR}/routes.sh"; fi\n'
		printf 'fi\n'

		printf 'CMD="${1:-}"\n'
		printf "[ -z \"\$CMD\" ] && usage && exit 1\n"
		printf "shift\n"
		printf "case \"\$CMD\" in\n"

		cat <<'INNER_EOF'
  workflow)
    _wf_subcmd="${1:-list}"
    if [ "$#" -gt 0 ]; then shift; fi
    case "${_wf_subcmd}" in
      --help|-h|help)
        echo "$TITLE - $VERSION (Arazzo ${ARAZZO_VERSION:-1.1.0})"
        echo "$SUMMARY"
        echo "$DESCRIPTION"
        echo "Usage: $0 workflow <list|run> [workflowId] [options]"
        if [ -n "${ARAZZO_JSON:-}" ]; then
          printf '%s' "${ARAZZO_JSON}" | jq -r '.workflows[]? | "  \(.workflowId) - \(.summary // .description // "Workflow")"'
        fi
        exit 0
        ;;
      --version|-v)
        echo "${VERSION} (arazzo ${ARAZZO_VERSION:-1.1.0})"
        exit 0
        ;;
      list)
        if [ -n "${ARAZZO_JSON:-}" ]; then
          printf '%s\n' "${ARAZZO_JSON}" | jq -r '.workflows[]? | "\(.workflowId)\t\(.summary // .description // "")\tdeps=\((.dependsOn // []) | join(","))"'
        fi
        exit 0
        ;;
      run)
        _run_wf_id="${1:-}"
        if [ -z "${_run_wf_id}" ]; then
          echo "Error: workflowId required for 'workflow run'" >&2
          exit 1
        fi
        shift
        _run_inputs="{}"
        _run_step=""
        _run_format="json"
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --inputs)
              _run_inputs="$2"
              shift 2
              ;;
            --input-file|--data-file)
              if [ ! -f "$2" ]; then echo "Error: input file $2 not found" >&2; exit 1; fi
              _run_inputs=$(cat "$2")
              shift 2
              ;;
            --step)
              _run_step="$2"
              shift 2
              ;;
            --format)
              _run_format="$2"
              shift 2
              ;;
            --server)
              export BASE_URL="$2"
              shift 2
              ;;
            -v|--verbose)
              export ARAZZO_VERBOSE=1
              shift 1
              ;;
            --*)
              _flag_k="${1#--}"
              _flag_v="${2:-}"
              _run_inputs=$(printf '%s' "${_run_inputs}" | jq -c --arg k "${_flag_k}" --arg v "${_flag_v}" '. + {($k): (($v | fromjson?) // $v)}')
              shift 2
              ;;
            *)
              echo "Unknown workflow flag: $1" >&2
              exit 1
              ;;
          esac
        done
        _wf_fn="workflow_$(printf '%s' "${_run_wf_id}" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_]/_/g')"
        if type "${_wf_fn}" >/dev/null 2>&1; then
          _wf_raw_out=$("${_wf_fn}" "${_run_inputs}" "${_run_step}") || exit 1
        else
          echo "Error: workflow function ${_wf_fn} not found" >&2
          exit 1
        fi
        case "${_run_format}" in
          table)
            printf '%s\n' "${_wf_raw_out}" | jq -r 'to_entries[] | "\(.key)\t\(.value)"'
            ;;
          yaml)
            printf '%s\n' "${_wf_raw_out}" | jq -r 'to_entries[] | "\(.key): \(.value | tojson)"'
            ;;
          *)
            printf '%s\n' "${_wf_raw_out}"
            ;;
        esac
        ;;
      *)
        echo "Unknown workflow subcommand: ${_wf_subcmd}" >&2
        exit 1
        ;;
    esac
    ;;
INNER_EOF

		tools_json_sh=$(jq -c -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "openapi"; include "arazzo"; (emit_mcp_tools + emit_mcp_workflow_tools)' "${ast}" | jq -R -r '@sh')

		cat <<INNER_EOF
  mcp)
    tools_json=${tools_json_sh}
    mcp_serve_stdio "\$TITLE" "\$VERSION" "openapi://spec" "OpenAPI Spec" "\$OPENAPI_JSON" "\$tools_json" "file://\$(pwd)" "cli_mcp_tool_dispatch"
    ;;
INNER_EOF
		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "openapi";
      . as $root |
      if .paths then
      .paths | to_entries[] | .key as $path |
      (if .value."$ref" and $root.components and $root.components.pathItems then ($root.components.pathItems[.value."$ref" | sub("^#/components/pathItems/"; "")] // .value) else .value end) as $pathItem |
      ($pathItem | (to_entries | map(select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers" and .key != "$ref" and .key != "additionalOperations"))) +
       (if .additionalOperations then (.additionalOperations | to_entries) else [] end))[] |
      .key as $method | .value |
      (if .requestBody and .requestBody."$ref" and $root.components and $root.components.requestBodies then
        .requestBody = ($root.components.requestBodies[.requestBody."$ref" | sub("^#/components/requestBodies/"; "")] // .requestBody)
      else . end) |
      get_op_id($method; $path) as $opId |
      get_raw_op_id($method; $path) as $rawOpId |
      ((.parameters // []) + ($pathItem.parameters // []) | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
      ([
        ($params[] | "\"${\(.name | gsub("-"; "_")):-}\""),
        (if .requestBody then "\"${requestBody:-}\"" else empty end)
      ] | join(" ")) as $callArgs |
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
      "    if [ -n \"${SERVER_URL:-}\" ] && type \($rawOpId) >/dev/null 2>&1; then\n" +
      (if $callArgs != "" then "      \($rawOpId) \($callArgs)\n" else "      \($rawOpId)\n" end) +
      "    else\n" +
      "      echo \"Executing \($opId)...\"\n" +
      "    fi\n" +
      "    ;;"
      else empty end
    ' "${ast}"
		printf "  *) usage; exit 1;;\nesac\n"
		printf "# @openapi_cli_end\n"
	} >"${output_file}.tmp"

	merge_or_move_emitted_file "${output_file}" "1"
}
