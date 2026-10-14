# @file src/server/emit_tests.jq
# @description Generates composable integration test scripts for each OpenAPI operation using ###FILE### delimiters.
include "openapi";

if .paths then
  "###FILE###run_all.sh\n" +
  "#!/bin/sh\n" +
  "set -e\n" +
  "DIR=\"$(dirname \"$0\")\"\n" +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  get_op_id($method; $path) as $opId |
  "echo \"Testing \($opId)...\"\n" +
  "sh \"$DIR/test_\($opId).sh\"\n" ] | join("")) +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  get_op_id($method; $path) as $opId |
  ($path | gsub("\\{[^}]+\\}"; "1")) as $resolvedPath |
  "###FILE###test_\($opId).sh\n" +
  "#!/bin/sh\n" +
  "set -e\n" +
  "BASE_URL=\"${BASE_URL:-http://localhost:8080}\"\n" +
  "res=$(curl -s -X \($method | ascii_upcase) \"$BASE_URL\($resolvedPath)\")\n" +
  "if [ -z \"$res\" ] || ! printf '%s\\n' \"$res\" | jq -e '.' >/dev/null 2>&1; then\n" +
  "  echo \"FAIL: \($opId) (\($method | ascii_upcase) \($resolvedPath)) returned invalid JSON: $res\" >&2\n" +
  "  exit 1\n" +
  "fi\n" ] | join(""))
else
  empty
end
