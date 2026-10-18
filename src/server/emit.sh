#!/bin/sh
# @file src/server/emit.sh
# @description Emits the HTTP and MCP SSE server entrypoint script from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/mcp_handler.sh"

# handle_emit_server generates the SSE server application from the AST.
# @param $1: output_file - The destination path for the generated server script.
handle_emit_server() {
	output_file="$1"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n"
		printf "# shellcheck disable=SC2016,SC1090,SC1091,SC2235\n"
		printf "# @openapi_server_start\n"
		emit_mcp_handler_func
		printf "\n"

		cat <<'INNER_EOF'
PORT="${PORT:-8080}"

INNER_EOF

		if [ "${CDD_EPHEMERAL:-0}" = "1" ] || [ "${CDD_SEED:-0}" = "1" ] || [ "${CDD_STRICT_VALIDATION:-0}" = "1" ] || [ "${CDD_ENFORCE_AUTH:-0}" = "1" ] || [ "${CDD_START_AUTH_SERVER:-0}" = "1" ]; then
			cat <<'INNER_EOF'
EPHEMERAL=false
SEED=false
STRICT_VALIDATION="${CDD_STRICT_VALIDATION:-false}"
ENFORCE_AUTH="${CDD_ENFORCE_AUTH:-false}"
START_AUTH_SERVER="${CDD_START_AUTH_SERVER:-false}"
for arg in "$@"; do
  case "$arg" in
    --ephemeral) EPHEMERAL=true ;;
    --seed) SEED=true ;;
    --strict-validation) STRICT_VALIDATION=true ;;
    --enforce-auth) ENFORCE_AUTH=true ;;
    --start-auth-server) START_AUTH_SERVER=true ;;
  esac
done

if [ "$EPHEMERAL" = "true" ] || [ -n "${DATABASE_URL:-}" ]; then
  ACTIVE_DAO="concrete"
else
  ACTIVE_DAO="stub"
fi
INNER_EOF
		else
			cat <<'INNER_EOF'
ACTIVE_DAO="stub"
INNER_EOF
		fi

		if [ "${CDD_EPHEMERAL:-0}" = "1" ]; then
			cat <<'INNER_EOF'
# EPHEMERAL Database Connection Setup
# If EPHEMERAL=true, we override DATABASE_URL to a clean temp directory.
if [ "$EPHEMERAL" = "true" ]; then
  export DATABASE_URL="/tmp/cdd_ephemeral_db_$$"
  mkdir -p "$DATABASE_URL"
fi
INNER_EOF
		fi

		if [ "${CDD_SEED:-0}" = "1" ]; then
			cat <<'INNER_EOF'
if [ "$SEED" = "true" ] && [ "$ACTIVE_DAO" = "concrete" ]; then
  echo "Seeding database at $DATABASE_URL"
  # initialize_db_schema executes DB schema migrations for the Concrete DAOs.
  echo "CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, email TEXT);" > "$DATABASE_URL/schema.sql"
  # Documentation: The seeder module is responsible for initializing the Faker library
  # and batch inserting fake data to maintain referential integrity in the ephemeral DB.
  cat << 'FAKER_EOF' > /tmp/faker_$$.awk
INNER_EOF
			cat "${LIBSCRIPT_ROOT_DIR}/src/server/seeder/faker.awk"
			cat <<'INNER_EOF'
BEGIN {
    srand()
    for(i=0; i<10; i++) {
        id=fake_uuid()
        print "INSERT INTO users (id, name, email) VALUES ('" id "', '" fake_name() "', '" fake_email() "');"
    }
}
FAKER_EOF
  awk -f /tmp/faker_$$.awk > "$DATABASE_URL/seed.sql" || true
  rm -f /tmp/faker_$$.awk
fi
INNER_EOF
		fi

		cat <<'INNER_EOF'
