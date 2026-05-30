#!/bin/sh
# shellcheck disable=SC2016,SC2129

set -eu

PRELUDE='#!/bin/sh

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
  *":"${this_file}":"*)
    printf "[STOP]     processing \"%s\"\n" "${this_file}" >&2
    if (return 0 2>/dev/null); then return; else exit 0; fi ;;
  *) printf "[CONTINUE] processing \"%s\"\n" "${this_file}" >&2 ;;
esac
export STACK="${STACK:-}${this_file}:"

DIR=$(CDPATH="" cd "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}/ROOT" ]; do d="$(dirname -- "${d}")"; done; printf "%s" "${d}")}"

for lib in "lib/env.sh" "lib/_common/pkg_mgr.sh"; do
  SCRIPT_NAME="${LIBSCRIPT_ROOT_DIR}/${lib}"
  export SCRIPT_NAME
  # shellcheck disable=SC1090
  . "${SCRIPT_NAME}"
done'

for type in classes docstrings functions mocks openapi routes tests; do
	for cmd in parse emit; do
		f="src/${type}/${cmd}.sh"
		echo "$PRELUDE" >"$f"
		echo "" >>"$f"
		if [ "$cmd" = "parse" ]; then
			echo "handle_${cmd}_${type}() {" >>"$f"
			echo '  file_path="${1}"' >>"$f"
			echo "  # Implement parse for ${type}" >>"$f"
			echo "}" >>"$f"
		else
			echo "handle_${cmd}_${type}() {" >>"$f"
			echo '  file_path="${1}"' >>"$f"
			echo "  # Implement emit for ${type}" >>"$f"
			echo "}" >>"$f"
		fi
		chmod +x "$f"
	done
done
