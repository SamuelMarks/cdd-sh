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
./bin/cdd-sh parse openapi tests/test_array_refs.json
./bin/cdd-sh emit classes tests/emitted_classes_array.sh

# shellcheck disable=SC1091
. tests/emitted_classes_array.sh
payload='{"books": [{"title": "1984"}, {"title": "Brave New World"}]}'
if validate_Library "$payload"; then echo "Valid library passed!"; else echo "FAIL valid library"; fi

bad_payload='{"books": [{"title": "1984"}, {}]}'
if validate_Library "$bad_payload"; then echo "FAIL - bad library should fail"; else echo "Bad library correctly failed!"; fi
