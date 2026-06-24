#!/bin/sh
set -eu

echo "Testing Sync with server.sh as source of truth..."

rm -rf temp-sync
mkdir -p temp-sync

# First, generate a normal server from petstore
./bin/cdd-sh from_openapi to_server -i ../petstore.json -o temp-sync/server

# Reverse gen
./bin/cdd-sh to_openapi -i temp-sync/server/src/server.sh -o temp-sync/spec.json

# Check if spec is generated
if [ ! -f temp-sync/spec.json ]; then
	echo "FAIL: Reverse sync did not output spec.json"
	exit 1
fi

# Assert sync
./bin/cdd-sh sync --truth server -i temp-sync/server/src/server.sh

if [ ! -f emitted_openapi.json ]; then
	echo "FAIL: Sync did not emit openapi.json"
	exit 1
fi

rm -rf temp-sync emitted_openapi.json
echo "Reverse sync successful"
