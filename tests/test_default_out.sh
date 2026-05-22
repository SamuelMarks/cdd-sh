#!/bin/sh
# Auto-generated Data Classes
set -eu

_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class Config
# @property retryCount: integer
# @required retryCount
validate_Config() {
  _payload_Config="${1:-}"
  [ -z "${_payload_Config}" ] && return 1
  _tmp_val_Config="$(_get_prop "${_payload_Config}" "retryCount")"
  if [ -z "$_tmp_val_Config" ] || [ "$_tmp_val_Config" = "null" ]; then _tmp_val_Config="3"; fi
  [ -z "$_tmp_val_Config" ] || [ "$_tmp_val_Config" = "null" ] && return 1
  if [ -n "$_tmp_val_Config" ] && [ "$_tmp_val_Config" != "null" ]; then
    :
    [ "$_tmp_val_Config" -gt 5 ] && return 1
  fi
  return 0
}


