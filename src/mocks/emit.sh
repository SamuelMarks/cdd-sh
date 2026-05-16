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

handle_emit_mocks() {
	file_path="${1:-mocks.json}"
	ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi
	# Simple mock generator from components.examples or operation responses
	jq '
    if .components and .components.examples then .components.examples
    elif .paths then
      [ .paths | to_entries[] | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .value.responses // {} | to_entries[] | select(.key == "200") | (if .value.content then .value.content | to_entries[0].value.example // {} else {} end) ]
    else {} end
  ' "${ast}" >"${file_path}"
}
