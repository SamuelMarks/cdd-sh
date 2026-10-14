#!/bin/sh
# @file test.sh
# @description Root test entrypoint that delegates execution to tests/test.sh.
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

DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
exec sh "${DIR}/tests/test.sh" "$@"
