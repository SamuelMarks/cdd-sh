#!/bin/sh
# @file tests/test_sync.sh
# @description Tests bidirectional synchronization using a generated server.sh as the source of truth.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"

echo "Testing Sync with server.sh as source of truth..."

SPEC_FILE="../petstore.json"
if [ ! -f "${SPEC_FILE}" ]; then
	SPEC_FILE="tests/test.json"
fi

# cleanup_sync removes temporary sync test artifacts.
# @param none
# @return Returns 0.
cleanup_sync() {
	rm -rf temp-sync emitted_openapi.json
}
trap cleanup_sync EXIT INT TERM

rm -rf temp-sync
mkdir -p temp-sync

# First, generate a normal server from spec
./bin/cdd-sh from_openapi to_server -i "${SPEC_FILE}" -o temp-sync/server

# Reverse gen
./bin/cdd-sh to_openapi -i temp-sync/server/src/server.sh -o temp-sync/spec.json

# Check if spec is generated and contains paths
if [ ! -f temp-sync/spec.json ] || ! jq -e '(.paths | length) > 0' temp-sync/spec.json >/dev/null; then
	echo "FAIL: Reverse sync did not output valid non-empty paths in spec.json"
	exit 1
fi

# Assert sync
./bin/cdd-sh sync --truth server -i temp-sync/server/src/server.sh -o temp-sync/synced

if [ ! -f temp-sync/synced/emitted_openapi.json ] || ! jq -e '(.paths | length) > 0' temp-sync/synced/emitted_openapi.json >/dev/null; then
	echo "FAIL: Sync did not emit valid non-empty openapi.json"
	exit 1
fi
if [ ! -f temp-sync/synced/emitted_docsjson.json ]; then
	echo "FAIL: Sync did not emit emitted_docsjson.json"
	exit 1
fi

echo "Reverse sync successful"
