#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054,SC3043,SC2129
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	THIS_FILE="${BASH_SOURCE[0]}"
	set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
	eval 'THIS_FILE="${(%):-%x}"'
	set -o pipefail
else
	THIS_FILE="${0}"
fi
case "${STACK+x}" in
*':'"${THIS_FILE}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;;
esac
export STACK="${STACK:-}${THIS_FILE}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_parse_openapi parses an OpenAPI spec into the AST.
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
handle_parse_openapi_dir() {
	dir_path="${1}"
	if [ ! -d "${dir_path}" ]; then
		printf "Error: OpenAPI directory not found at %s\n" "${dir_path}" >&2
		return 1
	fi
	# Convert and merge all json files in the directory
	find "${dir_path}" -maxdepth 1 -name "*.json" -exec jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/swagger2openapi.jq" {} + | jq -s 'reduce .[] as $item ({}; . * $item)' >"${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
}
