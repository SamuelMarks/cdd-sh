#!/bin/sh
# @file src/functions/emit.sh
# @description Emits standalone utility functions and x-functions OpenAPI extensions to a shell script.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_functions generates standalone utility functions and x-functions from the AST.
# @param $1: file_path - The destination shell script path (default: functions.sh).
handle_emit_functions() {
	file_path="${1:-functions.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi
	{
		printf "#!/bin/sh\n"
		printf "# Utility functions based on openapi extensions.\n\n"
		printf "# _urlencode encodes a string for safe inclusion in a URL.\n"
		printf "# @param \$1: The string to encode.\n"
		printf "_urlencode() {\n"
		printf "  jq -nr --arg v \"\$1\" '\$v|@uri'\n"
		printf "}\n\n"
		jq -r '
      if ."x-functions" then
        ."x-functions" | to_entries[] |
        "# @function \(.key)\n" +
        (if .value.description then "# @description \(.value.description)\n" else "" end) +
        "\(.key)() {\n" +
        "  \(.value.body // ":")\n" +
        "}\n"
      else empty end
    ' "${ast}"
	} >"${file_path}"
}
