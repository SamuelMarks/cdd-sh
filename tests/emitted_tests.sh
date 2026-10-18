#!/bin/sh
set -eu

# shellcheck disable=SC3028,SC2034
DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
BASE_URL="${BASE_URL:-http://localhost:8080/v2}"
export BASE_URL
export API_KEY="special-key"
export OAUTH_TOKEN="special-key"
export BASIC_AUTH="user:pass"

# curl is a wrapper around the system curl command.
curl() {
  out=$(command curl -s -w "\n%{http_code}" "$@" || true)
  status=$(printf "%s\n" "$out" | tail -n1)
  body=$(printf "%s\n" "$out" | sed '$d')
  printf "%s\n" "$body"
  if [ "$status" -lt 200 ] || [ "$status" -ge 400 ]; then
    echo "HTTP error: $status" >&2
    exit 1
  fi
}
# shellcheck disable=SC1090,SC1091,SC2034
. "${DIR}/emitted_routes.sh"

# test createUser
test_createUser() {
  echo "Testing createUser"
  out=$(createUser )
  if [ -n "$out" ]; then
    echo "$out" | jq empty >/dev/null || { echo "Failed to deserialize"; exit 1; }
  fi
}

# test getUsers
test_getUsers() {
  echo "Testing getUsers"
  out=$(getUsers )
  if [ -n "$out" ]; then
    echo "$out" | jq empty >/dev/null || { echo "Failed to deserialize"; exit 1; }
  fi
}

# test customRoute
test_customRoute() {
  echo "Testing customRoute"
  out=$(customRoute "test_string")
  if [ -n "$out" ]; then
    echo "$out" | jq empty >/dev/null || { echo "Failed to deserialize"; exit 1; }
  fi
}

# run all tests
run_all_tests() {
  touch test_string
  test_createUser
  test_getUsers
  test_customRoute
}

if ! (return 0 2>/dev/null); then
  run_all_tests "$@"
fi

