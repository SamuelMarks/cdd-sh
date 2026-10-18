# @file src/server/emit_workflows.jq
# @description Generates composable E2E workflow integration test scripts (test_workflows.sh and test_workflow_<id>.sh) from the Arazzo AST using ###FILE### delimiters.
include "arazzo";

. as $root |
if .workflows and (.workflows | length) > 0 then
  "###FILE###test_workflows.sh\n" +
  "#!/bin/sh\n" +
  "# @file test_workflows.sh\n" +
  "# @description Master E2E Arazzo workflow test suite runner.\n" +
  "set -e\n" +
  "DIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"\n" +
  "if [ -f \"${DIR}/../src/workflows.sh\" ]; then\n" +
  "  # shellcheck disable=SC1091\n" +
  "  . \"${DIR}/../src/workflows.sh\"\n" +
  "fi\n" +
  ([ .workflows[] | "sh \"${DIR}/test_workflow_\(.workflowId | gsub("[^a-zA-Z0-9_]"; "_")).sh\"" ] | join("\n")) + "\n" +
  "echo \"All Arazzo workflow E2E tests passed!\"\n" +
  (
    [
      .workflows[] |
      . as $wf |
      ($wf.workflowId) as $wfId |
      ($wfId | gsub("[^a-zA-Z0-9_]"; "_")) as $safeId |
      get_workflow_fn_name($wfId) as $fnName |
      (
        if $wf.inputs and $wf.inputs.properties then
          ($wf.inputs.properties | with_entries(
            .value = (
              if .value.default != null then .value.default
              elif .value.enum and (.value.enum | length) > 0 then .value.enum[0]
              elif .value.type == "integer" or .value.type == "number" then (.value.minimum // 1)
              elif .value.type == "boolean" then true
              elif .value.type == "array" then []
              elif .value.type == "object" then {}
              else "test_\(.key)"
              end
            )
          ))
        else
          {}
        end
      ) as $seedInputs |
      "\n###FILE###test_workflow_\($safeId).sh\n" +
      "#!/bin/sh\n" +
      "# @file test_workflow_\($safeId).sh\n" +
      "# @workflow \($wfId)\n" +
      "# @description E2E integration test for Arazzo workflow \($wfId).\n" +
      "set -e\n" +
      "DIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"\n" +
      "if [ -f \"${DIR}/../src/workflows.sh\" ]; then\n" +
      "  # shellcheck disable=SC1091\n" +
      "  . \"${DIR}/../src/workflows.sh\"\n" +
      "fi\n" +
      "SEED_INPUTS=\($seedInputs | tojson | @sh)\n" +
      "if type \($fnName) >/dev/null 2>&1; then\n" +
      "  res=$(\($fnName) \"${SEED_INPUTS}\")\n" +
      "  if ! printf '%s' \"${res}\" | jq -e '.' >/dev/null 2>&1; then\n" +
      "    echo \"FAIL: workflow \($wfId) returned invalid JSON: ${res}\" >&2\n" +
      "    exit 1\n" +
      "  fi\n" +
      "elif [ -n \"${BASE_URL:-}\" ]; then\n" +
      "  res=$(curl -s -X POST \"${BASE_URL}/_mock/workflows/\($wfId)\" -H \"Content-Type: application/json\" -d \"${SEED_INPUTS}\")\n" +
      "  if ! printf '%s' \"${res}\" | jq -e '.' >/dev/null 2>&1; then\n" +
      "    echo \"FAIL: /_mock/workflows/\($wfId) returned invalid JSON: ${res}\" >&2\n" +
      "    exit 1\n" +
      "  fi\n" +
      "fi\n" +
      "echo \"PASS: workflow \($wfId)\"\n"
    ] | join("")
  )
else
  empty
end
