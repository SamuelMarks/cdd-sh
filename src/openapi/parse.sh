#!/bin/sh
# @file src/openapi/parse.sh
# @description Parses OpenAPI 3.x and Swagger 2.0 specifications into the unified OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_openapi parses an OpenAPI spec into the AST.
# @param $1: file_path - The input OpenAPI or Swagger 2.0 JSON file path.
handle_parse_openapi() {
	file_path="${1}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: OpenAPI file not found at %s\n" "${file_path}" >&2
		return 1
	fi
	# Convert openapi to ast.json (direct copy, maybe minified/formatted)
	jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/swagger2openapi.jq" "${file_path}" >"${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
}

# handle_parse_openapi_dir merges all OpenAPI specs in a directory into the AST.
# @param $1: dir_path - The directory containing OpenAPI JSON files.
handle_parse_openapi_dir() {
	dir_path="${1}"
	if [ ! -d "${dir_path}" ]; then
		printf "Error: OpenAPI directory not found at %s\n" "${dir_path}" >&2
		return 1
	fi
	# Convert and merge all json files in the directory without external find binary
	set +f
	{
		for f in "${dir_path}"/*.json; do
			if [ -f "$f" ]; then
				jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/swagger2openapi.jq" "$f"
			fi
		done
	} | jq -s 'reduce .[] as $item ({}; . * $item)' >"${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	set -f
}
