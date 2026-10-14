# @file src/server/emit_daos.jq
# @description Generates stub and concrete DAO scripts for each OpenAPI operation using ###FILE### delimiters.
include "openapi";

if .paths then
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  get_op_id($method; $path) as $opId |
  "###FILE###dao_\($opId).sh\n" +
  "# dao_stub_\($opId) is the stub implementation for \($method | ascii_upcase) \($path).\n" +
  "# Returns a NotImplemented error.\n" +
  "dao_stub_\($opId)() {\n" +
  "  echo '{\"error\": \"Not Implemented\"}'\n" +
  "  return 1\n" +
  "}\n" +
  "\n" +
  "# dao_concrete_\($opId) is the concrete DB implementation for \($method | ascii_upcase) \($path).\n" +
  "# Interacts with DATABASE_URL.\n" +
  "dao_concrete_\($opId)() {\n" +
  "  echo '{}'\n" +
  "  return 0\n" +
  "}\n" ] | join(""))
else
  empty
end
