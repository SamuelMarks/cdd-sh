#!/bin/sh
# @file src/functions/parse.sh
# @description Parses standalone utility functions from a shell script into x-functions in the AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_functions parses annotated functions into x-functions in the AST.
# @param $1: file_path - The input shell script path (default: functions.sh).
handle_parse_functions() {
	file_path="${1:-functions.sh}"
	if [ ! -f "${file_path}" ]; then return 1; fi
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi": "3.2.0"}' >"${ast}"; fi

	funcs_json=$(awk -v dq='"' '
      BEGIN {
          printf "{"
          first = 1
          fname = ""
          desc = ""
          in_body = 0
          body = ""
      }
      /^# @function / {
          fname = $3
          desc = ""
          body = ""
          next
      }
      /^# @description / {
          desc = substr($0, 16)
          next
      }
      /^[a-zA-Z0-9_]+\(\) \{/ {
          if (fname != "") {
              in_body = 1
              next
          }
      }
      in_body == 1 {
          if ($0 ~ /^}/) {
              in_body = 0
              gsub(/\\/, "\\\\", body)
              gsub(/"/, "\\\"", body)
              gsub(/\n/, "\\n", body)
              gsub(/"/, "\\\"", desc)
              if (!first) printf ","
              first = 0
              printf "%s%s%s:{%sdescription%s:%s%s%s,%sbody%s:%s%s%s}", dq, fname, dq, dq, dq, dq, desc, dq, dq, dq, dq, body, dq
              fname = ""
              desc = ""
              body = ""
          } else {
              line = $0
              sub(/^[ \t]+/, "", line)
              if (body != "") body = body "\n" line
              else body = line
          }
      }
      END {
          printf "}\n"
      }
    ' "${file_path}")

	if [ "$funcs_json" != "{}" ]; then
		jq --argjson funcs "$funcs_json" '."x-functions" = ((."x-functions" // {}) * $funcs)' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	fi
}
