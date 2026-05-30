#!/bin/sh
set -eu
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
