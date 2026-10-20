#!/bin/sh
# @file src/functions/parse.sh
# @description Parses standalone utility functions from a shell script into x-functions in the AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_functions parses standalone utility functions into the AST.
# @param $1: file_path - The input shell script path (default: functions.sh).
handle_parse_functions() {
	file_path="${1:-functions.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi":"3.2.0"}' >"${ast}"; fi
	if [ ! -f "${file_path}" ]; then return 0; fi

	funcs_json=$(awk '
      # @function json_esc
      # @description Escapes backslashes, double quotes, and newlines for safe JSON string interpolation.
      # @param s - Input string to escape.
      function json_esc(s) {
        gsub(/\\/, "\\\\", s)
        gsub(/"/, "\\\"", s)
        gsub(/\n/, "\\n", s)
        return s
      }
      BEGIN {
        printf "{"
        first=1
        in_func=0
        desc=""
        func_name=""
        body=""
      }
      /^# @function / {
        func_name=$3
        in_func=1
        desc=""
        body=""
      }
      /^# @description / {
        if (in_func) {
          desc=substr($0, 16)
        }
      }
      /^\}/ {
        if (in_func) {
          if (!first) printf ", "
          first=0
          printf "\"%s\": {\"description\": \"%s\", \"body\": \"%s\"}", json_esc(func_name), json_esc(desc), json_esc(body)
          in_func=0
          func_name=""
          desc=""
          body=""
        }
      }
      {
        if (in_func && $0 !~ /^#/ && $0 !~ /\(\) \{/ && $0 !~ /^\}/) {
          line = $0
          gsub(/^  /, "", line)
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
