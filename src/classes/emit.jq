if .components and .components.schemas then
  .components.schemas | to_entries[] | .key as $className | .value as $schema |
  
  "# @class \($className)\n" +
  (if $schema.description then "# @description \($schema.description)\n" else "" end) +
  (
    if $schema.properties then
      ([$schema.properties | to_entries[] | 
        if .value["$ref"] then
          "# @property \(.key): \(.value["$ref"] | split("/") | last)"
        elif .value.type == "array" and .value.items["$ref"] then
          "# @property \(.key): \(.value.items["$ref"] | split("/") | last)[]"
        else
          "# @property \(.key): \(.value.type // "any")"
        end
      ] | join("\n")) + "\n"
    else "" end
  ) +
  (
    if $schema.required then
      "# @required \($schema.required | join(", "))\n"
    else "" end
  ) +
  "validate_\($className)() {\n" +
  "  _payload_\($className)=\"${1:-}\"\n" +
  "  [ -z \"${_payload_\($className)}\" ] && return 1\n" +
  (
    if $schema.properties then
      ([$schema.properties | to_entries[] | 
        .key as $propKey | .value as $propVal |
        (if $schema.required and ($schema.required | contains([$propKey])) then true else false end) as $isRequired |
        
        "  _tmp_val_\($className)=\"$(_get_prop \"${_payload_\($className)}\" \"\($propKey)\")\"\n" +
        (if $propVal.default != null then "  if [ -z \"$_tmp_val_\($className)\" ] || [ \"$_tmp_val_\($className)\" = \"null\" ]; then _tmp_val_\($className)=\($propVal.default | tojson | tojson); fi\n" else "" end) +
        (if $isRequired then "  [ -z \"$_tmp_val_\($className)\" ] || [ \"$_tmp_val_\($className)\" = \"null\" ] && return 1\n" else "" end) +
        "  if [ -n \"$_tmp_val_\($className)\" ] && [ \"$_tmp_val_\($className)\" != \"null\" ]; then\n" +
        "    :\n" +
        (if $propVal.type == "integer" or $propVal.type == "number" then
          (if $propVal.minimum != null then "    [ \"$_tmp_val_\($className)\" -lt \($propVal.minimum) ] && return 1\n" else "" end) +
          (if $propVal.maximum != null then "    [ \"$_tmp_val_\($className)\" -gt \($propVal.maximum) ] && return 1\n" else "" end) +
          (if $propVal.exclusiveMinimum != null then "    [ \"$_tmp_val_\($className)\" -le \($propVal.exclusiveMinimum) ] && return 1\n" else "" end) +
          (if $propVal.exclusiveMaximum != null then "    [ \"$_tmp_val_\($className)\" -ge \($propVal.exclusiveMaximum) ] && return 1\n" else "" end)
        else "" end) +
        (if $propVal.type == "string" then
          "    _len_\($className)=\"${#_tmp_val_\($className)}\"\n" +
          "    _len_\($className)=$((_len_\($className) - 2))\n" +
          (if $propVal.minLength != null then "    [ \"$_len_\($className)\" -lt \($propVal.minLength) ] && return 1\n" else "" end) +
          (if $propVal.maxLength != null then "    [ \"$_len_\($className)\" -gt \($propVal.maxLength) ] && return 1\n" else "" end) +
          (if $propVal.pattern != null then "    printf '%s' \"$_tmp_val_\($className)\" | jq -e 'test(\"\($propVal.pattern)\")' >/dev/null || return 1\n" else "" end) +
          (if $propVal.format == "email" then "    printf '%s' \"$_tmp_val_\($className)\" | jq -e 'test(\"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,}$\")' >/dev/null || return 1\n" else "" end) +
          (if $propVal.format == "uri" then "    printf '%s' \"$_tmp_val_\($className)\" | jq -e 'test(\"^https?://\")' >/dev/null || return 1\n" else "" end)
        else "" end) +
        (if $propVal.enum then
          "    _enum_ok_\($className)=0\n" +
          "    " + ([$propVal.enum[] | "if [ \"$_tmp_val_\($className)\" = \(.|tojson|tojson) ]; then _enum_ok_\($className)=1; fi"] | join("\n    ")) + "\n" +
          "    [ \"$_enum_ok_\($className)\" -eq 0 ] && return 1\n"
        else "" end) +
        (if $propVal.type == "array" then
          "    _count_\($className)=\"$(printf '%s' \"$_tmp_val_\($className)\" | jq -c 'length')\"\n" +
          (if $propVal.minItems != null then "    [ \"$_count_\($className)\" -lt \($propVal.minItems) ] && return 1\n" else "" end) +
          (if $propVal.maxItems != null then "    [ \"$_count_\($className)\" -gt \($propVal.maxItems) ] && return 1\n" else "" end) +
          (if $propVal.uniqueItems == true then "    _uniq_count_\($className)=\"$(printf '%s' \"$_tmp_val_\($className)\" | jq -c 'unique | length')\"\n    [ \"$_count_\($className)\" -ne \"$_uniq_count_\($className)\" ] && return 1\n" else "" end)
        else "" end) +
        (if $propVal["$ref"] then
          "    validate_\($propVal["$ref"] | split("/") | last) \"$_tmp_val_\($className)\" || return 1\n"
        elif $propVal.type == "array" and $propVal.items["$ref"] then
          "    _i_\($className)=0\n" +
          "    while [ \"$_i_\($className)\" -lt \"$_count_\($className)\" ]; do\n" +
          "      _item_\($className)=\"$(printf '%s' \"$_tmp_val_\($className)\" | jq -c \".[${_i_\($className)}]\")\"\n" +
          "      validate_\($propVal.items["$ref"] | split("/") | last) \"$_item_\($className)\" || return 1\n" +
          "      _i_\($className)=$((_i_\($className) + 1))\n" +
          "    done\n"
        else
          ""
        end) +
        (if $propVal.allOf then
          "    " + ([$propVal.allOf[] | if .["$ref"] then "validate_\(.["$ref"] | split("/") | last) \"$_tmp_val_\($className)\" || return 1" else "" end] | select(. != "") | join(";\n    ")) + "\n"
        else "" end) +
        (if $propVal.anyOf then
          "    _any_ok_\($className)=0\n" +
          "    " + ([$propVal.anyOf[] | if .["$ref"] then "if validate_\(.["$ref"] | split("/") | last) \"$_tmp_val_\($className)\" >/dev/null 2>&1; then _any_ok_\($className)=1; fi" else "" end] | select(. != "") | join("\n    ")) + "\n" +
          "    [ \"$_any_ok_\($className)\" -eq 0 ] && return 1\n"
        else "" end) +
        (if $propVal.oneOf then
          "    _one_ok_\($className)=0\n" +
          "    " + ([$propVal.oneOf[] | if .["$ref"] then "if validate_\(.["$ref"] | split("/") | last) \"$_tmp_val_\($className)\" >/dev/null 2>&1; then _one_ok_\($className)=$((_one_ok_\($className) + 1)); fi" else "" end] | select(. != "") | join("\n    ")) + "\n" +
          "    [ \"$_one_ok_\($className)\" -ne 1 ] && return 1\n"
        else "" end) +
        "  fi\n"
      ] | join(""))
    else "" end
  ) +
  (if $schema.allOf then
    "  # allOf\n" +
    "  " + ([$schema.allOf[] | if .["$ref"] then "validate_\(.["$ref"] | split("/") | last) \"${_payload_\($className)}\" || return 1" else "" end] | select(. != "") | join(";\n  ")) + "\n"
  else "" end) +
  (if $schema.anyOf then
    "  # anyOf\n" +
    "  _any_ok_\($className)=0\n" +
    "  " + ([$schema.anyOf[] | if .["$ref"] then "if validate_\(.["$ref"] | split("/") | last) \"${_payload_\($className)}\" >/dev/null 2>&1; then _any_ok_\($className)=1; fi" else "" end] | select(. != "") | join("\n    ")) + "\n" +
    "  [ \"$_any_ok_\($className)\" -eq 0 ] && return 1\n"
  else "" end) +
  (if $schema.oneOf then
    "  # oneOf\n" +
    "  _one_ok_\($className)=0\n" +
    "  " + ([$schema.oneOf[] | if .["$ref"] then "if validate_\(.["$ref"] | split("/") | last) \"${_payload_\($className)}\" >/dev/null 2>&1; then _one_ok_\($className)=$((_one_ok_\($className) + 1)); fi" else "" end] | select(. != "") | join("\n  ")) + "\n" +
    "  [ \"$_one_ok_\($className)\" -ne 1 ] && return 1\n"
  else "" end) +
  "  return 0\n" +
  "}\n\n"
else empty end
