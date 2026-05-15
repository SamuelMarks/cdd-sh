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
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

handle_parse_openapi() {
  file_path="${1}"
  if [ ! -f "${file_path}" ]; then
    printf "Error: OpenAPI file not found at %s\n" "${file_path}" >&2
    return 1
  fi
  # Convert openapi to ast.json (direct copy, maybe minified/formatted)
  jq -f "${DIR}/swagger2openapi.jq" "${file_path}" > "${LIBSCRIPT_ROOT_DIR}/ast.json"
}
