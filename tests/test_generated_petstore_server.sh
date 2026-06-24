#!/bin/sh
set -eu

TYPE="$1"
SPEC="$2"

if [ ! -f "$SPEC" ]; then
	echo "Warning: $SPEC not found, skipping."
	exit 0
fi

OUT_SERVER="temp-server-$TYPE"
OUT_SDK="temp-sdk-$TYPE"

rm -rf "$OUT_SERVER" "$OUT_SDK"

echo "Generating Server for $TYPE..."
./bin/cdd-sh from_openapi to_server -i "$SPEC" -o "$OUT_SERVER"

echo "Generating SDK for $TYPE..."
./bin/cdd-sh from_openapi to_sdk -i "$SPEC" -o "$OUT_SDK"

PORT=8111
if [ "$TYPE" = "openapi" ]; then
	PORT=8112
fi

echo "Starting generated server on port $PORT..."
PORT=$PORT sh "$OUT_SERVER/src/server.sh" --ephemeral </dev/null >/dev/null 2>&1 &
SERVER_PID=$!
sleep 2
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

export BASE_URL="http://localhost:$PORT"

echo "Testing SDK against generated server ($BASE_URL)..."
# shellcheck disable=SC1091
. "$OUT_SDK/src/routes.sh"

res=$(findPetsByStatus "available" 2>&1 || echo "ERROR")
if ! printf "%s" "$res" | grep -q "{"; then
	echo "FAIL: SDK findPetsByStatus against generated server did not return {} (returned: $res)"
	kill $SERVER_PID 2>/dev/null || true
	exit 1
fi

echo "$TYPE generated server SDK test passed!"
kill $SERVER_PID 2>/dev/null || true
rm -rf "$OUT_SERVER" "$OUT_SDK"
