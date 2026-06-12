#!/bin/sh
# Auto-generated Data Classes
set -eu
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

_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class User
# @property age: integer
# @property username: string
# @property tags: array
# @required age, username
validate_User() {
  _payload_User="${1:-}"
  [ -z "${_payload_User}" ] && return 1
  _tmp_val_User="$(_get_prop "${_payload_User}" "age")"
  [ -z "$_tmp_val_User" ] || [ "$_tmp_val_User" = "null" ] && return 1
  if [ -n "$_tmp_val_User" ] && [ "$_tmp_val_User" != "null" ]; then
    :
    [ "$_tmp_val_User" -lt 18 ] && return 1
    [ "$_tmp_val_User" -gt 120 ] && return 1
  fi
  _tmp_val_User="$(_get_prop "${_payload_User}" "username")"
  [ -z "$_tmp_val_User" ] || [ "$_tmp_val_User" = "null" ] && return 1
  if [ -n "$_tmp_val_User" ] && [ "$_tmp_val_User" != "null" ]; then
    :
    _len_User="${#_tmp_val_User}"
    _len_User=$((_len_User - 2))
    [ "$_len_User" -lt 3 ] && return 1
    [ "$_len_User" -gt 20 ] && return 1
    printf '%s' "$_tmp_val_User" | jq -e 'test("^[a-z0-9]+$")' >/dev/null || return 1
  fi
  _tmp_val_User="$(_get_prop "${_payload_User}" "tags")"
  if [ -n "$_tmp_val_User" ] && [ "$_tmp_val_User" != "null" ]; then
    :
    _count_User="$(printf '%s' "$_tmp_val_User" | jq -c 'length')"
    [ "$_count_User" -lt 1 ] && return 1
    [ "$_count_User" -gt 5 ] && return 1
    _uniq_count_User="$(printf '%s' "$_tmp_val_User" | jq -c 'unique | length')"
    [ "$_count_User" -ne "$_uniq_count_User" ] && return 1
  fi
  return 0
}


