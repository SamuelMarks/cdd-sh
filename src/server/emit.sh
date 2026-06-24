#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
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
case "${STACK+x}" in *':'"${THIS_FILE}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${THIS_FILE}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_emit_server generates the SSE server application from the AST.
handle_emit_server() {
	output_file="$1"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n"
		printf "# @openapi_server_start\n"

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
# fake_name generates a random human name
function fake_name() {
    names[1]="Alice"; names[2]="Bob"; names[3]="Charlie"; names[4]="David"; names[5]="Eve"
    return names[int(rand()*5)+1]
}
# fake_email generates a random email address
function fake_email() {
    domains[1]="example.com"; domains[2]="test.org"; domains[3]="demo.net"
    return tolower(fake_name()) "@" domains[int(rand()*3)+1]
}
# fake_phone generates a random phone number string
function fake_phone() {
    return sprintf("555-%04d", int(rand()*10000))
}
# fake_uuid generates a pseudo-UUID v4
function fake_uuid() {
    return sprintf("%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535)
}
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
INNER_EOF

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
    if echo "$auth_header" | grep -qi "^Bearer "; then
      export OAUTH_TOKEN=$(echo "$auth_header" | sed -i.bak -e 's/^[Bb]earer *//' 2>/dev/null || echo "$auth_header" | sed 's/^[Bb]earer *//')
    elif echo "$auth_header" | grep -qi "^Basic "; then
      export BASIC_AUTH=$(echo "$auth_header" | sed -i.bak -e 's/^[Bb]asic *//' 2>/dev/null || echo "$auth_header" | sed 's/^[Bb]asic *//')
    else
      export API_KEY="$auth_header"
    fi
  fi



  json_method=$(echo "$body" | jq -r '.method // empty')
  json_id=$(echo "$body" | jq -r '.id // null')

  if [ "$json_method" = "initialize" ]; then
    out="{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{\"listChanged\":true},\"resources\":{\"listChanged\":true,\"subscribe\":true},\"logging\":{},\"prompts\":{\"listChanged\":true}},\"serverInfo\":{\"name\":\"SSE Server\",\"version\":\"0.0.3\"}}"
    response_json=$(jq -n --arg id "$json_id" --argjson out "$out" '{"jsonrpc": "2.0", "result": $out, "id": $id}')
  elif [ "$json_method" = "notifications/initialized" ] || [ "$json_method" = "initialized" ] || [ "$json_method" = "notifications/tools/list_changed" ] || [ "$json_method" = "notifications/resources/list_changed" ] || [ "$json_method" = "notifications/prompts/list_changed" ] || [ "$json_method" = "notifications/roots/list_changed" ] || [ "$json_method" = "notifications/cancelled" ] || [ "$json_method" = "notifications/progress" ] || [ "$json_method" = "notifications/resources/updated" ]; then
    response_json=""
  elif [ "$json_method" = "notifications/message" ]; then
    level=$(echo "$body" | jq -r '.params.level // "info"')
    msg=$(echo "$body" | jq -r '.params.data // ""')
    echo "[$level] $msg" >&2
    response_json=""
  elif [ "$json_method" = "completion/complete" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"completion":{"values":[],"total":0,"hasMore":false}}}')
  elif [ "$json_method" = "sampling/createMessage" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"role":"assistant","content":{"type":"text","text":"Sampled message"},"model":"test-model","stopReason":"endTurn"}}')
  elif [ "$json_method" = "ping" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{}}')
  elif [ "$json_method" = "roots/list" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"roots":[{"uri":"file:///" ,"name":"Workspace"}]}}')
  elif [ "$json_method" = "resources/list" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"resources":[{"uri":"openapi://spec","name":"OpenAPI Spec","mimeType":"application/json"}]}}')
  elif [ "$json_method" = "prompts/list" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"prompts":[{"name":"test_prompt","description":"A test prompt","arguments":[{"name":"arg1","description":"An argument","required":true}]}]}}')
  elif [ "$json_method" = "prompts/get" ]; then
    prompt_name=$(echo "$body" | jq -r '.params.name // empty')
    if [ "$prompt_name" = "test_prompt" ]; then
      response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"description":"A test prompt","messages":[{"role":"user","content":{"type":"text","text":"Please test this"}}]}}')
    else
      response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid prompt"},"id":$id}')
    fi
  elif [ "$json_method" = "logging/setLevel" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{}}')
  elif [ "$json_method" = "resources/templates/list" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"resourceTemplates":[]}}')
  elif [ "$json_method" = "resources/subscribe" ] || [ "$json_method" = "resources/unsubscribe" ]; then
    response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{}}')
  elif [ "$json_method" = "resources/read" ]; then
    uri=$(echo "$body" | jq -r '.params.uri // empty')
    if [ "$uri" = "openapi://spec" ]; then
      # Assume spec is available or return empty
      response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","id":$id,"result":{"contents":[{"uri":"openapi://spec","mimeType":"application/json","text":"{}"}]}}')
    else
      response_json=$(jq -n --arg id "$json_id" '{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid URI"},"id":$id}')
    fi
  elif [ "$json_method" = "tools/list" ]; then
