#!/bin/sh
# Auto-generated Data Classes
set -eu

_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class Dog
# @property bark: boolean
# @required bark
validate_Dog() {
  _payload_Dog="${1:-}"
  [ -z "${_payload_Dog}" ] && return 1
  _tmp_val_Dog="$(_get_prop "${_payload_Dog}" "bark")"
  [ -z "$_tmp_val_Dog" ] || [ "$_tmp_val_Dog" = "null" ] && return 1
  if [ -n "$_tmp_val_Dog" ] && [ "$_tmp_val_Dog" != "null" ]; then
    :
  fi
  return 0
}


# @class Cat
# @property meow: boolean
# @required meow
validate_Cat() {
  _payload_Cat="${1:-}"
  [ -z "${_payload_Cat}" ] && return 1
  _tmp_val_Cat="$(_get_prop "${_payload_Cat}" "meow")"
  [ -z "$_tmp_val_Cat" ] || [ "$_tmp_val_Cat" = "null" ] && return 1
  if [ -n "$_tmp_val_Cat" ] && [ "$_tmp_val_Cat" != "null" ]; then
    :
  fi
  return 0
}


# @class Pet
# @property animal: any
# @required animal
validate_Pet() {
  _payload_Pet="${1:-}"
  [ -z "${_payload_Pet}" ] && return 1
  _tmp_val_Pet="$(_get_prop "${_payload_Pet}" "animal")"
  [ -z "$_tmp_val_Pet" ] || [ "$_tmp_val_Pet" = "null" ] && return 1
  if [ -n "$_tmp_val_Pet" ] && [ "$_tmp_val_Pet" != "null" ]; then
    :
    _one_ok_Pet=0
    if validate_Dog "$_tmp_val_Pet" >/dev/null 2>&1; then _one_ok_Pet=$((_one_ok_Pet + 1)); fi
    if validate_Cat "$_tmp_val_Pet" >/dev/null 2>&1; then _one_ok_Pet=$((_one_ok_Pet + 1)); fi
    [ "$_one_ok_Pet" -ne 1 ] && return 1
  fi
  return 0
}


