#!/bin/sh
# @file src/server/emit_daos.sh
# @description Emits stub and concrete DAO scripts for each OpenAPI operation.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_server_daos generates individual DAO files for the server.
# @param $1: out_dir - The output directory for DAO scripts (default: mocks).
handle_emit_server_daos() {
	out_dir="${1:-mocks}"
	export out_dir
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	mkdir -p "${out_dir}"

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_daos.jq" "${ast}" | awk -v dir="${out_dir}" '
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
