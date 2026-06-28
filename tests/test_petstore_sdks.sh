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

export BASE_URL="http://localhost:8100/api"
MOCK_PID=""
CONTAINER_ID=""

if curl -s -f http://localhost:8100/api/swagger.json >/dev/null 2>&1; then
	echo "Found active mock server at $BASE_URL, reusing..."
else
	echo "Starting local Petstore server..."
	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
		echo "Using Docker for mock server..."
		CONTAINER_ID=$(docker run -d -e SWAGGER_URL=http://localhost:8100/api/swagger.json -p 8100:8080 swaggerapi/petstore)
		# shellcheck disable=SC2064
		trap 'docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true' EXIT
	elif command -v python3 >/dev/null 2>&1; then
		echo "Using Python for mock server..."
		cat <<'PY_EOF' >/tmp/mock_server.py
import http.server, json
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        if 'findByStatus' in self.path:
            self.wfile.write(b'[{"id": 1, "name": "doggie"}]')
        else:
            self.wfile.write(b'{}')
http.server.HTTPServer(('localhost', 8100), Handler).serve_forever()
PY_EOF
		python3 /tmp/mock_server.py >/dev/null 2>&1 &
		MOCK_PID=$!
		trap 'kill "$MOCK_PID" >/dev/null 2>&1 || true; rm -f /tmp/mock_server.py' EXIT
	elif command -v java >/dev/null 2>&1 && command -v javac >/dev/null 2>&1; then
		echo "Using JVM for mock server..."
		cat <<'JAVA_EOF' >/tmp/MockServer.java
import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class MockServer {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8100), 0);
        server.createContext("/", new HttpHandler() {
            public void handle(HttpExchange t) throws java.io.IOException {
                String response = t.getRequestURI().toString().contains("findByStatus") ? "[{\"id\": 1, \"name\": \"doggie\"}]" : "{}";
                t.getResponseHeaders().set("Content-Type", "application/json");
                t.sendResponseHeaders(200, response.length());
                OutputStream os = t.getResponseBody();
                os.write(response.getBytes());
                os.close();
            }
        });
        server.start();
    }
}
JAVA_EOF
		javac /tmp/MockServer.java
		java -cp /tmp MockServer >/dev/null 2>&1 &
		MOCK_PID=$!
		trap 'kill "$MOCK_PID" >/dev/null 2>&1 || true; rm -f /tmp/MockServer.java /tmp/MockServer.class /tmp/MockServer$1.class' EXIT
	else
		echo "No Python, JVM, or Docker found. Testing against remote petstore.swagger.io..."
		export BASE_URL="https://petstore.swagger.io/v2"
	fi

	if [ -n "$MOCK_PID" ] || [ -n "${CONTAINER_ID:-}" ]; then
		echo "Waiting for local Petstore server to be ready..."
		timeout=60
		started=0
		while [ $timeout -gt 0 ]; do
			if curl -s -f http://localhost:8100/api/swagger.json >/dev/null 2>&1; then
				started=1
				break
			fi
			sleep 1
			timeout=$((timeout - 1))
		done
		if [ "$started" != "1" ]; then
			echo "Local Petstore server failed to start, testing against remote petstore.swagger.io..."
			export BASE_URL="https://petstore.swagger.io/v2"
		fi
	fi
fi

echo "Testing Swagger SDK against $BASE_URL..."
rm -rf temp-swagger-sdk temp-openapi-sdk
./bin/cdd-sh from_openapi to_sdk -i ../petstore.json -o temp-swagger-sdk
# shellcheck disable=SC1091
. temp-swagger-sdk/src/routes.sh

res=$(findPetsByStatus "available")
if ! printf "%s" "$res" | grep -q "\[" && ! printf "%s" "$res" | grep -q "Not found"; then
	echo "FAIL: Swagger SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "Swagger SDK test passed!"

echo "Testing OpenAPI SDK against $BASE_URL..."
./bin/cdd-sh from_openapi to_sdk -i ../petstore_oas3.json -o temp-openapi-sdk
# shellcheck disable=SC1091
. temp-openapi-sdk/src/routes.sh

res=$(findPetsByStatus "available")
if ! printf "%s" "$res" | grep -q "\[" && ! printf "%s" "$res" | grep -q "Not found"; then
	echo "FAIL: OpenAPI SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "OpenAPI SDK test passed!"

rm -rf temp-swagger-sdk temp-openapi-sdk