INNER_EOF

		# Generate the static JSON string for tools/list at EMIT TIME
		tools_json=$(jq -c '
		  if .paths then
		    [
		      .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
		      (if .operationId then (.operationId | split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("")) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
		      {
		        name: $opId,
		        description: (.summary // "Call \($method) \($path)"),
		        inputSchema: {
		          type: "object",
		          properties: (
		            ((.parameters // []) | map({(.name): {type: (.schema.type // "string")}})) | add // {}
		          ),
		          required: (
		            ((.parameters // []) | map(select(.required == true) | .name)) // []
		          )
		        }
		      }
		    ]
		  else
		    []
		  end
		' "${ast}")
		tools_json=$(echo "$tools_json" | sed "s/'/'\\\\''/g")

		cat <<INNER_EOF
        tools_json='${tools_json}'
        cursor=\$(echo "\$body" | jq -r '.params.cursor // empty')
        if [ "\$cursor" = "next" ]; then
          res_tools="[]"
          next_cursor=""
        else
          res_tools="\$tools_json"
          next_cursor=",\"nextCursor\":\"next\""
        fi
        if [ "\$json_id" = "null" ]; then
          response_json="{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{\"tools\":\${res_tools}\${next_cursor}}}"
        elif echo "\$json_id" | grep -q "^[0-9]*\$"; then
          response_json="{\"jsonrpc\":\"2.0\",\"id\":\$json_id,\"result\":{\"tools\":\${res_tools}\${next_cursor}}}"
        else
          response_json="{\"jsonrpc\":\"2.0\",\"id\":\"\$json_id\",\"result\":{\"tools\":\${res_tools}\${next_cursor}}}"
        fi
      elif [ "\$json_method" = "tools/call" ]; then
        tool_name=\$(echo "\$body" | jq -r '.params.name')
        args=\$(echo "\$body" | jq -c '.params.arguments // {}')
        
        eval_args=\$(echo "\$args" | jq -r 'to_entries | map("--\(.key) '\''\(.value)'\''") | join(" ")')
        
        set +e
        if type "dao_\${ACTIVE_DAO}_\${tool_name}" >/dev/null 2>&1; then
          res=\$(eval "dao_\${ACTIVE_DAO}_\${tool_name}")
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
        if [ "$method" = "POST" ] && [ "${content_length:-0}" -lt 10 ]; then
             response_json="{\"error\": \"400 Bad Request: missing fields\"}"
             found="validation_failed"
        fi
      fi

      if [ "$found" = "true" ] || [ "$found" = "auth_failed" ] || [ "$found" = "validation_failed" ]; then
        res_len=$(printf "%s" "$response_json" | wc -c | tr -d ' ')
        printf "HTTP/1.1 200 OK\r\n"
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
