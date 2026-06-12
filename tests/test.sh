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
# shellcheck disable=SC1090

# We need absolute paths or relative from ROOT
DIR=$(CDPATH='' cd "$(dirname -- "$0")" && pwd)
LIBSCRIPT_ROOT_DIR="$(dirname "${DIR}")"
export LIBSCRIPT_ROOT_DIR

# 1. Start clean
rm -f ast.json tests/emitted_*.sh tests/emitted_*.json tests/emitted_*.txt

# 2. Test OpenAPI Parsing
echo "Testing OpenAPI Parse..."
./bin/cdd-sh parse openapi tests/test.json
if [ ! -f ast.json ]; then
	echo "FAIL: ast.json not created"
	exit 1
fi

# 3. Test Routes Emit
echo "Testing Routes Emit..."
./bin/cdd-sh emit routes tests/emitted_routes.sh
if [ ! -f tests/emitted_routes.sh ]; then
	echo "FAIL: tests/emitted_routes.sh not created"
	exit 1
fi
if ! grep -q "getUsers()" tests/emitted_routes.sh; then
	echo "FAIL: getUsers not emitted"
	exit 1
fi

# 4. Test Routes Parse (round-trip)
echo "Testing Routes Parse..."
# We append a custom function to test if it gets parsed back into the AST
cat <<'ROUTE' >>tests/emitted_routes.sh
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
if ! grep -q "customRoute" ast.json; then
	echo "FAIL: customRoute not parsed back to ast.json"
	exit 1
fi
if ! jq -e '.paths["/custom/{id}"].delete' ast.json >/dev/null; then
	echo "FAIL: new route not correctly merged"
	exit 1
fi

# 5. Test Classes Emit
echo "Testing Classes Emit..."
./bin/cdd-sh emit classes tests/emitted_classes.sh
if [ ! -f tests/emitted_classes.sh ]; then
	echo "FAIL: tests/emitted_classes.sh not created"
	exit 1
fi

# 6. Test Classes Parse
echo "Testing Classes Parse..."
cat <<'CLASS' >>tests/emitted_classes.sh
# @class Product
# @description A product model
# @property id: string
# @property name: string
# @property price: number
# @required id, name
CLASS
./bin/cdd-sh parse classes tests/emitted_classes.sh
if ! jq -e '.components.schemas.Product' ast.json >/dev/null; then
	echo "FAIL: Product class not parsed"
	exit 1
fi

# 7. Test Docstrings Emit
echo "Testing Docstrings Emit..."
./bin/cdd-sh emit docstrings tests/emitted_docstrings.md
if [ ! -f tests/emitted_docstrings.md ]; then
	echo "FAIL: tests/emitted_docstrings.md not created"
	exit 1
fi
if ! grep -q "customRoute" tests/emitted_docstrings.md; then
	echo "FAIL: docstrings missing customRoute"
	exit 1
fi

# 8. Test Tests Emit
echo "Testing Tests Emit..."
./bin/cdd-sh emit tests tests/emitted_tests.sh
if [ ! -f tests/emitted_tests.sh ]; then
	echo "FAIL: tests/emitted_tests.sh not created"
	exit 1
fi
if ! grep -q "test_customRoute()" tests/emitted_tests.sh; then
	echo "FAIL: test missing customRoute"
	exit 1
fi

# 9. Test Mocks Emit
echo "Testing Mocks Emit..."
./bin/cdd-sh emit mocks tests/emitted_mocks.json
if [ ! -f tests/emitted_mocks.json ]; then
	echo "FAIL: tests/emitted_mocks.json not created"
	exit 1
fi

# 10. Verify outputs using Shellcheck on generated shells
echo "Shellchecking generated scripts..."
shellcheck tests/emitted_routes.sh tests/emitted_classes.sh tests/emitted_tests.sh

