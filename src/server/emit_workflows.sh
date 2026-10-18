#!/bin/sh
# @file src/server/emit_workflows.sh
# @description Emits composable E2E Arazzo workflow test scripts for the generated server.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_server_workflows generates E2E workflow test files in the target test directory.
# @param $1: out_dir - The output directory for workflow test scripts (default: tests).
handle_emit_server_workflows() {
	out_dir="${1:-tests}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	mkdir -p "${out_dir}"

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_workflows.jq" "${ast}" | awk -v dir="${out_dir}" '
      /^###FILE###/ {
          if (out_file != "") { close(out_file) }
          file_name = substr($0, 11)
          out_file = dir "/" file_name
          printf "" > out_file
          next
      }
      {
          if (out_file != "") { print $0 >> out_file }
      }
      END {
          if (out_file != "") { close(out_file) }
      }
    '

	set +f
	for f in "${out_dir}"/*.sh; do
		if [ -f "$f" ]; then chmod +x "$f"; fi
	done
	set -f
}
