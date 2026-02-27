#!/bin/sh
set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
  this_file="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
  this_file="${BASH_SOURCE[0]}"
  set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
  this_file="${(%):-%x}"
  set -o pipefail
else
  this_file="${0}"
fi

case "${STACK+x}" in
  *':'"${this_file}"':'*)
    printf '[STOP]     processing "%s"\n' "${this_file}" >&2
    if (return 0 2>/dev/null); then return; else exit 0; fi ;;
  *) printf '[CONTINUE] processing "%s"\n' "${this_file}" >&2 ;;
esac
export STACK="${STACK:-}${this_file}"':'

DIR=$(CDPATH='' cd -- "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

for lib in 'lib/env.sh' 'lib/_common/pkg_mgr.sh'; do
  SCRIPT_NAME="${LIBSCRIPT_ROOT_DIR}"'/'"${lib}"
  export SCRIPT_NAME
  # shellcheck disable=SC1090
  . "${SCRIPT_NAME}"
done

usage() {
  printf "Usage: %s <command> [args]\n\n" "${0}"
  printf "Commands:\n"
  printf "  from_openapi -i <spec.json>        Parse an OpenAPI spec into ast.json\n"
  printf "  to_openapi -f <code_file>          Emit an OpenAPI spec from ast.json (not currently supported using -f alone. use 'emit openapi <file>' to just generate or 'parse <type> <code_file>' to parse code to AST then 'emit openapi')\n"
  printf "  to_docs_json [-i <spec.json>]      Output JSON docs structure\n"
  printf "  -help                              Show this help\n"
  printf "  -version                           Show version\n"
  printf "  parse <type> <file>                Parse a file into ast.json (types: openapi, routes, classes, etc.)\n"
  printf "  emit <type> <file>                 Emit a file from ast.json\n"
  exit 1
}

if [ "$#" -eq 0 ]; then
  usage
fi

CMD="${1}"
shift

case "${CMD}" in
  -help|--help)
    usage
    ;;
  -version|--version)
    echo "cdd-sh 1.0.0"
    exit 0
    ;;
  from_openapi)
    if [ "$#" -lt 2 ] || [ "$1" != "-i" ]; then
      echo "Error: from_openapi requires -i <spec.json>" >&2
      exit 1
    fi
    # shellcheck disable=SC1090,SC1091
    . "${LIBSCRIPT_ROOT_DIR}/src/openapi/parse.sh"
    handle_parse_openapi "$2"
    ;;
  to_openapi)
    # The requirement is `cdd-LANGUAGE to_openapi -f path/to/code`
    # Let's assume path/to/code is routes.sh for this simplified wrapper,
    # as `cdd-sh` is actually multi-module. We will parse it then emit.
    if [ "$#" -lt 2 ] || [ "$1" != "-f" ]; then
      echo "Error: to_openapi requires -f <path/to/code>" >&2
      exit 1
    fi
    # shellcheck disable=SC1090,SC1091
    . "${LIBSCRIPT_ROOT_DIR}/src/routes/parse.sh"
    handle_parse_routes "$2"
    # shellcheck disable=SC1090,SC1091
    . "${LIBSCRIPT_ROOT_DIR}/src/openapi/emit.sh"
    # Emit to stdout or openapi.json. Let's do stdout.
    handle_emit_openapi "/dev/stdout"
    ;;
  to_docs_json)
    # shellcheck disable=SC1090,SC1091
    . "${LIBSCRIPT_ROOT_DIR}/src/docsjson/emit.sh"
    handle_to_docs_json "$@"
    ;;
  parse|emit)
    TYPE="${1:-}"
    FILE="${2:-}"
    
    HANDLER="${LIBSCRIPT_ROOT_DIR}/src/${TYPE}/${CMD}.sh"
    if [ ! -f "${HANDLER}" ]; then
      printf "Error: Unsupported type '%s' or handler missing (%s)\n" "${TYPE}" "${HANDLER}" >&2
      exit 1
    fi
    
    SCRIPT_NAME="${HANDLER}"
    export SCRIPT_NAME
    # shellcheck disable=SC1090
    . "${HANDLER}"
    
    "handle_${CMD}_${TYPE}" "${FILE}"
    ;;
  *)
    printf "Error: Unknown command '%s'\n" "${CMD}" >&2
    usage
    ;;
esac
