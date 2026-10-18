#!/bin/sh
# @file src/tests/parse.sh
# @description Parses generated test scripts to extract operation test examples into the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_tests parses test scripts into the AST, recording operation test invocations.
# @param $1: file_path - The input test script path (default: test_routes.sh).
handle_parse_tests() {
	file_path="${1:-test_routes.sh}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: file not found at %s\n" "${file_path}" >&2
		return 1
	fi
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 0; fi

	test_ops=$(awk -v dq='"' '
      BEGIN {
          printf "{"
          first = 1
          op = ""
      }
      /^test_[a-zA-Z0-9_]+\(\) \{/ {
          op = $1
          sub(/^test_/, "", op)
          sub(/\(\)$/, "", op)
          next
      }
      /out=\$\(/ {
          if (op != "") {
              line = $0
              sub(/^[ \t]*out=\$\(/, "", line)
              sub(/\)[ \t]*$/, "", line)
              gsub(/\\/, "\\\\", line)
              gsub(/"/, "\\\"", line)
              if (!first) printf ","
              first = 0
              printf "%s%s%s:%s%s%s", dq, op, dq, dq, line, dq
              op = ""
          }
      }
      END {
          printf "}\n"
      }
    ' "${file_path}")

	if [ "$test_ops" != "{}" ]; then
		jq --argjson tests "$test_ops" '
      if .paths then
        .paths |= with_entries(
          .value |= with_entries(
            if (.value | type) == "object" and .value.operationId and $tests[.value.operationId] then
              .value["x-test-invocation"] = $tests[.value.operationId]
            else . end
          )
        )
      else . end |
      if (.workflows == null or (.workflows | length) == 0) then
        .arazzo = (.arazzo // "1.1.0") |
        .workflows = [
          {
            workflowId: "testSuiteWorkflow",
            summary: "Synthesized workflow from test suite invocations",
            steps: (
              $tests | to_entries | map({
                stepId: ("step_" + .key),
                operationId: .key,
                successCriteria: [{"condition": "$statusCode == 200"}]
              })
            )
          }
        ]
      else . end
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	fi
}
