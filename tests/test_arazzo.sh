#!/bin/sh
# @file tests/test_arazzo.sh
# @description Comprehensive integration test suite for Arazzo 1.1.0 bidirectional generation, runtime evaluation, CLI, Server, and MCP.
# shellcheck disable=SC1091,SC2016,SC2317,SC2329,SC2030,SC2031
set -e
ROOT_DIR="$(cd "$(dirname -- "$0")/.." && pwd)"
. "${ROOT_DIR}/lib/env.sh"
. "${ROOT_DIR}/lib/arazzo_runtime.sh"

TMP_ARAZZO_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cdd_test_arazzo.XXXXXX")
# shellcheck disable=SC2064
trap "rm -rf \"${TMP_ARAZZO_DIR}\"" EXIT INT TERM

echo "1. Testing Arazzo 1.1.0 Runtime Expression, Selector, Criterion & Payload Replacement Engine..."
arazzo_init_state '{"username":"bob","quantity":3}' '[{"name":"petstore","url":"https://api.example.com","type":"openapi"}]' '{"parameters":{"traceHeader":{"name":"X-Trace-Id","in":"header","value":"t-99"}}}' 'https://example.com/self.arazzo.json'
WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c '
	.current.url = "https://api.example.com/items" |
	.current.method = "POST" |
	.current.statusCode = 201 |
	.current.request.header = {"X-Custom": "req-hdr"} |
	.current.request.query = {"page": "2"} |
	.current.request.path = {"itemId": "42"} |
	.current.request.body = {"item": {"name": "bone"}} |
	.current.response.header = {"Content-Type": "application/json", "X-Rate-Limit": "100"} |
	.current.response.body = {"id": "ord-77", "status": "available", "items": [{"sku": "SKU-1"}]} |
	.current.message.header = {"X-Msg-Id": "m-1"} |
	.current.message.payload = {"event": "created"} |
	.outputs = {"summaryId": "ord-77"} |
	.steps.prevStep.outputs = {"token": "tok-xyz"} |
	.workflows.authFlow.outputs = {"jwt": "jwt-abc"}
')
export WORKFLOW_STATE_JSON

[ "$(arazzo_eval_expr '$url')" = "https://api.example.com/items" ]
[ "$(arazzo_eval_expr '$method')" = "POST" ]
[ "$(arazzo_eval_expr '$statusCode')" = "201" ]
[ "$(arazzo_eval_expr '$request.header.x-custom')" = "req-hdr" ]
[ "$(arazzo_eval_expr '$request.query.page')" = "2" ]
[ "$(arazzo_eval_expr '$request.path.itemId')" = "42" ]
[ "$(arazzo_eval_expr '$request.body#/item/name')" = "bone" ]
[ "$(arazzo_eval_expr '$response.header.x-rate-limit')" = "100" ]
[ "$(arazzo_eval_expr '$response.body.id')" = "ord-77" ]
[ "$(arazzo_eval_expr '$message.header.X-Msg-Id')" = "m-1" ]
[ "$(arazzo_eval_expr '$message.payload.event')" = "created" ]
[ "$(arazzo_eval_expr '$inputs.username')" = "bob" ]
[ "$(arazzo_eval_expr '$outputs.summaryId')" = "ord-77" ]
[ "$(arazzo_eval_expr '$steps.prevStep.outputs.token')" = "tok-xyz" ]
[ "$(arazzo_eval_expr '$workflows.authFlow.outputs.jwt')" = "jwt-abc" ]
[ "$(arazzo_eval_expr '$sourceDescriptions.petstore.url')" = "https://api.example.com" ]
[ "$(arazzo_eval_expr '$components.parameters.traceHeader.value')" = "t-99" ]
[ "$(arazzo_eval_expr '$self')" = "https://example.com/self.arazzo.json" ]
[ "$(arazzo_eval_expr 'Bearer {$steps.prevStep.outputs.token} for {$inputs.username}')" = "Bearer tok-xyz for bob" ]

