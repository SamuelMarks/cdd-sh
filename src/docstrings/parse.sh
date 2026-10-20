#!/bin/sh
# @file src/docstrings/parse.sh
# @description Parses Markdown documentation descriptions back into the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_docstrings parses docstrings into the AST.
# @param $1: file_path - The input Markdown file path (default: docs.md).
handle_parse_docstrings() {
	file_path="${1:-docs.md}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi":"3.2.0"}' >"${ast}"; fi
	if [ ! -f "${file_path}" ]; then return 0; fi

	all_raw=$(awk '
	# @function json_esc
	# @description Escapes backslashes, double quotes, and newlines for safe JSON string interpolation.
	# @param s - Input string to escape.
	function json_esc(s) {
		gsub(/\\/, "\\\\", s)
		gsub(/"/, "\\\"", s)
		gsub(/\n/, "\\n", s)
		return s
	}
	BEGIN { op = ""; desc = ""; info_desc = ""; in_info = 0 }
	/^# / {
	title_ver = substr($0, 3)
	split(title_ver, a, "(")
	title = a[1]; gsub(/ *$/, "", title)
	if (length(a) > 1) { ver = a[2]; gsub(/\)$/, "", ver) }
	in_info = 1
	next
	}
	/^## / {
	if (op != "") { ops[op] = desc; desc = "" }
	if (in_info) { in_info = 0 }
	op = substr($0, 4)
	next
	}
	/^[\*#-]/ { next }
	/^[A-Za-z0-9]/ {
	if (in_info) { info_desc = info_desc $0 "\n" }
	else if (op != "") { desc = desc $0 "\n" }
	}
	END {
	if (op != "") { ops[op] = desc }
	gsub(/\n$/, "", info_desc)
	printf "INFO:{\"title\": \"%s\", \"version\": \"%s\", \"description\": \"%s\"}\n", json_esc(title), json_esc(ver), json_esc(info_desc)

	printf "OPS:{"
	first=1
	for (o in ops) {
	  gsub(/\n$/, "", ops[o])
	  if (!first) printf ", "
	  first=0
	  printf "\"%s\": \"%s\"", json_esc(o), json_esc(ops[o])
	}
	printf "}\n"
	}
	' <"${file_path}")

	docs_info=$(printf '%s\n' "$all_raw" | awk '/^INFO:/ { print substr($0, 6) }')
	docs_ops=$(printf '%s\n' "$all_raw" | awk '/^OPS:/ { print substr($0, 5) }')
	if [ -n "$docs_info" ]; then
		jq --argjson info "$docs_info" --argjson ops "$docs_ops" '
      .info = ((.info // {}) * $info) |
      (
        if .paths then
          .paths |= with_entries(.value |= with_entries(
            if .value.operationId and $ops[.value.operationId] then
              .value.description = $ops[.value.operationId]
            else . end
          ))
        else . end
      )
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	fi
}
