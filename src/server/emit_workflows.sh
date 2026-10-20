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

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_workflows.jq" "${ast}" | emit_split_files "${out_dir}"
}
