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
        (if $isRequired then "  [ -z \"$_tmp_val_\($className)\" ] && return 1\n" else "" end) +
        
        if $propVal["$ref"] then
          "  if [ -n \"$_tmp_val_\($className)\" ]; then validate_\($propVal["$ref"] | split("/") | last) \"$_tmp_val_\($className)\" || return 1; fi\n"
        elif $propVal.type == "array" and $propVal.items["$ref"] then
          "  if [ -n \"$_tmp_val_\($className)\" ] && [ \"$_tmp_val_\($className)\" != \"null\" ]; then\n" +
          "    _count_\($className)=\"$(printf '%s' \"$_tmp_val_\($className)\" | jq -c 'length')\"\n" +
          "    _i_\($className)=0\n" +
          "    while [ \"$_i_\($className)\" -lt \"$_count_\($className)\" ]; do\n" +
          "      _item_\($className)=\"$(printf '%s' \"$_tmp_val_\($className)\" | jq -c \".[${_i_\($className)}]\")\"\n" +
          "      validate_\($propVal.items["$ref"] | split("/") | last) \"$_item_\($className)\" || return 1\n" +
          "      _i_\($className)=$((_i_\($className) + 1))\n" +
          "    done\n" +
          "  fi\n"
        else
          ""
        end
      ] | join(""))
    else "" end
  ) +
  "  return 0\n" +
  "}\n\n"
else empty end
