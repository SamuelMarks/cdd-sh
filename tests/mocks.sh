#!/bin/sh
# shellcheck disable=SC3028,SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"

# curl overrides the system curl to return mock data from emitted_mocks.json
curl() {
  if [ -f "$DIR/mocks.json" ]; then
    # Simply return the first mock we find, or `{}`.
    body=$(jq -r 'if type == "array" and length > 0 then .[0] else . end | tojson' "$DIR/mocks.json" 2>/dev/null || echo "{}")
  else
    body="{}"
  fi
  printf "%s\n" "$body"
}
