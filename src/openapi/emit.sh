#!/bin/sh
set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054,SC3043,SC2129
if [ "${SCRIPT_NAME-}" ]; then
	this_file="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else
	this_file="${0}"
fi
case "${STACK+x}" in
*':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;;
esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_emit_openapi outputs the AST as an OpenAPI spec.
handle_emit_openapi() {
	file_path="${1:-openapi.json}"
	if [ ! -f "${LIBSCRIPT_ROOT_DIR}/ast.json" ]; then
		printf "Error: ast.json not found\n" >&2
		return 1
	fi
	# From AST to openapi is direct as well for now
	if [ "${CDD_EMIT_SWAGGER2:-0}" = "1" ] || echo "${file_path}" | grep -q "swagger"; then
		jq -f "${DIR}/openapi2swagger.jq" "${LIBSCRIPT_ROOT_DIR}/ast.json" >"${file_path}"
	else
		jq '.' "${LIBSCRIPT_ROOT_DIR}/ast.json" >"${file_path}"
	fi
}
