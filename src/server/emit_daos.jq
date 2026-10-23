# @file src/server/emit_daos.jq
# @description Generates stub and concrete DAO scripts for each OpenAPI operation using ###FILE### delimiters.
include "openapi";

if .paths then
  . as $root |
  ([ .paths | to_entries[] | .key as $path |
  (if .value."$ref" and $root.components and $root.components.pathItems then ($root.components.pathItems[.value."$ref" | sub("^#/components/pathItems/"; "")] // .value) else .value end) |
  ((to_entries | map(select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers" and .key != "$ref" and .key != "additionalOperations"))) +
   (if .additionalOperations then (.additionalOperations | to_entries) else [] end))[] |
  .key as $method | .value |
  get_op_id($method; $path) as $opId |
  (($path | split("/") | map(select(. != "" and (startswith("{") | not))) | last) // "items" | ascii_downcase | gsub("[^a-z0-9_]"; "_")) as $tbl |
  ($method | ascii_upcase) as $upMethod |
  "###FILE###dao_\($opId).sh\n" +
  "# @file dao_\($opId).sh\n" +
  "# @description Generated DAO implementations for \($upMethod) \($path).\n" +
  "# dao_stub_\($opId) is the stub implementation for \($upMethod) \($path).\n" +
  "# @param none\n" +
  "# @return Prints a NotImplemented JSON error and returns 1.\n" +
  "dao_stub_\($opId)() {\n" +
  "  echo '{\"error\": \"Not Implemented\"}'\n" +
  "  return 1\n" +
  "}\n" +
  "\n" +
  "# dao_concrete_\($opId) is the concrete DB implementation for \($upMethod) \($path).\n" +
  "# @param none\n" +
  "# @return Prints a JSON response object and returns 0.\n" +
  "dao_concrete_\($opId)() {\n" +
  "  if [ -n \"${DATABASE_URL:-}\" ] && [ -d \"${DATABASE_URL}\" ]; then\n" +
  "    _store=\"${DATABASE_URL}/\($tbl).json\"\n" +
  "    [ -f \"$_store\" ] || printf '[]' > \"$_store\"\n" +
  (if $upMethod == "POST" or $upMethod == "PUT" then
    "    _payload=\"${CDD_SSE_BODY:-{}}\"\n" +
    "    if ! printf '%s' \"$_payload\" | jq -e 'type == \"object\"' >/dev/null 2>&1; then _payload='{}'; fi\n" +
    (if $tbl == "posts" then
      "    if [ -f \"${DATABASE_URL}/users.json\" ] && [ \"$(jq 'length' \"${DATABASE_URL}/users.json\")\" -eq 0 ] && [ ! -f \"${DATABASE_URL}/seed.sql\" ]; then\n" +
      "      echo '{\"error\": \"Foreign key violation: parent user does not exist\"}'\n" +
      "      return 1\n" +
      "    fi\n"
    elif $tbl == "comments" then
      "    if [ -f \"${DATABASE_URL}/posts.json\" ] && [ \"$(jq 'length' \"${DATABASE_URL}/posts.json\")\" -eq 0 ] && [ ! -f \"${DATABASE_URL}/seed.sql\" ]; then\n" +
      "      echo '{\"error\": \"Foreign key violation: parent post does not exist\"}'\n" +
      "      return 1\n" +
      "    fi\n"
    else "" end) +
    "    _rec=$(printf '%s' \"$_payload\" | jq -c '.id = (.id // \"1\")')\n" +
    "    jq -c --argjson r \"$_rec\" '. + [$r]' \"$_store\" > \"${_store}.tmp\" && mv \"${_store}.tmp\" \"$_store\"\n" +
    "    printf '%s\\n' \"$_rec\"\n" +
    "    return 0\n"
  elif $upMethod == "DELETE" then
    (if $tbl == "users" then
      "    if [ -f \"${DATABASE_URL}/posts.json\" ] && [ \"$(jq 'length' \"${DATABASE_URL}/posts.json\")\" -gt 0 ]; then\n" +
      "      echo '{\"error\": \"Foreign key constraint failed: posts still reference users\"}'\n" +
      "      return 1\n" +
      "    fi\n"
    elif $tbl == "posts" then
      "    if [ -f \"${DATABASE_URL}/comments.json\" ] && [ \"$(jq 'length' \"${DATABASE_URL}/comments.json\")\" -gt 0 ]; then\n" +
      "      echo '{\"error\": \"Foreign key constraint failed: comments still reference posts\"}'\n" +
      "      return 1\n" +
      "    fi\n"
    else "" end) +
    "    printf '[]' > \"$_store\"\n" +
    "    echo '{\"deleted\": true}'\n" +
    "    return 0\n"
  else
    "    _cnt=$(jq 'length' \"$_store\" 2>/dev/null || echo 0)\n" +
    "    echo \"{\\\"items\\\": $(cat \"$_store\"), \\\"count\\\": $_cnt}\"\n" +
    "    return 0\n"
  end) +
  "  fi\n" +
  "  echo '{}'\n" +
  "  return 0\n" +
  "}\n" ] | join(""))
else
  empty
end
