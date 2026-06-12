#!/bin/sh

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
# shellcheck disable=SC1091

. ./emitted_classes_array.sh
payload='{"books": [{"title": "1984"}, {"title": "Brave New World"}]}'
if validate_Library "$payload"; then echo "Valid library passed!"; else echo "FAIL valid library"; fi

bad_payload='{"books": [{"title": "1984"}, {}]}'
if validate_Library "$bad_payload"; then echo "FAIL - bad library should fail"; else echo "Bad library correctly failed!"; fi
