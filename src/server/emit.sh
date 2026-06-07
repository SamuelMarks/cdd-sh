#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
if [ "${SCRIPT_NAME-}" ]; then this_file="${SCRIPT_NAME}"; elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else this_file="${0}"; fi
case "${STACK+x}" in *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
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
echo "Starting SSE Server on port $PORT..."
echo "To test: curl -N http://localhost:$PORT/mcp/sse"

# Use python as a reliable router. It will just execute this script with a special mode.
if [ "${1:-}" != "--handler" ]; then
  cat << 'PYEOF' > /tmp/cdd_sse_$$.py
import http.server
import socketserver
import subprocess
import os
import sys

PORT = int(os.environ.get("PORT", 8080))
class Handler(http.server.BaseHTTPRequestHandler):
    def handle_request(self, method):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else ""
        auth = self.headers.get('Authorization', '')
        
        env = os.environ.copy()
        env["CDD_SSE_PATH"] = self.path
        env["CDD_SSE_METHOD"] = method
        env["CDD_SSE_AUTH"] = auth
        env["CDD_SSE_BODY"] = body
        
        res = subprocess.run(["sh", sys.argv[1], "--handler"], env=env, capture_output=True, text=True)
        
        lines = res.stdout.split('\n')
        status = 500
        headers = {}
        body_start = 0
        
        # Find the actual HTTP response start
        http_start_idx = -1
        for idx, line in enumerate(lines):
            if line.startswith("HTTP/1.1 "):
                http_start_idx = idx
                break
                
        if http_start_idx >= 0:
            parts = lines[http_start_idx].split(' ')
            status = int(parts[1])
            body_start = http_start_idx + 1
            for i in range(http_start_idx + 1, len(lines)):
                body_start = i + 1
                if lines[i] == '':
                    break
                if ':' in lines[i]:
                    k, v = lines[i].split(':', 1)
                    headers[k.strip()] = v.strip()
                
        out_body = '\n'.join(lines[body_start:])
        
        self.send_response(status)
        for k, v in headers.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(out_body.encode('utf-8'))
        
    def do_GET(self):
        if self.path == "/mcp/sse":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"event: endpoint\ndata: /mcp/message\n\n")
            import time
            while True:
                time.sleep(10)
        else:
            self.handle_request("GET")
    def do_POST(self): self.handle_request("POST")

socketserver.TCPServer.allow_reuse_address = True
try:
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    pass
PYEOF
  python3 /tmp/cdd_sse_$$.py "$0"
  rm -f /tmp/cdd_sse_$$.py
  exit 0
fi

# We are in handler mode
path="${CDD_SSE_PATH}"
method="${CDD_SSE_METHOD}"
auth_header="${CDD_SSE_AUTH}"
body="${CDD_SSE_BODY}"

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
    out="{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{\"listChanged\":true},\"resources\":{\"listChanged\":true,\"subscribe\":true},\"logging\":{},\"prompts\":{\"listChanged\":true}},\"serverInfo\":{\"name\":\"SSE Server\",\"version\":\"0.0.2\"}}"
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
		      (if .operationId then (.operationId | gsub("([a-z])([A-Z])"; "\(.captures[0].string)_\(.captures[1].string)") | ascii_downcase) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
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
        res=\$(eval "./bin/sdk-cli \$tool_name \$eval_args" 2>&1 || eval "./tests/out/bin/sdk-cli \$tool_name \$eval_args" 2>&1 || eval "../bin/sdk-cli \$tool_name \$eval_args" 2>&1)
        exit_code=\$?
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
      
      res_len=\$(printf "%s" "\$response_json" | wc -c | tr -d ' ')
      echo "HTTP/1.1 200 OK"
      if [ -n "\$response_json" ]; then
        echo "Content-Type: application/json"
      fi
      echo "Content-Length: \${res_len}"
      echo ""
      if [ -n "\$response_json" ]; then
        printf "%s" "\$response_json"
      fi
else
  echo "HTTP/1.1 404 Not Found"
  echo "Content-Length: 9"
  echo ""
  echo "Not Found"
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
