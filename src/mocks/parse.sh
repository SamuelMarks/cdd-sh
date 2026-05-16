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

handle_parse_mocks() {
	file_path="${1:-mocks.json}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: file not found at %s\n" "${file_path}" >&2
		return 1
	fi
	ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
	if [ ! -f "${ast}" ]; then echo "{}" >"${ast}"; fi
	# Update AST components with edited mocks
	jq --slurpfile mocks "${file_path}" 'if .components == null then .components = {} else . end | .components.examples = $mocks[0]' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
