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

# handle_emit_openapi outputs the AST as an OpenAPI spec.
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
