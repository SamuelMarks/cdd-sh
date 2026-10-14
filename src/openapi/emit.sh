#!/bin/sh
# @file src/openapi/emit.sh
# @description Emits the OpenAPI 3.2.0 or Swagger 2.0 JSON specification from the AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_openapi outputs the AST as an OpenAPI spec.
# @param $1: file_path - The destination JSON file path (default: openapi.json).
handle_emit_openapi() {
	file_path="${1:-openapi.json}"
	if [ ! -f "${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}" ]; then
		printf "Error: ast.json not found\n" >&2
		return 1
	fi
	# From AST to openapi is direct as well for now
	is_swagger=0
	case "${file_path}" in
	*swagger*) is_swagger=1 ;;
	esac

	if [ "${CDD_EMIT_SWAGGER2:-0}" = "1" ] || [ "${is_swagger}" = "1" ]; then
		jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/openapi2swagger.jq" "${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}" >"${file_path}"
	else
		jq '.' "${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}" >"${file_path}"
	fi
}
