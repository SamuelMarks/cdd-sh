#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
rm -f ast.json
./bin/cdd-sh parse openapi tests/test_validation.json
./bin/cdd-sh emit classes tests/test_validation_out.sh
cat tests/test_validation_out.sh
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