# Load generated models
for _model_file in "$(dirname "$0")"/models/*.sh; do
  [ -f "$_model_file" ] && . "$_model_file"
done

# Load generated DAOs (mocks)
for _mock_file in "$(dirname "$0")"/mocks/*.sh; do
  [ -f "$_mock_file" ] && . "$_mock_file"
done

# Load generated route handlers and router
for _route_file in "$(dirname "$0")"/routes/*.sh; do
  [ -f "$_route_file" ] && . "$_route_file"
done

# Load generated Arazzo workflows if present
if [ -f "$(dirname "$0")/workflows.sh" ]; then
  # shellcheck disable=SC1091
  . "$(dirname "$0")/workflows.sh"
fi
INNER_EOF

		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "arazzo";
      if (.workflows and (.workflows | length) > 0) or .arazzo then
        "ARAZZO_SERVER_JSON=" + (extract_arazzo_spec | tojson | @sh) + "\n"
      else
        "ARAZZO_SERVER_JSON=\"\"\n"
      end
    ' "${ast}"

		cat <<'INNER_EOF'
# Use socat or nc as a reliable router. It will just execute this script with a special mode.
if [ "${1:-}" != "--handler" ]; then
echo "Starting SSE Server on port $PORT..."
echo "To test: curl -N http://localhost:$PORT/mcp/sse"
  cat << 'SH_EOF' > /tmp/cdd_sse_$$.sh
#!/bin/sh
method=""
path=""
auth_header=""
content_length=0

while IFS= read -r line; do
  line=$(printf "%s" "$line" | tr -d '\r')
  if [ -z "$method" ]; then
    method=$(printf "%s" "$line" | cut -d' ' -f1)
    path=$(printf "%s" "$line" | cut -d' ' -f2 | cut -d'?' -f1)
  fi
  if printf "%s" "$line" | grep -qi "^Authorization:"; then
    auth_header=$(printf "%s" "$line" | cut -d':' -f2- | sed 's/^ *//')
  fi
  if printf "%s" "$line" | grep -qi "^Content-Length:"; then
    content_length=$(printf "%s" "$line" | cut -d':' -f2 | sed 's/^ *//')
  fi
  if [ -z "$line" ]; then
    break
  fi
done

body=""
if [ "$content_length" -gt 0 ]; then
  body=$(dd bs=1 count="$content_length" 2>/dev/null)
fi

export CDD_SSE_PATH="$path"
export CDD_SSE_METHOD="$method"
export CDD_SSE_AUTH="$auth_header"
export CDD_SSE_BODY="$body"

if [ "$path" = "/mcp/sse" ] && [ "$method" = "GET" ]; then
  printf "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\nevent: endpoint\ndata: /mcp/message\n\n"
  while true; do sleep 10; done
else
  sh "$1" --handler
fi
SH_EOF
  chmod +x /tmp/cdd_sse_$$.sh

  if command -v socat >/dev/null 2>&1; then
    socat TCP4-LISTEN:"$PORT",reuseaddr,fork EXEC:"/tmp/cdd_sse_$$.sh \"$0\""
  else
    rm -f "/tmp/cdd_sse_pipe_$$"
    mkfifo "/tmp/cdd_sse_pipe_$$"
    # shellcheck disable=SC2094
    while true; do
      nc -l "$PORT" < "/tmp/cdd_sse_pipe_$$" | "/tmp/cdd_sse_$$.sh" "$0" > "/tmp/cdd_sse_pipe_$$"
    done
    rm -f "/tmp/cdd_sse_pipe_$$"
  fi
  rm -f /tmp/cdd_sse_$$.sh
  exit 0
fi

# We are in handler mode
path="${CDD_SSE_PATH}"
method="${CDD_SSE_METHOD}"
auth_header="${CDD_SSE_AUTH}"
body="${CDD_SSE_BODY}"

if [ "$method" = "OPTIONS" ]; then
  printf "HTTP/1.1 204 No Content\r\n"
  printf "Access-Control-Allow-Origin: *\r\n"
  printf "Access-Control-Allow-Methods: *\r\n"
  printf "Access-Control-Allow-Headers: *\r\n\r\n"
  exit 0
fi

if [ "$path" = "/mcp/message" ] && [ "$method" = "POST" ]; then
  if [ -n "$auth_header" ]; then
    case "$auth_header" in
      [Bb]earer\ *)
        export OAUTH_TOKEN="${auth_header#[Bb]earer }"
        ;;
      [Bb]asic\ *)
        export BASIC_AUTH="${auth_header#[Bb]asic }"
        ;;
      *)
        export API_KEY="$auth_header"
        ;;
    esac
  fi



  json_method=$(echo "$body" | jq -r '.method // empty')
  json_id=$(echo "$body" | jq -r '.id // null')
