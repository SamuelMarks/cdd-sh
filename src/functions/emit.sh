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

# handle_emit_functions generates functions from the AST.
handle_emit_functions() {
	file_path="${1:-functions.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi
	# Dump standalone shell helpers (like validators) if any.
	echo "#!/bin/sh" >"${file_path}"
	echo "# Utility functions based on openapi extensions." >>"${file_path}"
}
