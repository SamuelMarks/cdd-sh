#!/bin/sh
set -eu

echo "Testing Request Validation & Auth Mocks..."

rm -rf temp-validation
mkdir -p temp-validation

# We'll use the petstore.json.
# It defines GET /pet/findByStatus which takes an array of strings in OpenAPI 3 or a single string in swagger. Wait, validation.
# We have a specific test_validation.json we can use!
./bin/cdd-sh from_openapi to_server -i tests/test.json -o temp-validation/server --strict-validation --enforce-auth

export CDD_ENFORCE_AUTH=1
export CDD_STRICT_VALIDATION=1
export CDD_START_AUTH_SERVER=1
PORT=8119 sh temp-validation/server/src/server.sh --strict-validation --enforce-auth --start-auth-server >server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Test Auth Failure
res=$(curl -s -X GET http://localhost:8119/users)
if ! echo "$res" | grep -q "Unauthorized" && ! echo "$res" | grep -q "error"; then
	echo "FAIL: Expected auth failure (401), got: $res"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

# Test Validation Failure
res=$(curl -s -X POST http://localhost:8119/users -H "Authorization: Bearer mock-token-123" -H "Content-Type: application/json" -d '{}')
if ! echo "$res" | grep -q "Bad Request" && ! echo "$res" | grep -q "error"; then
	echo "FAIL: Expected validation failure (400), got: $res"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

res=$(curl -s -X POST http://localhost:8119/auth/login)
if ! echo "$res" | grep -q "mock-token-123"; then
	echo "FAIL: Expected Auth Server to return mock-token-123, got: $res"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

res=$(curl -s -X POST http://localhost:8119/_mock/trigger-webhook/my_webhook)
if ! echo "$res" | grep -q "dispatched"; then
	echo "FAIL: Expected Webhook trigger to return dispatched, got: $res"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

echo "Validation & Auth tests passed!"
kill $SERVER_PID 2>/dev/null || true
rm -rf temp-validation server.log
