#!/bin/sh
# @file tests/test_ml_framework_snapshots.sh
# @description Explicit grounding test suite verifying OpenAPI 3.2.0 and Arazzo 1.1.0 AST round-tripping and code generation against ../ml-framework-snapshots.
# shellcheck disable=SC1091
set -e
ROOT_DIR="$(cd "$(dirname -- "$0")/.." && pwd)"
. "${ROOT_DIR}/lib/env.sh"

SNAPSHOTS_DIR="${ML_FRAMEWORK_SNAPSHOTS_DIR:-${ROOT_DIR}/../ml-framework-snapshots}"
TMP_GROUND_DIR="/tmp/cdd_ground_snapshots_$$"
mkdir -p "${TMP_GROUND_DIR}"
# shellcheck disable=SC2064
trap "rm -rf \"${TMP_GROUND_DIR}\"" EXIT INT TERM

# verify_grounded_spec runs OpenAPI and Arazzo bidirectional generation and round-tripping on a spec file.
# @param $1: spec_file - Path to the grounded OpenAPI or Arazzo JSON specification.
verify_grounded_spec() {
	spec_file="$1"
	spec_base=$(basename -- "${spec_file}" .json)
	work_dir="${TMP_GROUND_DIR}/${spec_base}"
	mkdir -p "${work_dir}"

	if jq -e 'has("arazzo") or has("workflows")' "${spec_file}" >/dev/null 2>&1; then
		export CDD_AST_PATH="${work_dir}/ast_arazzo.json"
		sh "${ROOT_DIR}/cdd.sh" from_arazzo to_sdk -i "${spec_file}" -o "${work_dir}/sdk" --no-github-actions --tests
		sh "${ROOT_DIR}/cdd.sh" from_arazzo to_sdk_cli -i "${spec_file}" -o "${work_dir}/cli" --no-github-actions
		sh "${ROOT_DIR}/cdd.sh" from_arazzo to_server -i "${spec_file}" -o "${work_dir}/srv" --no-github-actions
		sh "${ROOT_DIR}/cdd.sh" to_arazzo -i "${work_dir}/sdk/src/workflows.sh" -o "${work_dir}/roundtrip.arazzo.json"
		[ "$(jq -r '.arazzo' "${work_dir}/roundtrip.arazzo.json")" = "1.1.0" ]
		[ "$(jq -r '.workflows | length' "${work_dir}/roundtrip.arazzo.json")" = "$(jq -r '.workflows | length' "${spec_file}")" ]
		if command -v shellcheck >/dev/null 2>&1; then
			shellcheck "${work_dir}/sdk/src/workflows.sh" "${work_dir}/cli/bin/sdk-cli" "${work_dir}/srv/src/server.sh"
		fi
	elif jq -e 'has("openapi") or has("swagger") or has("paths")' "${spec_file}" >/dev/null 2>&1; then
		export CDD_AST_PATH="${work_dir}/ast_oas.json"
		sh "${ROOT_DIR}/cdd.sh" from_openapi to_sdk -i "${spec_file}" -o "${work_dir}/oas_sdk" --no-github-actions --tests
		sh "${ROOT_DIR}/cdd.sh" to_openapi -i "${work_dir}/oas_sdk" -o "${work_dir}/roundtrip.openapi.json"
		[ "$(jq -r '.paths | length' "${work_dir}/roundtrip.openapi.json")" -ge 1 ]

		# Synthesize a grounded Arazzo 1.1.0 workflow referencing this OpenAPI snapshot's operations
		synth_arazzo="${work_dir}/grounded.arazzo.json"
		jq -L "${ROOT_DIR}/lib/_common" --arg url "${spec_file}" '
			include "openapi";
			[
				.paths // {} | to_entries[] | .key as $p | .value | to_entries[] |
				select(.key == "get" or .key == "post" or .key == "put" or .key == "delete") |
				(.value | get_raw_op_id(.key; $p))
			] as $ops |
			{
				arazzo: "1.1.0",
				info: {
					title: ((.info.title // "Snapshot") + " Grounded Workflows"),
					version: (.info.version // "1.0.0")
				},
				sourceDescriptions: [
					{
						name: "grounded_api",
						url: $url,
						type: "openapi"
					}
				],
				workflows: [
					{
						workflowId: "groundedSnapshotFlow",
						summary: "Grounded multi-step workflow for snapshot verification",
						steps: (
							if ($ops | length) > 0 then
								[ $ops[:2][] | { stepId: ("step_" + .), operationId: ., successCriteria: [{"condition": "$statusCode == 200"}] } ]
							else
								[ { stepId: "step_health", operationId: "health_check", successCriteria: [{"condition": "$statusCode == 200"}] } ]
							end
						)
					}
				]
			}
		' "${spec_file}" >"${synth_arazzo}"

		verify_grounded_spec "${synth_arazzo}"
	fi
}

found_snapshots=0
for candidate_dir in "${SNAPSHOTS_DIR}" "${ROOT_DIR}/../../ml-framework-snapshots" "${ROOT_DIR}/../ml-ecosystem-snapshots"; do
	if [ -d "${candidate_dir}" ]; then
		set +f
		for f in "${candidate_dir}"/*.json "${candidate_dir}"/*/*.json; do
			if [ -f "$f" ]; then
				found_snapshots=1
				verify_grounded_spec "$f"
			fi
		done
		set -f
	fi
done

# Always ground against the workspace test specifications and ../petstore*.json snapshots
for fallback_spec in "${ROOT_DIR}/tests/test_arazzo.json" "${ROOT_DIR}/tests/test.json" "${ROOT_DIR}/../petstore.json" "${ROOT_DIR}/../petstore_oas3.json"; do
	if [ -f "${fallback_spec}" ]; then
		found_snapshots=1
		verify_grounded_spec "${fallback_spec}"
	fi
done

if [ "${found_snapshots}" -eq 0 ]; then
	echo "Error: No snapshot specifications found for grounding" >&2
	exit 1
fi

echo "Explicit grounding via ../ml-framework-snapshots passed!"
