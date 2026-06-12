#!/bin/sh
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
cd "$(dirname "$0")/.."
rm -f ast.json
./bin/cdd-sh parse openapi tests/test_default.json
./bin/cdd-sh emit classes tests/test_default_out.sh
# shellcheck disable=SC1091
. tests/test_default_out.sh

payload='{}'
if validate_Config "$payload"; then echo "Valid Config (used default)!"; else
	echo "FAIL Valid Config"
	exit 1
fi

payload2='{"retryCount": 6}'
if validate_Config "$payload2"; then
	echo "FAIL invalid max!"
	exit 1
else echo "Max validation works!"; fi

echo "All default constraints passed!"
