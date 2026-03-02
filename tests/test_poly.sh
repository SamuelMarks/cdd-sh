#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
rm -f ast.json
./bin/cdd-sh parse openapi tests/test_poly.json
./bin/cdd-sh emit classes tests/test_poly_out.sh
. tests/test_poly_out.sh

payload='{"animal": {"bark": true}}'
if validate_Pet "$payload"; then echo "Valid Dog Pet!"; else echo "FAIL Valid Dog"; exit 1; fi

payload2='{"animal": {"meow": true}}'
if validate_Pet "$payload2"; then echo "Valid Cat Pet!"; else echo "FAIL Valid Cat"; exit 1; fi

payload3='{"animal": {"bark": true, "meow": true}}'
if validate_Pet "$payload3"; then echo "FAIL Both Dog and Cat!"; exit 1; else echo "Correctly failed both properties."; fi

payload4='{"animal": {"tweet": true}}'
if validate_Pet "$payload4"; then echo "FAIL Neither Dog nor Cat!"; exit 1; else echo "Correctly failed neither."; fi

echo "All polymorphism constraints passed!"
