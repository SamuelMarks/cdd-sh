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

# handle_emit_classes generates data classes and models from the AST.
handle_emit_classes() {
	file_path="${1:-classes.sh}"
	ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n# Auto-generated Data Classes\nset -eu\n\n"
		printf "_get_prop() {\n  printf '%%s' \"\$1\" | jq -c \".\\\\\"\$2\\\\\" // empty\"\n}\n\n"
		jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/classes/emit.jq" "${ast}"
	} >"${file_path}.tmp"

	if [ -f "${file_path}" ]; then
		awk -v new_file="${file_path}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" "${file_path}" >"${file_path}.merged"
		mv "${file_path}.merged" "${file_path}"
		rm -f "${file_path}.tmp"
	else
		mv "${file_path}.tmp" "${file_path}"
	fi
}
