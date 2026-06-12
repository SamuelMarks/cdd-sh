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
./bin/cdd-sh parse openapi tests/test_validation.json
./bin/cdd-sh emit classes tests/test_validation_out.sh
cat tests/test_validation_out.sh
# shellcheck disable=SC1091
. tests/test_validation_out.sh

payload='{"age": 20, "username": "bob123", "tags": ["a", "b"]}'
if validate_User "$payload"; then echo "Valid!"; else
	echo "FAIL Valid"
	exit 1
fi

payload2='{"age": 17, "username": "bob123", "tags": ["a", "b"]}'
if validate_User "$payload2"; then
	echo "FAIL Invalid age"
	exit 1
else echo "Age validation works!"; fi

payload3='{"age": 20, "username": "b", "tags": ["a", "b"]}'
if validate_User "$payload3"; then
	echo "FAIL Invalid username len"
	exit 1
else echo "Username minLength works!"; fi

payload4='{"age": 20, "username": "B O B", "tags": ["a", "b"]}'
if validate_User "$payload4"; then
	echo "FAIL Invalid username pattern"
	exit 1
else echo "Username pattern works!"; fi

payload5='{"age": 20, "username": "bob123", "tags": ["a", "a"]}'
if validate_User "$payload5"; then
	echo "FAIL Invalid unique tags"
	exit 1
else echo "Tags uniqueItems works!"; fi

echo "All constraint validations passed!"
