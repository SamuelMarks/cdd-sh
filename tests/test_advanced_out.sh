#!/bin/sh
# Auto-generated Data Classes
set -eu

_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class BasePet
# @property name: string
# @required name
validate_BasePet() {
  _payload_BasePet="${1:-}"
  [ -z "${_payload_BasePet}" ] && return 1
  _tmp_val_BasePet="$(_get_prop "${_payload_BasePet}" "name")"
  [ -z "$_tmp_val_BasePet" ] || [ "$_tmp_val_BasePet" = "null" ] && return 1
  if [ -n "$_tmp_val_BasePet" ] && [ "$_tmp_val_BasePet" != "null" ]; then
    :
    _len_BasePet="${#_tmp_val_BasePet}"
    _len_BasePet=$((_len_BasePet - 2))
  fi
  return 0
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
  # allOf
  validate_BasePet "${_payload_Dog}" || return 1
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
  # allOf
  validate_BasePet "${_payload_Cat}" || return 1
  return 0
}


# @class Pet
validate_Pet() {
  _payload_Pet="${1:-}"
  [ -z "${_payload_Pet}" ] && return 1
  # oneOf
  _one_ok_Pet=0
  if validate_Dog "${_payload_Pet}" >/dev/null 2>&1; then _one_ok_Pet=$((_one_ok_Pet + 1)); fi
  if validate_Cat "${_payload_Pet}" >/dev/null 2>&1; then _one_ok_Pet=$((_one_ok_Pet + 1)); fi
  [ "$_one_ok_Pet" -ne 1 ] && return 1
  return 0
}


# @class AnyPet
validate_AnyPet() {
  _payload_AnyPet="${1:-}"
  [ -z "${_payload_AnyPet}" ] && return 1
  # anyOf
  _any_ok_AnyPet=0
  if validate_Dog "${_payload_AnyPet}" >/dev/null 2>&1; then _any_ok_AnyPet=1; fi
    if validate_Cat "${_payload_AnyPet}" >/dev/null 2>&1; then _any_ok_AnyPet=1; fi
  [ "$_any_ok_AnyPet" -eq 0 ] && return 1
  return 0
}


