#!/bin/sh
set -eu

PORT="${CDD_PORT:-8080}"
LISTEN="${CDD_LISTEN:-0.0.0.0}"

echo "Starting JSON-RPC server on ${LISTEN}:${PORT}..."

if [ ! -p /tmp/cdd_fifo ]; then
  mkfifo /tmp/cdd_fifo
fi

while true; do
  {
    read -r line || true
    line=$(echo "$line" | tr -d '\r\n')
    if [ -z "$line" ]; then continue; fi

    # Read headers
    content_length=0
    while read -r header; do
      header=$(echo "$header" | tr -d '\r')
      if [ -z "$header" ]; then break; fi
      if echo "$header" | grep -qi "^Content-Length:"; then
        content_length=$(echo "$header" | awk '{print $2}')
      fi
    done

    body=""
    if [ "$content_length" -gt 0 ]; then
      body=$(dd bs=1 count="$content_length" 2>/dev/null)
    fi

    json_method=$(echo "$body" | jq -r '.method // empty')
    json_params=$(echo "$body" | jq -r '.params // []')
    json_id=$(echo "$body" | jq -r '.id // null')

    if [ -n "$json_method" ]; then
      args=$(echo "$json_params" | jq -r 'join(" ")')
      # shellcheck disable=SC2086
      out=$(./bin/cdd-sh "$json_method" $args 2>&1 || true)
      response_json=$(jq -n --arg id "$json_id" --arg out "$out" '{"jsonrpc": "2.0", "result": $out, "id": $id}')
      
      echo "HTTP/1.1 200 OK"
      echo "Content-Type: application/json"
      echo "Content-Length: $(echo "$response_json" | wc -c)"
      echo ""
      echo "$response_json"
    else
      echo "HTTP/1.1 400 Bad Request"
      echo "Content-Type: text/plain"
      echo "Content-Length: 11"
      echo ""
      echo "Bad Request"
    fi
  } < /tmp/cdd_fifo | nc -l -p "$PORT" > /tmp/cdd_fifo
done