# Test Selector Object (jsonpointer, jsonpath, xpath)
[ "$(arazzo_select_value '{"context":"$response.body","selector":"/items/0/sku","type":{"type":"jsonpointer","version":"rfc6901"}}')" = "SKU-1" ]
[ "$(arazzo_select_value '{"context":"$response.body","selector":"$.items[0].sku","type":{"type":"jsonpath","version":"rfc9535"}}')" = "SKU-1" ]
[ "$(arazzo_select_value '{"context":"$response.body","selector":"$..sku","type":"jsonpath"}')" = "SKU-1" ]
[ "$(arazzo_xpath_extract '<order id="99"><item><sku>XML-SKU-9</sku></item></order>' '/order/item/sku/text()')" = "XML-SKU-9" ]
[ "$(arazzo_xpath_extract '<order id="99"><item><sku>XML-SKU-9</sku></item></order>' '/order/@id')" = "99" ]

# Test Criterion Object (simple, regex, jsonpath, xpath)
arazzo_eval_criterion '{"condition":"$statusCode == 201 && $inputs.quantity >= 2","type":"simple"}'
arazzo_eval_criterion '{"context":"$statusCode","condition":"^20[01]$","type":"regex"}'
arazzo_eval_criterion '{"context":"$response.body","condition":"$[?(@.status == '\''available'\'')]","type":"jsonpath"}'
arazzo_eval_criterion '{"context":"<order><status>available</status></order>","condition":"/order/status/text()","type":{"type":"xpath","version":"xpath-30"}}'

# Test Payload Replacement Object targetSelectorType (jsonpointer, jsonpath recursive & direct, xpath element & attribute)
rb_json_out=$(arazzo_build_request_body '{
  "contentType": "application/json",
  "payload": {
    "meta": {"dotted.key": "old", "qty": 0, "tag": "t0"},
    "nested": {"tag": "t0"}
  },
  "replacements": [
    {"target": "/meta/dotted.key", "targetSelectorType": {"type": "jsonpointer", "version": "rfc6901"}, "value": "$inputs.username"},
    {"target": "$.meta.qty", "targetSelectorType": {"type": "jsonpath", "version": "rfc9535"}, "value": "$inputs.quantity"},
    {"target": "$..tag", "targetSelectorType": "jsonpath", "value": "updated-tag"}
  ]
}')
[ "$(printf '%s' "${rb_json_out}" | jq -r '.meta["dotted.key"]')" = "bob" ]
[ "$(printf '%s' "${rb_json_out}" | jq -r '.meta.qty')" = "3" ]
[ "$(printf '%s' "${rb_json_out}" | jq -r '.meta.tag')" = "updated-tag" ]
[ "$(printf '%s' "${rb_json_out}" | jq -r '.nested.tag')" = "updated-tag" ]

rb_xml_out=$(arazzo_build_request_body '{
  "contentType": "application/xml",
  "payload": "<order id=\"0\"><buyer>placeholder</buyer></order>",
  "replacements": [
    {"target": "/order/@id", "targetSelectorType": {"type": "xpath", "version": "xpath-30"}, "value": "99"},
    {"target": "/order/buyer/text()", "targetSelectorType": "xpath", "value": "$inputs.username"}
  ]
}')
[ "${rb_xml_out}" = '<order id="99"><buyer>bob</buyer></order>' ]

echo "2. Testing cdd-sh parse arazzo & emit arazzo lossless round-tripping..."
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast.json"
sh "${ROOT_DIR}/cdd.sh" parse arazzo "${ROOT_DIR}/tests/test_arazzo.json"
sh "${ROOT_DIR}/cdd.sh" emit arazzo "${TMP_ARAZZO_DIR}/emitted_arazzo.json"

[ "$(jq -r '.arazzo' "${TMP_ARAZZO_DIR}/emitted_arazzo.json")" = "1.1.0" ]
[ "$(jq -r '."$self"' "${TMP_ARAZZO_DIR}/emitted_arazzo.json")" = "https://example.com/workflows/petstore.arazzo.json" ]
[ "$(jq -r '.info.title' "${TMP_ARAZZO_DIR}/emitted_arazzo.json")" = "Petstore Arazzo Workflow Suite" ]
[ "$(jq -r '.workflows | length' "${TMP_ARAZZO_DIR}/emitted_arazzo.json")" = "2" ]
[ "$(jq -r '.components.parameters.traceHeader.name' "${TMP_ARAZZO_DIR}/emitted_arazzo.json")" = "X-Trace-Id" ]

