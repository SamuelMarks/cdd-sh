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
./bin/cdd-sh parse openapi tests/test_enum_format.json
./bin/cdd-sh emit classes tests/test_enum_format_out.sh
# shellcheck disable=SC1091
. tests/test_enum_format_out.sh

payload='{"email": "test@example.com", "status": "active"}'
if validate_Contact "$payload"; then echo "Valid Contact!"; else
	echo "FAIL Valid Contact"
	exit 1
fi

payload2='{"email": "not_an_email", "status": "active"}'
if validate_Contact "$payload2"; then
	echo "FAIL invalid email!"
	exit 1
else echo "Email validation works!"; fi

payload3='{"email": "test@example.com", "status": "pending"}'
if validate_Contact "$payload3"; then
	echo "FAIL invalid enum!"
	exit 1
else echo "Enum validation works!"; fi

echo "All enum & format constraints passed!"
