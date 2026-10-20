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

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_daos.jq" "${ast}" | emit_split_files "${out_dir}"
}
