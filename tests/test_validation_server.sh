#!/bin/sh
# @file tests/test_validation_server.sh
# @description Tests strict request validation, authentication enforcement, and webhook triggers on the generated server.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")" && pwd)/test_helpers.sh"

echo "Testing Request Validation & Auth Mocks..."

VAL_PORT=$(allocate_free_port 18119)
SERVER_PID=""

# cleanup_val_srv terminates the validation server and removes temporary directories.
# @param none
# @return Returns 0.
cleanup_val_srv() {
	cleanup_server_pid "${SERVER_PID:-}" "${VAL_PORT:-}"
	rm -rf temp-validation server.log
}
trap cleanup_val_srv EXIT INT TERM

rm -rf temp-validation
mkdir -p temp-validation

./bin/cdd-sh from_openapi to_server -i tests/test.json -o temp-validation/server --strict-validation --enforce-auth

export CDD_ENFORCE_AUTH=1
export CDD_STRICT_VALIDATION=1
export CDD_START_AUTH_SERVER=1
PORT="${VAL_PORT}" sh temp-validation/server/src/server.sh --strict-validation --enforce-auth --start-auth-server >server.log 2>&1 &
SERVER_PID=$!
wait_for_port "${VAL_PORT}" 50

# Test Auth Failure
res=$(curl -s -X GET "http://127.0.0.1:${VAL_PORT}/users")
if ! echo "$res" | grep -q "Unauthorized" && ! echo "$res" | grep -q "error"; then
	echo "FAIL: Expected auth failure (401), got: $res"
	exit 1
fi

# Test Validation Failure
res=$(curl -s -X POST "http://127.0.0.1:${VAL_PORT}/users" -H "Authorization: Bearer mock-token-123" -H "Content-Type: application/json" -d '{}')
if ! echo "$res" | grep -q "Bad Request" && ! echo "$res" | grep -q "error"; then
	echo "FAIL: Expected validation failure (400), got: $res"
	exit 1
fi

res=$(curl -s -X POST "http://127.0.0.1:${VAL_PORT}/auth/login")
if ! echo "$res" | grep -q "mock-token-123"; then
	echo "FAIL: Expected Auth Server to return mock-token-123, got: $res"
	exit 1
fi

res=$(curl -s -X POST "http://127.0.0.1:${VAL_PORT}/_mock/trigger-webhook/my_webhook")
if ! echo "$res" | grep -q "dispatched"; then
	echo "FAIL: Expected Webhook trigger to return dispatched, got: $res"
	exit 1
fi

# Test multi-model fallback validation: add User and StrictOther models and verify valid User payload passes while invalid payload fails
mkdir -p temp-validation/server/src/models
cat <<'MODEL_A' >temp-validation/server/src/models/model_User.sh
#!/bin/sh
validate_User() {
  printf '%s' "$1" | jq -e 'has("id") and has("name")' >/dev/null 2>&1
}
MODEL_A
cat <<'MODEL_B' >temp-validation/server/src/models/model_StrictOther.sh
#!/bin/sh
validate_StrictOther() {
  printf '%s' "$1" | jq -e 'has("unrelatedRequiredField")' >/dev/null 2>&1
}
MODEL_B
chmod +x temp-validation/server/src/models/model_User.sh temp-validation/server/src/models/model_StrictOther.sh

res_valid=$(curl -s -X POST "http://127.0.0.1:${VAL_PORT}/users" -H "Authorization: Bearer mock-token-123" -H "Content-Type: application/json" -d '{"id":"u1","name":"Alice"}')
if echo "$res_valid" | grep -q "400 Bad Request"; then
	echo "FAIL: Expected valid User payload to pass strict validation even when unrelated model exists, got: $res_valid"
	exit 1
fi

res_invalid=$(curl -s -X POST "http://127.0.0.1:${VAL_PORT}/users" -H "Authorization: Bearer mock-token-123" -H "Content-Type: application/json" -d '{"neither":"valid"}')
if ! echo "$res_invalid" | grep -q "400 Bad Request"; then
	echo "FAIL: Expected invalid payload matching neither model to fail strict validation, got: $res_invalid"
	exit 1
fi

echo "Validation & Auth tests passed!"
