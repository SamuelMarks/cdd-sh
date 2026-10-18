#!/bin/sh
# Auto-generated Data Classes
set -eu

# get property
_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class Library
# @property books: Book[]
# @required books
validate_Library() {
  _payload_Library="${1:-}"
  [ -z "${_payload_Library}" ] && return 1
  _tmp_val_Library="$(_get_prop "${_payload_Library}" "books")"
  [ -z "$_tmp_val_Library" ] || [ "$_tmp_val_Library" = "null" ] && return 1
  if [ -n "$_tmp_val_Library" ] && [ "$_tmp_val_Library" != "null" ]; then
    :
    _count_Library="$(printf '%s' "$_tmp_val_Library" | jq -c 'length')"
    _i_Library=0
    while [ "$_i_Library" -lt "$_count_Library" ]; do
      _item_Library="$(printf '%s' "$_tmp_val_Library" | jq -c ".[${_i_Library}]")"
      validate_Book "$_item_Library" || return 1
      _i_Library=$((_i_Library + 1))
    done
  fi
  return 0
}


# @class Book
# @property title: string
# @required title
validate_Book() {
  _payload_Book="${1:-}"
  [ -z "${_payload_Book}" ] && return 1
  _tmp_val_Book="$(_get_prop "${_payload_Book}" "title")"
  [ -z "$_tmp_val_Book" ] || [ "$_tmp_val_Book" = "null" ] && return 1
  if [ -n "$_tmp_val_Book" ] && [ "$_tmp_val_Book" != "null" ]; then
    :
    _len_Book="${#_tmp_val_Book}"
    _len_Book=$((_len_Book - 2))
  fi
  return 0
}


