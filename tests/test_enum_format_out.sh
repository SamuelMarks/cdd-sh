#!/bin/sh
# Auto-generated Data Classes
set -eu

_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class Contact
# @property email: string
# @property status: string
# @required email, status
validate_Contact() {
  _payload_Contact="${1:-}"
  [ -z "${_payload_Contact}" ] && return 1
  _tmp_val_Contact="$(_get_prop "${_payload_Contact}" "email")"
  [ -z "$_tmp_val_Contact" ] || [ "$_tmp_val_Contact" = "null" ] && return 1
  if [ -n "$_tmp_val_Contact" ] && [ "$_tmp_val_Contact" != "null" ]; then
    :
    _len_Contact="${#_tmp_val_Contact}"
    _len_Contact=$((_len_Contact - 2))
    printf '%s' "$_tmp_val_Contact" | jq -e 'test("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")' >/dev/null || return 1
  fi
  _tmp_val_Contact="$(_get_prop "${_payload_Contact}" "status")"
  [ -z "$_tmp_val_Contact" ] || [ "$_tmp_val_Contact" = "null" ] && return 1
  if [ -n "$_tmp_val_Contact" ] && [ "$_tmp_val_Contact" != "null" ]; then
    :
    _len_Contact="${#_tmp_val_Contact}"
    _len_Contact=$((_len_Contact - 2))
    _enum_ok_Contact=0
    if [ "$_tmp_val_Contact" = "\"active\"" ]; then _enum_ok_Contact=1; fi
    if [ "$_tmp_val_Contact" = "\"inactive\"" ]; then _enum_ok_Contact=1; fi
    [ "$_enum_ok_Contact" -eq 0 ] && return 1
  fi
  return 0
}


