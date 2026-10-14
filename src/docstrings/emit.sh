#!/bin/sh
# @file src/docstrings/emit.sh
# @description Emits Markdown API documentation from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_docstrings generates docstrings from the AST.
# @param $1: file_path - The destination Markdown file path (default: docs.md).
handle_emit_docstrings() {
	file_path="${1:-docs.md}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi

	{
		printf "# API Documentation\n\n"
		jq -r '
      if .info then
        "# \(.info.title // "API") (\(.info.version // "0.0.3"))\n\n" +
        "\(.info.description // "")\n\n"
      else empty end
    ' "${ast}"

		jq -r '
      if .paths then
        .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
        (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
        "## \($opId)\n\n" +
        "**Method**: \($method | ascii_upcase)\n" +
        "**Path**: \($path)\n\n" +
        "\(.description // .summary // "")\n\n" +
        (if .parameters then
          "### Parameters\n" +
          (.parameters | map("- `\(.name)` (\(.in)): \(.description // "")") | join("\n")) + "\n\n"
        else "" end) +
        (if .responses then
          "**Responses**:\n" +
          (.responses // {} | to_entries | map("- `\(.key)`: \(.value.description // "")") | join("\n")) + "\n\n"
        else "" end)
      else empty end
    ' "${ast}"
	} >"${file_path}"
}
