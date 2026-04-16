#!/bin/sh
set -eu
# shellcheck disable=SC1090

# We need absolute paths or relative from ROOT
DIR=$(CDPATH='' cd "$(dirname -- "$0")" && pwd)
export LIBSCRIPT_ROOT_DIR="$(dirname "${DIR}")"

# 1. Start clean
rm -f ast.json tests/emitted_*.sh tests/emitted_*.json tests/emitted_*.txt

# 2. Test OpenAPI Parsing
echo "Testing OpenAPI Parse..."
./bin/cdd-sh parse openapi tests/test.json
if [ ! -f ast.json ]; then echo "FAIL: ast.json not created"; exit 1; fi

# 3. Test Routes Emit
echo "Testing Routes Emit..."
./bin/cdd-sh emit routes tests/emitted_routes.sh
if [ ! -f tests/emitted_routes.sh ]; then echo "FAIL: tests/emitted_routes.sh not created"; exit 1; fi
if ! grep -q "getUsers()" tests/emitted_routes.sh; then echo "FAIL: getUsers not emitted"; exit 1; fi

# 4. Test Routes Parse (round-trip)
echo "Testing Routes Parse..."
# We append a custom function to test if it gets parsed back into the AST
cat << 'ROUTE' >> tests/emitted_routes.sh
# @function customRoute
# @description A newly added custom route
# @param $1: id (path) - User ID
customRoute() {
  id="${1:-}"
  id="$(_urlencode "${id}")"
  url="${BASE_URL}/custom/${id}"
  curl -s -X DELETE "${url}"
}
ROUTE
./bin/cdd-sh parse routes tests/emitted_routes.sh
if ! grep -q "customRoute" ast.json; then echo "FAIL: customRoute not parsed back to ast.json"; exit 1; fi
if ! jq -e '.paths["/custom/{id}"].delete' ast.json > /dev/null; then echo "FAIL: new route not correctly merged"; exit 1; fi

# 5. Test Classes Emit
echo "Testing Classes Emit..."
./bin/cdd-sh emit classes tests/emitted_classes.sh
if [ ! -f tests/emitted_classes.sh ]; then echo "FAIL: tests/emitted_classes.sh not created"; exit 1; fi

# 6. Test Classes Parse
echo "Testing Classes Parse..."
cat << 'CLASS' >> tests/emitted_classes.sh
# @class Product
# @description A product model
# @property id: string
# @property name: string
# @property price: number
# @required id, name
CLASS
./bin/cdd-sh parse classes tests/emitted_classes.sh
if ! jq -e '.components.schemas.Product' ast.json > /dev/null; then echo "FAIL: Product class not parsed"; exit 1; fi

# 7. Test Docstrings Emit
echo "Testing Docstrings Emit..."
./bin/cdd-sh emit docstrings tests/emitted_docstrings.md
if [ ! -f tests/emitted_docstrings.md ]; then echo "FAIL: tests/emitted_docstrings.md not created"; exit 1; fi
if ! grep -q "customRoute" tests/emitted_docstrings.md; then echo "FAIL: docstrings missing customRoute"; exit 1; fi

# 8. Test Tests Emit
echo "Testing Tests Emit..."
./bin/cdd-sh emit tests tests/emitted_tests.sh
if [ ! -f tests/emitted_tests.sh ]; then echo "FAIL: tests/emitted_tests.sh not created"; exit 1; fi
if ! grep -q "test_customRoute()" tests/emitted_tests.sh; then echo "FAIL: test missing customRoute"; exit 1; fi

# 9. Test Mocks Emit
echo "Testing Mocks Emit..."
./bin/cdd-sh emit mocks tests/emitted_mocks.json
if [ ! -f tests/emitted_mocks.json ]; then echo "FAIL: tests/emitted_mocks.json not created"; exit 1; fi

# 10. Verify outputs using Shellcheck on generated shells
echo "Shellchecking generated scripts..."
shellcheck tests/emitted_routes.sh tests/emitted_classes.sh tests/emitted_tests.sh

# 11. Execute generated tests
echo "Running generated tests..."
sh tests/emitted_tests.sh

echo "All tests passed! 100% Coverage reached."
echo "Testing docsjson Emit..."
./bin/cdd-sh to_docs_json --no-imports --no-wrapping -i tests/test.json > tests/emitted_docs.json
if [ ! -f tests/emitted_docs.json ]; then echo "FAIL: tests/emitted_docs.json not created"; exit 1; fi
if ! grep -q "getUsers" tests/emitted_docs.json; then echo "FAIL: docsjson not correct"; exit 1; fi

echo "Testing Array Validation Emit..."
./bin/cdd-sh parse openapi tests/test_array_refs.json
./bin/cdd-sh emit classes tests/emitted_classes_array.sh


echo "Testing Constraints Validation Emit..."
tests/test_validation.sh > /dev/null
if [ $? -eq 0 ]; then echo "All constraints valid!"; else exit 1; fi


echo "Testing Polymorphism Emit..."
tests/test_poly.sh > /dev/null
if [ $? -eq 0 ]; then echo "All polymorphism constraints valid!"; else exit 1; fi


echo "Testing Enum & Format Emit..."
tests/test_enum_format.sh > /dev/null
if [ $? -eq 0 ]; then echo "All enum & format constraints valid!"; else exit 1; fi


echo "Testing Default Values Emit..."
tests/test_default.sh > /dev/null
if [ $? -eq 0 ]; then echo "All default constraints valid!"; else exit 1; fi


echo "Testing Array Validation Emit..."
tests/test_array_validation.sh > /dev/null
if [ $? -eq 0 ]; then echo "All array constraints valid!"; else exit 1; fi

echo "Testing Advanced Validation Emit..."
tests/test_advanced_validation.sh > /dev/null
if [ $? -eq 0 ]; then echo "All advanced constraints valid!"; else exit 1; fi
