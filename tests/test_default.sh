#!/bin/sh
set -eu
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
