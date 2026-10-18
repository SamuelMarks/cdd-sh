#!/bin/sh
# Auto-generated API Client
set -eu

BASE_URL="${BASE_URL:-https://api.test.com}"
OAUTH_TOKEN="${OAUTH_TOKEN:-}"
API_KEY="${API_KEY:-}"

# urlencode 
_urlencode() {
  printf '%s' "$1" | jq -s -R -r '@uri'
}

# quote_sh safely escapes a string for eval.
_quote_sh() {
  printf '%s' "$1" | jq -s -R -r '@sh'
}

# serialize matrix
_serialize_matrix() {
  if [ "$3" = "true" ]; then
    printf "%s" "$2" | awk -F, -v n="$1" '{for(i=1;i<=NF;i++) printf ";"n"="$i}'
  else
    printf ";%s=%s" "$1" "$2"
  fi
}

# serialize label
_serialize_label() {
  if [ "$3" = "true" ]; then
    printf "%s" "$2" | awk -F, '{for(i=1;i<=NF;i++) printf "."$i}'
  else
    printf ".%s" "$2"
  fi
}

# @function getUsers
# @description Get all users
getUsers() {
  url="${BASE_URL}/users"
  qs=""
  curl_args=""
  [ -n "${qs}" ] && url="${url}?${qs#&}"
  # shellcheck disable=SC2086
  eval curl -s -X GET ${curl_args} "$(_quote_sh "${url}")"
}


# @function createUser
# @description Create a user
createUser() {
  url="${BASE_URL}/users"
  qs=""
  curl_args=""
  [ -n "${qs}" ] && url="${url}?${qs#&}"
  # shellcheck disable=SC2086
  eval curl -s -X POST ${curl_args} "$(_quote_sh "${url}")"
}


# @function customRoute
# @description A newly added custom route
# @param $1: id (path) - User ID
customRoute() {
  id="${1:-}"
  id="$(_urlencode "${id}")"
  url="${BASE_URL}/custom/${id}"
  curl -s -X DELETE "${url}"
}
