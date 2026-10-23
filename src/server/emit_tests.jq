# @file src/server/emit_tests.jq
# @description Generates topologically sorted composable integration test scripts and teardown suites for each OpenAPI operation using ###FILE### delimiters.
include "openapi";

# get_test_tier maps a path and HTTP method to its topological execution tier.
# @param $method: The HTTP method string.
# @param $path: The URL path string.
# @return Integer tier rank for creation (1..4) and reverse teardown (10..13).
def get_test_tier($method; $path):
  ($method | ascii_downcase) as $m |
  ($path | ascii_downcase) as $p |
  if $m == "delete" then
    if ($p | contains("comment")) then 10
    elif ($p | contains("post")) then 11
    elif ($p | contains("user")) then 12
    else 13 end
  else
    if ($p | contains("user")) then 1
    elif ($p | contains("post")) then 2
    elif ($p | contains("comment")) then 3
    else 4 end
  end;

if .paths then
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
    get_op_id($method; $path) as $opId |
    get_test_tier($method; $path) as $tier |
    {
      path: $path,
      method: $method,
      opId: $opId,
      tier: $tier,
      resolvedPath: ($path | gsub("\\{[^}]+\\}"; "1"))
    }
  ] | sort_by(.tier)) as $ops |
  "###FILE###run_all.sh\n" +
  "#!/bin/sh\n" +
  "# @file run_all.sh\n" +
  "# @description Master runner for generated server endpoint tests with topological tier ordering, dependency guards, reverse teardown, and clean state validation.\n" +
  "set -e\n" +
  "DIR=\"$(dirname \"$0\")\"\n" +
  "TIER1_OK=1\n" +
  "TIER2_OK=1\n" +
  ([ $ops[] |
    if .tier == 1 then
      "echo \"[Tier 1 - Independent] Testing \(.opId)...\"\n" +
      "if ! sh \"$DIR/test_\(.opId).sh\"; then TIER1_OK=0; echo \"FAIL: Tier 1 (\(.opId)) failed\" >&2; exit 1; fi\n"
    elif .tier == 2 then
      "if [ \"$TIER1_OK\" -ne 1 ]; then echo \"SKIP/FAIL: Dependency Setup Failed (Tier 1 prerequisite for \(.opId))\" >&2; exit 1; fi\n" +
      "echo \"[Tier 2 - Dependent] Testing \(.opId)...\"\n" +
      "if ! sh \"$DIR/test_\(.opId).sh\"; then TIER2_OK=0; echo \"FAIL: Tier 2 (\(.opId)) failed\" >&2; exit 1; fi\n"
    elif .tier == 3 then
      "if [ \"$TIER1_OK\" -ne 1 ] || [ \"$TIER2_OK\" -ne 1 ]; then echo \"SKIP/FAIL: Dependency Setup Failed (Tier 1/2 prerequisite for \(.opId))\" >&2; exit 1; fi\n" +
      "echo \"[Tier 3 - Sub-dependent] Testing \(.opId)...\"\n" +
      "sh \"$DIR/test_\(.opId).sh\"\n"
    elif .tier >= 10 then
      "echo \"[Teardown Tier \(.tier)] Testing \(.opId)...\"\n" +
      "sh \"$DIR/test_\(.opId).sh\"\n"
    else
      "echo \"Testing \(.opId)...\"\n" +
      "sh \"$DIR/test_\(.opId).sh\"\n"
    end
  ] | join("")) +
  "if [ -n \"${DATABASE_URL:-}\" ] && [ -d \"${DATABASE_URL}\" ]; then\n" +
  "  for _tbl_file in \"${DATABASE_URL}\"/*.json; do\n" +
  "    if [ -f \"$_tbl_file\" ] && [ \"${VERIFY_CLEAN_STATE:-0}\" = \"1\" ]; then\n" +
  "      _rem=$(jq 'length' \"$_tbl_file\" 2>/dev/null || echo 0)\n" +
  "      if [ \"$_rem\" -ne 0 ]; then\n" +
  "        echo \"FAIL: Clean State Validation failed for $_tbl_file (COUNT=$_rem != 0)\" >&2\n" +
  "        exit 1\n" +
  "      fi\n" +
  "    fi\n" +
  "  done\n" +
  "fi\n" +
  ([ $ops[] |
  "###FILE###test_\(.opId).sh\n" +
  "#!/bin/sh\n" +
  "# @file test_\(.opId).sh\n" +
  "# @description Integration test for \(.method | ascii_upcase) \(.path).\n" +
  "set -e\n" +
  "BASE_URL=\"${BASE_URL:-http://localhost:8080}\"\n" +
  (if (.method | ascii_upcase) == "POST" or (.method | ascii_upcase) == "PUT" then
    "res=$(curl -s -X \(.method | ascii_upcase) -H \"Content-Type: application/json\" -d '{\"id\":\"1\",\"name\":\"Alice\"}' \"$BASE_URL\(.resolvedPath)\")\n"
  else
    "res=$(curl -s -X \(.method | ascii_upcase) \"$BASE_URL\(.resolvedPath)\")\n"
  end) +
  "if [ -z \"$res\" ] || ! printf '%s\\n' \"$res\" | jq -e '.' >/dev/null 2>&1; then\n" +
  "  echo \"FAIL: \(.opId) (\(.method | ascii_upcase) \(.resolvedPath)) returned invalid JSON: $res\" >&2\n" +
  "  exit 1\n" +
  "fi\n" ] | join(""))
else
  empty
end