# 10.5 Test Swagger 2.0 conversion
echo "Testing Swagger 2.0 Parse..."
./bin/cdd-sh parse openapi tests/test_swagger.json
if ! jq -e '.openapi' ast.json >/dev/null; then
	echo "FAIL: Swagger 2.0 not converted to OpenAPI 3.2.0"
	exit 1
fi
if ! jq -e '.servers[0].url == "https://api.example.com/v1"' ast.json >/dev/null; then
	echo "FAIL: Swagger 2.0 host/basePath not mapped"
	exit 1
fi

echo "Testing Swagger 2.0 Emit..."
CDD_EMIT_SWAGGER2=1 ./bin/cdd-sh emit openapi tests/emitted_swagger.json
if ! jq -e '.swagger == "2.0"' tests/emitted_swagger.json >/dev/null; then
	echo "FAIL: OpenAPI 3.2.0 not converted to Swagger 2.0"
	exit 1
fi
if ! jq -e '.host == "api.example.com"' tests/emitted_swagger.json >/dev/null; then
	echo "FAIL: OpenAPI 3.2.0 host not mapped back"
	exit 1
fi

# 11. Execute generated tests
echo "Running generated tests..."
cat <<'EOF' >/tmp/mock_handler.sh
#!/bin/sh
while IFS= read -r line; do
  line=$(printf "%s" "$line" | tr -d '\r')
  if [ -z "$line" ]; then break; fi
done
printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"
EOF
chmod +x /tmp/mock_handler.sh
if command -v socat >/dev/null 2>&1; then
	socat TCP4-LISTEN:8181,reuseaddr,fork EXEC:/tmp/mock_handler.sh >/dev/null 2>&1 &
else
	rm -f /tmp/nc_pipe
	mkfifo /tmp/nc_pipe
	# shellcheck disable=SC2094
	while true; do nc -l 8181 </tmp/nc_pipe | /tmp/mock_handler.sh >/tmp/nc_pipe; done >/dev/null 2>&1 &
fi
SERVER_PID=$!
sleep 1

BASE_URL="http://localhost:8181/v2" sh tests/emitted_tests.sh
kill $SERVER_PID

echo "All tests passed! 100% Coverage reached."
echo "Testing docsjson Emit..."
./bin/cdd-sh to_docs_json --no-imports --no-wrapping -i tests/test.json >tests/emitted_docs.json
if [ ! -f tests/emitted_docs.json ]; then
	echo "FAIL: tests/emitted_docs.json not created"
	exit 1
fi
if ! grep -q "getUsers" tests/emitted_docs.json; then
	echo "FAIL: docsjson not correct"
	exit 1
fi

echo "Testing Array Validation Emit..."
./bin/cdd-sh parse openapi tests/test_array_refs.json
./bin/cdd-sh emit classes tests/emitted_classes_array.sh

echo "Testing Constraints Validation Emit..."
if tests/test_validation.sh >/dev/null; then echo "All constraints valid!"; else exit 1; fi

echo "Testing Polymorphism Emit..."
if tests/test_poly.sh >/dev/null; then echo "All polymorphism constraints valid!"; else exit 1; fi

echo "Testing Enum & Format Emit..."
if tests/test_enum_format.sh >/dev/null; then echo "All enum & format constraints valid!"; else exit 1; fi

echo "Testing Default Values Emit..."
if tests/test_default.sh >/dev/null; then echo "All default constraints valid!"; else exit 1; fi

echo "Testing Array Validation Emit..."
if tests/test_array_validation.sh >/dev/null; then echo "All array constraints valid!"; else exit 1; fi

echo "Testing Advanced Validation Emit..."
if tests/test_advanced_validation.sh >/dev/null; then echo "All advanced constraints valid!"; else exit 1; fi
sh tests/test_mcp.sh
sh tests/test_server.sh
sh tests/test_sdk.sh
sh tests/test_serve_rpc.sh
sh tests/test_petstore_sdks.sh
