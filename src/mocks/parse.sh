#!/bin/sh
# @file src/mocks/parse.sh
# @description Parses mock response JSON payloads back into the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_mocks parses mocks into the AST.
# @param $1: file_path - The input mocks JSON file path (default: mocks.json).
handle_parse_mocks() {
	file_path="${1:-mocks.json}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: file not found at %s\n" "${file_path}" >&2
		return 1
	fi
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo "{}" >"${ast}"; fi
	# Update AST components with edited mocks
	jq --slurpfile mocks "${file_path}" 'if .components == null then .components = {} else . end | .components.examples = $mocks[0]' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
