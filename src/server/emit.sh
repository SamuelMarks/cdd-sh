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
		printf "# @file %s\n" "${output_file##*/}"
		printf "# @description Auto-generated HTTP and MCP SSE server.\n"
		printf "# shellcheck disable=SC2016,SC1090,SC1091,SC2235\n"
		printf "# @openapi_server_start\n"
		emit_mcp_handler_func
		printf "\n"

		cat <<'INNER_EOF'
PORT="${PORT:-8080}"

EPHEMERAL="${CDD_EPHEMERAL:-false}"
SEED="${CDD_SEED:-false}"
HANDLER_MODE=false
STRICT_VALIDATION="${CDD_STRICT_VALIDATION:-false}"
ENFORCE_AUTH="${CDD_ENFORCE_AUTH:-false}"
START_AUTH_SERVER="${CDD_START_AUTH_SERVER:-false}"
for arg in "$@"; do
  case "$arg" in
    --ephemeral) EPHEMERAL=true ;;
    --seed) SEED=true ;;
    --handler) HANDLER_MODE=true ;;
    --strict-validation) STRICT_VALIDATION=true ;;
    --enforce-auth) ENFORCE_AUTH=true ;;
    --start-auth-server) START_AUTH_SERVER=true ;;
  esac
done

if [ "$EPHEMERAL" = "true" ] || [ "$EPHEMERAL" = "1" ] || [ -n "${DATABASE_URL:-}" ]; then
  ACTIVE_DAO="concrete"
else
  ACTIVE_DAO="stub"
fi

# EPHEMERAL Database Connection Setup
# If EPHEMERAL=true and we are not a per-request child of _sse_sh, override DATABASE_URL to a clean temp directory.
if ( [ "$EPHEMERAL" = "true" ] || [ "$EPHEMERAL" = "1" ] ) && [ "${_CDD_SRV_HANDLING:-0}" != "1" ]; then
  export DATABASE_URL=$(mktemp -d "${TMPDIR:-/tmp}/cdd_ephemeral_db_XXXXXX")