echo "3. Testing cdd-sh from_arazzo to_sdk --tests and workflow execution..."
SDK_OUT="${TMP_ARAZZO_DIR}/sdk_out"
sh "${ROOT_DIR}/cdd.sh" from_arazzo to_sdk -i "${ROOT_DIR}/tests/test_arazzo.json" -o "${SDK_OUT}" --tests
[ -f "${SDK_OUT}/src/workflows.sh" ]
[ -f "${SDK_OUT}/src/routes.sh" ]
[ -f "${SDK_OUT}/src/classes.sh" ]
[ -f "${SDK_OUT}/tests/test_workflows.sh" ]

# Define mock SDK route operations so workflows execute against deterministic responses
(
	. "${SDK_OUT}/src/workflows.sh"
	# getUsers returns a mock user list payload with an auth token.
	getUsers() {
		printf '{"id":"item-101","token":"secret-jwt-token","status":"available"}\n'
	}
	# createUser returns a mock created order payload.
	createUser() {
		printf '{"id":"order-555","status":"available"}\n'
	}
	unset WORKFLOW_STATE_JSON
	wf_res=$(workflow_order_checkout_flow '{"username":"alice","itemName":"GoldenRetriever","quantity":2}')
	[ "$(printf '%s' "${wf_res}" | jq -r '.orderId')" = "order-555" ]
	[ "$(printf '%s' "${wf_res}" | jq -r '.buyer')" = "alice" ]
	[ "$(printf '%s' "${wf_res}" | jq -r '.channel')" = "_async_send_orders_created" ]
	[ "$(printf '%s' "${wf_res}" | jq -r '.selfDoc')" = "https://example.com/workflows/petstore.arazzo.json" ]

	# Test retry recovery on transient 503 failure
	unset WORKFLOW_STATE_JSON
	# getUsers simulates a transient 503 failure before succeeding on retry.
	getUsers() {
		if [ "${ARAZZO_MOCK_STATUS:-200}" = "503" ]; then
			return 1
		fi
		printf '{"id":"item-retry-ok","token":"retry-tok","status":"available"}\n'
	}
	export ARAZZO_MOCK_STATUS=503
	export ARAZZO_RETRY_RECOVERY_STATUS=200
	retry_res=$(workflow_auth_setup_flow '{"username":"alice"}')
	[ "$(printf '%s' "${retry_res}" | jq -r '.authToken')" = "retry-tok" ]
)