INNER_EOF

		tools_json_sh=$(jq -c -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "openapi"; include "arazzo"; (emit_mcp_tools + emit_mcp_workflow_tools)' "${ast}" | jq -R -r '@sh')

		cat <<INNER_EOF
  tools_json=${tools_json_sh}
  if response_json=\$(mcp_handle_common "\$body" "SSE Server" "0.0.4" "openapi://spec" "OpenAPI Spec" "{}" "\$tools_json" "file:///"); then
    :
  elif [ "\$json_method" = "tools/call" ]; then
        tool_name=\$(echo "\$body" | jq -r '.params.name')
        args=\$(echo "\$body" | jq -c '.params.arguments // {}')
        
        eval_args=\$(echo "\$args" | jq -r 'to_entries | map("--" + .key + " " + (.value | tostring | @sh)) | join(" ")')
        
        set +e
        if type "dao_\${ACTIVE_DAO}_\${tool_name}" >/dev/null 2>&1; then
          res=\$(eval "dao_\${ACTIVE_DAO}_\${tool_name} \$eval_args")
          exit_code=\$?
        elif type "\${tool_name}" >/dev/null 2>&1; then
          res=\$("\${tool_name}" "\$args")
          exit_code=\$?
        else
          res="{\"error\": \"Tool \$tool_name not implemented in DAO\"}"
          exit_code=1
        fi
        set -e
        
        res_escaped=\$(echo "\$res" | jq -R -s '.')
        if [ "\$exit_code" -ne 0 ]; then
          response_json=\$(jq -n --arg id "\$json_id" --argjson content "\$res_escaped" '{"jsonrpc":"2.0","id":\$id,"result":{"isError":true,"content":[{"type":"text","text":\$content}]}}')
        else
          response_json=\$(jq -n --arg id "\$json_id" --argjson content "\$res_escaped" '{"jsonrpc":"2.0","id":\$id,"result":{"isError":false,"content":[{"type":"text","text":\$content}]}}')
        fi
      else
        if [ "\$json_id" != "null" ]; then
          response_json=\$(jq -n --arg id "\$json_id" '{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": \$id}')
        else
          response_json=""
        fi
      fi
      
      found="true"
INNER_EOF

		cat <<'INNER_EOF'
      elif type router_dispatch >/dev/null 2>&1 && router_dispatch; then
        : # router_dispatch will set found="true" and response_json
INNER_EOF

		cat <<'INNER_EOF'
elif [ "$START_AUTH_SERVER" = "true" ] || [ "$START_AUTH_SERVER" = "1" ] && [ "$path" = "/auth/register" ] && [ "$method" = "POST" ]; then
  found="true"
  response_json="{\"token\": \"mock-token-123\"}"
elif [ "$START_AUTH_SERVER" = "true" ] || [ "$START_AUTH_SERVER" = "1" ] && [ "$path" = "/auth/login" ] && [ "$method" = "POST" ]; then
  found="true"
  response_json="{\"token\": \"mock-token-123\"}"
elif [ "$START_AUTH_SERVER" = "true" ] || [ "$START_AUTH_SERVER" = "1" ] && [ "$path" = "/auth/refresh" ] && [ "$method" = "POST" ]; then
  found="true"
  response_json="{\"token\": \"mock-token-123\"}"
elif [ "$START_AUTH_SERVER" = "true" ] || [ "$START_AUTH_SERVER" = "1" ] && [ "$path" = "/auth/logout" ] && [ "$method" = "POST" ]; then
  found="true"
  response_json="{}"
elif echo "$path" | grep -q "^/_mock/trigger-webhook/" && [ "$method" = "POST" ]; then
  found="true"
  webhook_name=$(echo "$path" | sed 's|^/_mock/trigger-webhook/||')
  response_json="{\"status\": \"dispatched\", \"webhook\": \"$webhook_name\"}"
elif [ "$path" = "/_mock/workflows" ] && [ "$method" = "GET" ]; then
  found="true"
  if [ -n "${ARAZZO_SERVER_JSON:-}" ]; then
    response_json=$(printf '%s' "${ARAZZO_SERVER_JSON}" | jq -c '{workflows: [.workflows[]? | {workflowId: .workflowId, summary: (.summary // ""), dependsOn: (.dependsOn // [])}]}')
  else
    response_json="{\"workflows\":[]}"
  fi
elif echo "$path" | grep -q "^/_mock/workflows/" && [ "$method" = "POST" ]; then
  found="true"
  _mock_wf_id=$(echo "$path" | sed 's|^/_mock/workflows/||')
  _mock_wf_fn="workflow_$(printf '%s' "${_mock_wf_id}" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_]/_/g')"
  if type "${_mock_wf_fn}" >/dev/null 2>&1; then
    response_json=$("${_mock_wf_fn}" "${body:-{}}")
  else
    response_json="{\"status\": \"executed\", \"workflowId\": \"${_mock_wf_id}\"}"
  fi
INNER_EOF

		cat <<'INNER_EOF'
      else
        found="false"
      fi


      if [ "$found" = "true" ]; then
        if ( [ "$ENFORCE_AUTH" = "true" ] || [ "$ENFORCE_AUTH" = "1" ] ) && ! echo "$path" | grep -q "^/auth/" && ! echo "$path" | grep -q "^/_mock/"; then
          if [ -z "$auth_header" ] || [ "$auth_header" != "Bearer mock-token-123" ]; then
            response_json="{\"error\": \"401 Unauthorized\"}"
            found="auth_failed"
          fi
        fi
      fi
      if [ "$found" = "true" ] && ( [ "$STRICT_VALIDATION" = "true" ] || [ "$STRICT_VALIDATION" = "1" ] ) && ! echo "$path" | grep -q "^/auth/" && ! echo "$path" | grep -q "^/_mock/"; then
        if [ "$method" = "POST" ] || [ "$method" = "PUT" ]; then
          if [ -z "$body" ] || [ "$body" = "{}" ] || ! printf "%s" "$body" | jq -e 'type == "object" and (keys | length) > 0' >/dev/null 2>&1; then
            response_json="{\"error\": \"400 Bad Request: missing fields\"}"
            found="validation_failed"
          else
            for _model_file in "$(dirname "$0")"/models/model_*.sh; do
              if [ -f "$_model_file" ]; then
                _mname=$(basename "$_model_file" .sh)
                _mname="${_mname#model_}"
                if type "validate_${_mname}" >/dev/null 2>&1; then
                  if ! "validate_${_mname}" "$body" >/dev/null 2>&1; then
                    response_json="{\"error\": \"400 Bad Request: validation failed for ${_mname}\"}"
                    found="validation_failed"
                    break
                  fi
                fi
              fi
            done
          fi
        fi
      fi

      if [ "$found" = "true" ] || [ "$found" = "auth_failed" ] || [ "$found" = "validation_failed" ]; then
        res_len=${#response_json}
        if [ "$found" = "auth_failed" ]; then
          printf "HTTP/1.1 401 Unauthorized\r\n"
        elif [ "$found" = "validation_failed" ]; then
          printf "HTTP/1.1 400 Bad Request\r\n"
        else
          printf "HTTP/1.1 200 OK\r\n"
        fi
        printf "Access-Control-Allow-Origin: *\r\n"
        printf "Access-Control-Allow-Methods: *\r\n"
        printf "Access-Control-Allow-Headers: *\r\n"
        if [ -n "$response_json" ]; then
          printf "Content-Type: application/json\r\n"
        fi
        printf "Content-Length: %s\r\n\r\n" "${res_len}"
        if [ -n "$response_json" ]; then
          printf "%s" "$response_json"
        fi
      else
        printf "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found"
      fi
INNER_EOF

		printf "# @openapi_server_end\n"
	} >"${output_file}.tmp"

	if [ -f "${output_file}" ]; then
		awk -v new_file="${output_file}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" <"${output_file}" >"${output_file}.merged"
		mv "${output_file}.merged" "${output_file}"
		rm -f "${output_file}.tmp"
	else
		mv "${output_file}.tmp" "${output_file}"
	fi
	chmod +x "${output_file}"
}