fi
INNER_EOF

		schema_sql=$(jq -r '
			"CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, email TEXT);\n" +
			"CREATE TABLE IF NOT EXISTS posts (id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id), title TEXT);\n" +
			"CREATE TABLE IF NOT EXISTS comments (id TEXT PRIMARY KEY, post_id TEXT REFERENCES posts(id), user_id TEXT REFERENCES users(id), body TEXT);" +
			(if .components and .components.schemas then
				([ .components.schemas | to_entries[] | select(.value.properties != null) |
					(.key | ascii_downcase | gsub("[^a-z0-9_]"; "_")) as $tbl |
					([ .value.properties | keys[] | gsub("[^a-zA-Z0-9_]"; "_") + " TEXT" ] | join(", ")) as $cols |
					if $cols != "" then "\nCREATE TABLE IF NOT EXISTS \($tbl) (\($cols));" else empty end
				] | join(""))
			else "" end)
		' "${ast}")

		cat <<INNER_EOF
# seed_database executes DB schema migrations and populates the relational dependency graph (Users -> Posts -> Comments).
# @param \$1: db_dir - Path to the database directory.
# @return Returns 0 on success.
seed_database() {
  _db_dir="\${1:-\$DATABASE_URL}"
  mkdir -p "\$_db_dir"
  echo "Seeding database at \$_db_dir"
  cat << 'SCHEMA_EOF' > "\$_db_dir/schema.sql"
${schema_sql}
SCHEMA_EOF
  _faker_script=\$(mktemp "\${TMPDIR:-/tmp}/cdd_faker.XXXXXX")
  cat << 'FAKER_EOF' > "\$_faker_script"
INNER_EOF
		cat "${LIBSCRIPT_ROOT_DIR}/src/server/seeder/faker.awk"
		cat <<'INNER_EOF'
BEGIN {
    srand()
    seed_relational_graph(10, 50, 200)
}
FAKER_EOF
  awk -f "$_faker_script" > "$_db_dir/seed.sql" || true
  rm -f "$_faker_script"
}

if ( [ "$SEED" = "true" ] || [ "$SEED" = "1" ] ) && [ "$ACTIVE_DAO" = "concrete" ] && [ -n "${DATABASE_URL:-}" ] && [ ! -f "$DATABASE_URL/seed.sql" ]; then
  seed_database "$DATABASE_URL"
fi
INNER_EOF

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
if [ "${1:-}" != "--handler" ] && [ "${HANDLER_MODE:-false}" != "true" ]; then
  _srv_rt_dir=$(mktemp -d "${TMPDIR:-/tmp}/cdd_srv_rt.XXXXXX")
  _sse_sh="${_srv_rt_dir}/sse_handler.sh"
  _sse_pipe="${_srv_rt_dir}/sse_pipe"
  # shellcheck disable=SC2064
  trap "rm -rf \"${_srv_rt_dir}\"; [ \"\${EPHEMERAL:-false}\" = \"true\" ] && [ -n \"\${DATABASE_URL:-}\" ] && rm -rf \"\${DATABASE_URL}\"" EXIT INT TERM
echo "Starting SSE Server on port $PORT..."
echo "To test: curl -N http://localhost:$PORT/mcp/sse"
  cat << 'SH_EOF' > "$_sse_sh"
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
  _CDD_SRV_HANDLING=1 sh "$1" --handler
fi
SH_EOF
  chmod +x "$_sse_sh"

  if command -v socat >/dev/null 2>&1; then
    socat TCP4-LISTEN:"$PORT",reuseaddr,fork EXEC:"\"$_sse_sh\" \"$0\""
  else
    mkfifo "$_sse_pipe"
    # shellcheck disable=SC2094
    while true; do
      nc -l "$PORT" < "$_sse_pipe" | "$_sse_sh" "$0" > "$_sse_pipe"
    done
  fi
  rm -rf "$_srv_rt_dir"
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
        
        eval_args=\$(echo "\$args" | jq -r 'to_entries | map(select(.key | test("^[a-zA-Z0-9_-]+$")) | "--" + .key + " " + (.value | tostring | @sh)) | join(" ")')
        
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
          _expected_auth="${CDD_EXPECTED_AUTH_TOKEN:-Bearer mock-token-123}"
          if [ -z "$auth_header" ] || [ "$auth_header" != "${_expected_auth}" ]; then
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
          elif [ -n "${matched_req_model:-}" ] && type "validate_${matched_req_model}" >/dev/null 2>&1; then
            if ! "validate_${matched_req_model}" "$body" >/dev/null 2>&1; then
              response_json="{\"error\": \"400 Bad Request: validation failed for ${matched_req_model}\"}"
              found="validation_failed"
            fi
          else
            _any_model_exists=0
            _any_model_passed=0
            _first_failed_model=""
            for _model_file in "$(dirname "$0")"/models/model_*.sh; do
              if [ -f "$_model_file" ]; then
                _mname=$(basename "$_model_file" .sh)
                _mname="${_mname#model_}"
                if type "validate_${_mname}" >/dev/null 2>&1; then
                  _any_model_exists=1
                  if "validate_${_mname}" "$body" >/dev/null 2>&1; then
                    _any_model_passed=1
                    break
                  elif [ -z "${_first_failed_model}" ]; then
                    _first_failed_model="${_mname}"
                  fi
                fi
              fi
            done
            if [ "${_any_model_exists}" -eq 1 ] && [ "${_any_model_passed}" -eq 0 ]; then
              response_json="{\"error\": \"400 Bad Request: validation failed for ${_first_failed_model}\"}"
              found="validation_failed"
            fi
          fi
        fi
      fi

      if [ "$found" = "true" ] || [ "$found" = "auth_failed" ] || [ "$found" = "validation_failed" ]; then
        res_len=$(printf "%s" "$response_json" | wc -c | tr -d ' ')
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

	merge_or_move_emitted_file "${output_file}" "1"
}