echo "4. Testing cdd-sh to_arazzo reverse extraction from SDK workflows.sh..."
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_rev_sdk.json"
sh "${ROOT_DIR}/cdd.sh" to_arazzo -i "${SDK_OUT}/src/workflows.sh" -o "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json"
[ "$(jq -r '.arazzo' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "1.1.0" ]
[ "$(jq -r '.workflows | length' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "2" ]
[ "$(jq -r '.workflows[0].workflowId' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "authSetupFlow" ]
[ "$(jq -r '.workflows[1].workflowId' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "orderCheckoutFlow" ]
[ "$(jq -r '.workflows[1].dependsOn[0]' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "authSetupFlow" ]
[ "$(jq -r '.workflows[1].steps[0].requestBody.replacements | length' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "2" ]
[ "$(jq -r '.workflows[1].steps[0].requestBody.replacements[0].targetSelectorType.type' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "jsonpointer" ]
[ "$(jq -r '.workflows[1].steps[0].requestBody.replacements[1].targetSelectorType.type' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "jsonpath" ]
[ "$(jq -r '.workflows[1].steps[1].channelPath' "${TMP_ARAZZO_DIR}/from_sdk_arazzo.json")" = "/orders/created" ]

echo "5. Testing heuristic AST extraction from unannotated shell workflow functions..."
cat <<'INNER_EOF' >"${TMP_ARAZZO_DIR}/unannotated.sh"
#!/bin/sh
custom_checkout_pipeline() {
  step1=$(login_user "alice")
  step2=$(create_order "$step1")
  printf "%s\n" "$step2"
}
INNER_EOF
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_heur.json"
sh "${ROOT_DIR}/cdd.sh" to_arazzo -i "${TMP_ARAZZO_DIR}/unannotated.sh" -o "${TMP_ARAZZO_DIR}/heur_arazzo.json"
[ "$(jq -r '.workflows[0].workflowId' "${TMP_ARAZZO_DIR}/heur_arazzo.json")" = "custom_checkout_pipeline" ]
[ "$(jq -r '.workflows[0].steps[0].operationId' "${TMP_ARAZZO_DIR}/heur_arazzo.json")" = "login_user" ]
[ "$(jq -r '.workflows[0].steps[1].operationId' "${TMP_ARAZZO_DIR}/heur_arazzo.json")" = "create_order" ]

echo "6. Testing cdd-sh from_arazzo to_sdk_cli and CLI workflow execution & round-tripping..."
CLI_OUT="${TMP_ARAZZO_DIR}/cli_out"
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_cli.json"
sh "${ROOT_DIR}/cdd.sh" from_arazzo to_sdk_cli -i "${ROOT_DIR}/tests/test_arazzo.json" -o "${CLI_OUT}"
[ -x "${CLI_OUT}/bin/sdk-cli" ]

# Test CLI workflow --help, --version, list, and run
"${CLI_OUT}/bin/sdk-cli" workflow --help | grep -q "authSetupFlow"
"${CLI_OUT}/bin/sdk-cli" workflow --version | grep -q "arazzo 1.1.0"
"${CLI_OUT}/bin/sdk-cli" workflow list | grep -q "orderCheckoutFlow"

# Test CLI MCP tools/list includes workflow tools
mcp_list_out=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | "${CLI_OUT}/bin/sdk-cli" mcp)
printf '%s' "${mcp_list_out}" | jq -e '.result.tools[] | select(.name == "workflow_orderCheckoutFlow")' >/dev/null

# Reverse-compile CLI back to Arazzo
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_rev_cli.json"
sh "${ROOT_DIR}/cdd.sh" to_arazzo -i "${CLI_OUT}/bin/sdk-cli" -o "${TMP_ARAZZO_DIR}/from_cli_arazzo.json"
[ "$(jq -r '.workflows | length' "${TMP_ARAZZO_DIR}/from_cli_arazzo.json")" = "2" ]

echo "7. Testing cdd-sh from_arazzo to_server, to_docs_json, and Server -> Arazzo round-tripping..."
SRV_OUT="${TMP_ARAZZO_DIR}/srv_out"
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_srv.json"
sh "${ROOT_DIR}/cdd.sh" from_arazzo to_server -i "${ROOT_DIR}/tests/test_arazzo.json" -o "${SRV_OUT}"
[ -x "${SRV_OUT}/src/server.sh" ]
[ -x "${SRV_OUT}/tests/test_workflows.sh" ]

# Test server handler mode for GET /_mock/workflows and POST /_mock/workflows/authSetupFlow
mock_wf_list=$(CDD_SSE_PATH="/_mock/workflows" CDD_SSE_METHOD="GET" CDD_SSE_AUTH="" CDD_SSE_BODY="" "${SRV_OUT}/src/server.sh" --handler | tail -n1)
printf '%s' "${mock_wf_list}" | jq -e '.workflows | length == 2' >/dev/null

# Reverse-compile Server back to Arazzo
export CDD_AST_PATH="${TMP_ARAZZO_DIR}/ast_rev_srv.json"
sh "${ROOT_DIR}/cdd.sh" to_arazzo -i "${SRV_OUT}/src/server.sh" -o "${TMP_ARAZZO_DIR}/from_srv_arazzo.json"
[ "$(jq -r '.workflows | length' "${TMP_ARAZZO_DIR}/from_srv_arazzo.json")" = "2" ]

# Test to_docs_json with Arazzo workflows
DOCS_OUT="${TMP_ARAZZO_DIR}/docs_out"
sh "${ROOT_DIR}/cdd.sh" from_arazzo to_docs_json -i "${ROOT_DIR}/tests/test_arazzo.json" -o "${DOCS_OUT}"
[ "$(jq -r '.workflows.orderCheckoutFlow.imports' "${DOCS_OUT}/docs.json")" = ". ./workflows.sh" ]
[ "$(jq -r '.workflows.orderCheckoutFlow.wrapper_start' "${DOCS_OUT}/docs.json")" = "main() {" ]
[ "$(jq -r '.workflows.orderCheckoutFlow.snippet' "${DOCS_OUT}/docs.json" | grep -c 'workflow_order_checkout_flow')" -ge 1 ]
[ "$(jq -r '.workflows.orderCheckoutFlow.snippet' "${DOCS_OUT}/docs.json" | grep -c 'adoptable-puppy')" -ge 1 ]
[ "$(jq -r '.workflows.orderCheckoutFlow.wrapper_end' "${DOCS_OUT}/docs.json")" = "$(printf '}\n\nmain "$@"')" ]

DOCS_DIRECT_DIR="${TMP_ARAZZO_DIR}/docs_direct"
mkdir -p "${DOCS_DIRECT_DIR}"
sh "${ROOT_DIR}/cdd.sh" to_docs_json --no-imports --no-wrapping -i "${ROOT_DIR}/tests/test_arazzo.json" -o "${DOCS_DIRECT_DIR}"
[ -f "${DOCS_DIRECT_DIR}/docs.json" ]
[ "$(jq -r '.workflows.authSetupFlow.imports' "${DOCS_DIRECT_DIR}/docs.json")" = "" ]
[ "$(jq -r '.workflows.authSetupFlow.wrapper_start' "${DOCS_DIRECT_DIR}/docs.json")" = "" ]
[ "$(jq -r '.workflows.authSetupFlow.wrapper_end' "${DOCS_DIRECT_DIR}/docs.json")" = "" ]
[ "$(jq -r '.workflows.authSetupFlow.snippet' "${DOCS_DIRECT_DIR}/docs.json" | grep -c 'alice')" -ge 1 ]

echo "8. Testing CLI workflow run flags (--step, --format yaml/table, --verbose, --input-file, --data-file) and error branches..."
printf '{"username":"charlie","itemName":"Bulldog","quantity":1}\n' >"${TMP_ARAZZO_DIR}/wf_inputs.json"
"${CLI_OUT}/bin/sdk-cli" workflow run authSetupFlow --input-file "${TMP_ARAZZO_DIR}/wf_inputs.json" --step loginStep --format yaml -v | grep -q "authToken:"
"${CLI_OUT}/bin/sdk-cli" workflow run authSetupFlow --data-file "${TMP_ARAZZO_DIR}/wf_inputs.json" --step loginStep --format json | grep -q "authToken"
"${CLI_OUT}/bin/sdk-cli" workflow run authSetupFlow --username charlie --format table | grep -q "authToken"

# Test MCP tools/call for workflow_authSetupFlow
mcp_call_out=$(printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"workflow_authSetupFlow","arguments":{"username":"dave"}}}\n' | "${CLI_OUT}/bin/sdk-cli" mcp)
printf '%s' "${mcp_call_out}" | jq -e '.result.isError == false' >/dev/null

# Test error branches: missing required input, invalid JSON input, exhausted retryLimit, missing file
(
	. "${SDK_OUT}/src/workflows.sh"
	if validate_workflow_auth_setup_flow_inputs "not-json" 2>/dev/null; then exit 1; fi
	if validate_workflow_auth_setup_flow_inputs '{}' 2>/dev/null; then exit 1; fi
	# getUsers simulates a persistent 500 error.
	getUsers() { return 1; }
	export ARAZZO_MOCK_STATUS=500
	unset ARAZZO_RETRY_RECOVERY_STATUS
	if workflow_auth_setup_flow '{"username":"alice"}' 2>/dev/null; then exit 1; fi
)
if sh "${ROOT_DIR}/cdd.sh" parse arazzo "${TMP_ARAZZO_DIR}/nonexistent.json" 2>/dev/null; then exit 1; fi
help_from_arz=$(sh "${ROOT_DIR}/cdd.sh" from_arazzo --help 2>&1 || true)
printf '%s\n' "${help_from_arz}" | grep -q "to_sdk"
help_to_arz=$(sh "${ROOT_DIR}/cdd.sh" to_arazzo --help 2>&1 || true)
printf '%s\n' "${help_to_arz}" | grep -q "arazzo.json"

echo "All Arazzo 1.1.0 tests passed!"
