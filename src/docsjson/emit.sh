#!/bin/sh
# @file src/docsjson/emit.sh
# @description Emits JSON documentation with shell code snippets from an OpenAPI or Arazzo specification.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_to_docs_json outputs the AST as a documentation JSON format.
# @param $@: CLI flags (-i/--input, -o/--output, --no-imports, --no-wrapping)
handle_to_docs_json() {
	input_file="${CDD_INPUT:-}"
	output_file="${CDD_OUTPUT:-}"
	no_imports="false"
	no_wrapping="false"
	if [ "${CDD_NO_IMPORTS:-0}" = "1" ]; then no_imports="true"; fi
	if [ "${CDD_NO_WRAPPING:-0}" = "1" ]; then no_wrapping="true"; fi

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-i | --input)
			input_file="$2"
			shift 2
			;;
		-o | --output)
			output_file="$2"
			shift 2
			;;
		--no-imports)
			no_imports="true"
			shift 1
			;;
		--no-wrapping)
			no_wrapping="true"
			shift 1
			;;
		*)
			printf "Unknown option %s\n" "$1" >&2
			exit 1
			;;
		esac
	done

	if [ -z "$input_file" ]; then
		printf "Error: -i/--input is required\n" >&2
		exit 1
	fi
	if [ ! -f "$input_file" ]; then
		printf "Error: Input file %s not found\n" "$input_file" >&2
		exit 1
	fi

	res=$(jq -n -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" --slurpfile spec "$input_file" \
		--arg no_imports "$no_imports" \
		--arg no_wrapping "$no_wrapping" '
    include "openapi";
    include "arazzo";
    {
      "endpoints": (
        if $spec[0].paths then
          $spec[0].paths | to_entries | map(
            .key as $path |
            .value | to_entries | map(
              select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") |
              .key as $method |
              .value |
              get_docs_op_id($method; $path) as $opId |
              
              (
                (if $no_imports == "false" then ". ./routes.sh\n\n" else "" end) +
                (if $no_wrapping == "false" then "main() {\n" else "" end) +
                "  " + $opId + (if .parameters then (.parameters | map(" \"dummy\"") | join("")) else "" end) + "\n" +
                (if $no_wrapping == "false" then "}\n\nmain \"$@\"\n" else "" end)
              ) as $finalCode |
              
              {
                "key": ($method | ascii_downcase),
                "value": $finalCode
              }
            ) | from_entries |
            { "key": $path, "value": . }
          ) | from_entries
        else
          {}
        end
      )
    } + (
      if $spec[0].workflows and ($spec[0].workflows | length) > 0 then
        {
          "workflows": (
            $spec[0].workflows | map(
              .workflowId as $wfId |
              get_workflow_fn_name($wfId) as $fnName |
              (
                (if $no_imports == "false" then ". ./workflows.sh\n\n" else "" end) +
                (if $no_wrapping == "false" then "main() {\n" else "" end) +
                "  " + $fnName + " \"{}\"\n" +
                (if $no_wrapping == "false" then "}\n\nmain \"$@\"\n" else "" end)
              ) as $wfCode |
              { "key": $wfId, "value": $wfCode }
            ) | from_entries
          )
        }
      else
        {}
      end
    )
  ')
	if [ -n "$output_file" ]; then
		printf "%s\n" "$res" >"$output_file"
	else
		printf "%s\n" "$res"
	fi
}

# handle_emit_docsjson emits the documentation JSON from the current AST file.
# @param $1: file_path - The destination path for the documentation JSON.
handle_emit_docsjson() {
	file_path="${1:-emitted_docsjson.json}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi
	handle_to_docs_json -i "${ast}" -o "${file_path}"
}
