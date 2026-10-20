#!/bin/sh
# @file src/server/emit_tests.sh
# @description Emits composable integration test scripts for the generated server endpoints.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_server_tests generates individual test files for the server endpoints.
# @param $1: out_dir - The output directory for test scripts (default: tests).
handle_emit_server_tests() {
	out_dir="${1:-tests}"
	export out_dir
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_tests.jq" "${ast}" | emit_split_files "${out_dir}"
}
