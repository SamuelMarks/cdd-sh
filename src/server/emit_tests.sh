#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
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
export STACK="${STACK:-}${THIS_FILE}:"
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}/ROOT" ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_emit_server_tests generates individual test files for the server endpoints.
handle_emit_server_tests() {
	out_dir="${1:-tests}"
	export out_dir
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	mkdir -p "${out_dir}"

	jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/server/emit_tests.jq" "${ast}" | sh
}
