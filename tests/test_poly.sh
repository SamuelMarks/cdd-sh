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
./bin/cdd-sh parse openapi tests/test_poly.json
./bin/cdd-sh emit classes tests/test_poly_out.sh
# shellcheck disable=SC1091
. tests/test_poly_out.sh

payload='{"animal": {"bark": true}}'
if validate_Pet "$payload"; then echo "Valid Dog Pet!"; else
	echo "FAIL Valid Dog"
	exit 1
fi

payload2='{"animal": {"meow": true}}'
if validate_Pet "$payload2"; then echo "Valid Cat Pet!"; else
	echo "FAIL Valid Cat"
	exit 1
fi

payload3='{"animal": {"bark": true, "meow": true}}'
if validate_Pet "$payload3"; then
	echo "FAIL Both Dog and Cat!"
	exit 1
else echo "Correctly failed both properties."; fi

payload4='{"animal": {"tweet": true}}'
if validate_Pet "$payload4"; then
	echo "FAIL Neither Dog nor Cat!"
	exit 1
else echo "Correctly failed neither."; fi

echo "All polymorphism constraints passed!"
