#!/bin/sh
# @file src/server/emit_routes.sh
# @description Emits the HTTP route dispatcher script (router.sh) for the generated server.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_server_routes generates individual route files for the server.
# @param $1: out_dir - The output directory for route scripts (default: routes).
handle_emit_server_routes() {
	out_dir="${1:-routes}"
	export out_dir
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_routes.jq" "${ast}" | emit_split_files "${out_dir}"
}
