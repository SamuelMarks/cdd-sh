#!/bin/sh
# Auto-generated Data Classes
set -eu

# get property
_get_prop() {
  printf '%s' "$1" | jq -c ".\"$2\" // empty"
}

# @class Product
# @description A product model
# @property id: string
# @property name: string
# @property price: number
# @required id, name
