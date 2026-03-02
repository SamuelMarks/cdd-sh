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
DIR=$(CDPATH='' cd -- "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

handle_emit_docstrings() {
  file_path="${1:-docs.md}"
  ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
  if [ ! -f "${ast}" ]; then
    printf "Error: AST file not found at %s\n" "${ast}" >&2
    return 1
  fi
  
  {
    printf "# API Documentation\n\n"
    jq -r '
      if .info then
        "# \(.info.title // "API") (\(.info.version // "0.0.1"))\n\n" +
        "\(.info.description // "")\n\n"
      else empty end
    ' "${ast}"
    
    jq -r '
      if .paths then
        .paths | to_entries[] | .key as $path | .value | to_entries[] | .key as $method | .value |
        (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
        "## \($opId)\n\n" +
        "**Method**: \($method | ascii_upcase)\n" +
        "**Path**: \($path)\n\n" +
        "\(.description // .summary // "")\n\n" +
        (if .parameters then
          "### Parameters\n" +
          (.parameters | map("- `\(.name)` (\(.in)): \(.description // "")") | join("\n")) + "\n\n"
        else "" end) +
        (if .responses then
          "### Responses\n" +
          (.responses | to_entries | map("- `\(.key)`: \(.value.description // "")") | join("\n")) + "\n\n"
        else "" end)
      else empty end
    ' "${ast}"
  } > "${file_path}"
}
