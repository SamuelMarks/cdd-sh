#!/bin/sh
# @file test.sh
# @description Root test entrypoint that delegates execution to tests/test.sh.
set -eu
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
else
	THIS_FILE="${0}"
fi

DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
exec sh "${DIR}/tests/test.sh" "$@"
