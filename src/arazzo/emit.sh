#!/bin/sh
# @file src/arazzo/emit.sh
# @description Emits the Arazzo 1.1.0 JSON specification from the unified CDD AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_arazzo outputs the Arazzo 1.1.0 JSON specification from the AST.
# @param $1: file_path - The destination path for the generated Arazzo JSON specification (default: emitted_arazzo.json).
handle_emit_arazzo() {
	file_path="${1:-emitted_arazzo.json}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi

	jq -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/arazzo/emit.jq" "${ast}" >"${file_path}"
}
