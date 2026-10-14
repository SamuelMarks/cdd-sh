#!/bin/sh
# @file lib/env.sh
# @description Shared POSIX shell initialization, stack tracking, and LIBSCRIPT_ROOT_DIR resolution.
set -eu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
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
export STACK="${STACK:-}${THIS_FILE:-env.sh}:"
if [ -z "${LIBSCRIPT_ROOT_DIR:-}" ]; then
	if [ -f "./ROOT" ]; then
		LIBSCRIPT_ROOT_DIR="."
	else
		DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
		LIBSCRIPT_ROOT_DIR=$(
			d="${DIR}"
			while [ ! -f "${d}/ROOT" ] && [ "${d}" != "/" ]; do d="$(dirname -- "${d}")"; done
			printf '%s' "${d}"
		)
	fi
fi
export LIBSCRIPT_ROOT_DIR
