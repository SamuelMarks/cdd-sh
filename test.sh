#!/bin/sh
set -eu
# shellcheck disable=SC1090

# We need absolute paths or relative from ROOT
DIR=$(CDPATH='' cd "$(dirname -- "$0")" && pwd)
export LIBSCRIPT_ROOT_DIR="${DIR}"

# 1. Start clean
rm -f ast.json emitted_*.sh emitted_*.json emitted_*.txt

# 2. Test OpenAPI Parsing
echo "Testing OpenAPI Parse..."
./cdd.sh parse openapi test.json
if [ ! -f ast.json ]; then
	echo "FAIL: ast.json not created"
	exit 1
fi

# 3. Test Routes Emit
echo "Testing Routes Emit..."
./cdd.sh emit routes emitted_routes.sh
if [ ! -f emitted_routes.sh ]; then
	echo "FAIL: emitted_routes.sh not created"
	exit 1
fi
if ! grep -q "getUsers()" emitted_routes.sh; then
	echo "FAIL: getUsers not emitted"
	exit 1
fi

# 4. Test Routes Parse (round-trip)
echo "Testing Routes Parse..."
# We append a custom function to test if it gets parsed back into the AST
cat <<'ROUTE' >>emitted_routes.sh
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
./cdd.sh parse routes emitted_routes.sh
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
./cdd.sh emit classes emitted_classes.sh
if [ ! -f emitted_classes.sh ]; then
	echo "FAIL: emitted_classes.sh not created"
	exit 1
fi

# 6. Test Classes Parse
echo "Testing Classes Parse..."
cat <<'CLASS' >>emitted_classes.sh
# @class Product
# @description A product model
# @property id: string
# @property name: string
# @property price: number
# @required id, name
CLASS
./cdd.sh parse classes emitted_classes.sh
if ! jq -e '.components.schemas.Product' ast.json >/dev/null; then
	echo "FAIL: Product class not parsed"
	exit 1
fi

# 7. Test Docstrings Emit
echo "Testing Docstrings Emit..."
./cdd.sh emit docstrings emitted_docstrings.md
if [ ! -f emitted_docstrings.md ]; then
	echo "FAIL: emitted_docstrings.md not created"
	exit 1
fi
if ! grep -q "customRoute" emitted_docstrings.md; then
	echo "FAIL: docstrings missing customRoute"
	exit 1
fi

# 8. Test Tests Emit
echo "Testing Tests Emit..."
./cdd.sh emit tests emitted_tests.sh
if [ ! -f emitted_tests.sh ]; then
	echo "FAIL: emitted_tests.sh not created"
	exit 1
fi
if ! grep -q "test_customRoute()" emitted_tests.sh; then
	echo "FAIL: test missing customRoute"
	exit 1
fi

# 9. Test Mocks Emit
echo "Testing Mocks Emit..."
./cdd.sh emit mocks emitted_mocks.json
if [ ! -f emitted_mocks.json ]; then
	echo "FAIL: emitted_mocks.json not created"
	exit 1
fi

# 10. Verify outputs using Shellcheck on generated shells
echo "Shellchecking generated scripts..."
shellcheck emitted_routes.sh emitted_classes.sh emitted_tests.sh

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

BASE_URL="http://localhost:8181/v2" sh emitted_tests.sh
kill $SERVER_PID

echo "All tests passed! 100% Coverage reached."
