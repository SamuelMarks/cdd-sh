#!/bin/sh
# @file src/workflows/parse.sh
# @description Parses POSIX shell workflow orchestrators (annotated or heuristic) into the Arazzo AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_workflows parses a workflows.sh script (or unannotated shell script calling route functions) into the AST.
# @param $1: file_path - The input shell workflow script path (default: workflows.sh).
handle_parse_workflows() {
	file_path="${1:-workflows.sh}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: Workflow file not found at %s\n" "${file_path}" >&2
		return 1
	fi

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf '{"arazzo": "1.1.0"}\n' >"${ast}"
	fi

	extracted_lines=$(awk '
	# @function flush_step
	# @description Emits the currently accumulated step metadata line.
	function flush_step() {
		if (step_id == "" || wf_id == "") return
		printf "STEP:%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", wf_id, step_id, step_desc, step_target_kind, step_target_val, step_action, step_corr, step_timeout, step_deps, step_params, step_rb, step_crit, step_succ, step_fail, step_out, step_ext
		step_id = ""; step_desc = ""; step_target_kind = ""; step_target_val = ""
		step_action = ""; step_corr = ""; step_timeout = ""; step_deps = ""
		step_params = ""; step_rb = ""; step_crit = ""; step_succ = ""
		step_fail = ""; step_out = ""; step_ext = ""
	}
	# @function flush_wf
	# @description Emits the currently accumulated workflow metadata line.
	function flush_wf() {
		flush_step()
		if (wf_id == "") return
		printf "WF:%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", wf_id, wf_summary, wf_desc, wf_deps, wf_inputs, wf_params, wf_succ, wf_fail, wf_out, wf_ext
		wf_id = ""; wf_summary = ""; wf_desc = ""; wf_deps = ""; wf_inputs = ""
		wf_params = ""; wf_succ = ""; wf_fail = ""; wf_out = ""; wf_ext = ""
	}
	BEGIN {
		arazzo_ver = "1.1.0"; self_uri = ""; info_title = "Arazzo Workflow Specification"
		info_summary = ""; info_desc = ""; info_ver = "0.1.0"; info_ext = "{}"
		root_ext = "{}"; comps_json = "{}"
		wf_id = ""; step_id = ""
		heur_wf = ""; heur_step_idx = 0
	}
	/^# @arazzo / { arazzo_ver = substr($0, 11); next }
	/^# @self / { self_uri = substr($0, 9); next }
	/^# @info_title / { info_title = substr($0, 15); next }
	/^# @info_summary / { info_summary = substr($0, 17); next }
	/^# @info_description / { info_desc = substr($0, 21); next }
	/^# @info_version / { info_ver = substr($0, 17); next }
	/^# @info_extensions / { info_ext = substr($0, 20); next }
	/^# @arazzo_extensions / { root_ext = substr($0, 22); next }
	/^# @sourceDescription / {
		sd_name = $3; sd_type = $4; sd_url = $5
		sd_prefix_len = length("# @sourceDescription ") + length(sd_name) + 1 + length(sd_type) + 1 + length(sd_url)
		sd_ext = substr($0, sd_prefix_len + 2)
		if (sd_ext == "") sd_ext = "{}"
		printf "SD:%s\t%s\t%s\t%s\n", sd_name, sd_type, sd_url, sd_ext
		next
	}
	/^# @arazzo_components_json / { comps_json = substr($0, 27); next }
	/^# @workflow / {
		flush_wf()
		wf_id = $3
		heur_wf = ""
		next
	}
	/^# @summary / { if (wf_id != "") wf_summary = substr($0, 12); next }
	/^# @description / { if (wf_id != "" && step_id == "") wf_desc = substr($0, 16); next }
	/^# @dependsOn / { if (wf_id != "") wf_deps = substr($0, 14); next }
	/^# @inputs_schema / { if (wf_id != "") wf_inputs = substr($0, 18); next }
	/^# @workflow_parameters / { if (wf_id != "") wf_params = substr($0, 24); next }
	/^# @workflow_success_actions / { if (wf_id != "") wf_succ = substr($0, 29); next }
	/^# @workflow_failure_actions / { if (wf_id != "") wf_fail = substr($0, 29); next }
	/^# @workflow_outputs / { if (wf_id != "") wf_out = substr($0, 21); next }
	/^# @workflow_extensions / { if (wf_id != "") wf_ext = substr($0, 24); next }

	/^[ \t]*# @step / {
		flush_step()
		sub(/^[ \t]*# @step /, "", $0)
		step_id = $1
		next
	}
	/^[ \t]*# @step_description / {
		sub(/^[ \t]*# @step_description /, "", $0)
		step_desc = $0
		next
	}
	/^[ \t]*# @step_target / {
		sub(/^[ \t]*# @step_target /, "", $0)
		step_target_kind = $1
		step_target_val = substr($0, length($1) + 2)
		next
	}
	/^[ \t]*# @step_action / {
		sub(/^[ \t]*# @step_action /, "", $0)
		step_action = $0
		next
	}
	/^[ \t]*# @step_correlation_id / {
		sub(/^[ \t]*# @step_correlation_id /, "", $0)
		step_corr = $0
		next
	}
	/^[ \t]*# @step_timeout / {
		sub(/^[ \t]*# @step_timeout /, "", $0)
		step_timeout = $0
		next
	}
	/^[ \t]*# @step_depends_on / {
		sub(/^[ \t]*# @step_depends_on /, "", $0)
		step_deps = $0
		next
	}
	/^[ \t]*# @step_parameters / {
		sub(/^[ \t]*# @step_parameters /, "", $0)
		step_params = $0
		next
	}
	/^[ \t]*# @step_request_body / {
		sub(/^[ \t]*# @step_request_body /, "", $0)
		step_rb = $0
		next
	}
	/^[ \t]*# @step_success_criteria / {
		sub(/^[ \t]*# @step_success_criteria /, "", $0)
		step_crit = $0
		next
	}
	/^[ \t]*# @step_on_success / {
		sub(/^[ \t]*# @step_on_success /, "", $0)
		step_succ = $0
		next
	}
	/^[ \t]*# @step_on_failure / {
		sub(/^[ \t]*# @step_on_failure /, "", $0)
		step_fail = $0
		next
	}
	/^[ \t]*# @step_outputs / {
		sub(/^[ \t]*# @step_outputs /, "", $0)
		step_out = $0
		next
	}
	/^[ \t]*# @step_extensions / {
		sub(/^[ \t]*# @step_extensions /, "", $0)
		step_ext = $0
		next
	}

	/^[a-zA-Z_][a-zA-Z0-9_]*\(\)[ \t]*\{/ {
		fn = $1
		sub(/\(\).*$/, "", fn)
		if (wf_id == "" && fn !~ /^validate_/ && fn !~ /^arazzo_/ && fn !~ /^_/ && fn !~ /^curl$/ && fn !~ /^mcp_/) {
			heur_wf = fn
			sub(/^workflow_/, "", heur_wf)
			heur_step_idx = 0
			printf "HEUR_WF:%s\n", heur_wf
		}
	}
	/^[ \t]*[a-zA-Z0-9_]+=\$\([a-zA-Z_][a-zA-Z0-9_]*/ {
		if (heur_wf != "" && wf_id == "") {
			line = $0
			sub(/^[ \t]*[a-zA-Z0-9_]+=\$\(/, "", line)
			sub(/\).*$/, "", line)
			split(line, call_parts, " ")
			called_op = call_parts[1]
			if (called_op !~ /^(printf|echo|jq|awk|sed|tr|cut|head|tail|cat|dirname|basename|command|_urlencode|arazzo_)/) {
				heur_step_idx++
				printf "HEUR_STEP:%s\tstep_%d\t%s\n", heur_wf, heur_step_idx, called_op
			}
		}
	}
	/^\}/ {
		if (wf_id != "") {
			flush_wf()
		}
		heur_wf = ""
	}
	END {
		flush_wf()
		printf "META:%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", arazzo_ver, self_uri, info_title, info_summary, info_desc, info_ver, info_ext, root_ext, comps_json
	}
	' <"${file_path}")

	meta_json=$(printf '%s\n' "${extracted_lines}" | awk '/^META:/ { print substr($0, 6) }' | jq -R '
		split("\t") |
		{
			arazzo: (if .[0] != "" then .[0] else "1.1.0" end),
			arazzoSelf: (if .[1] != "" then .[1] else null end),
			arazzoInfo: (
				{
					title: (if .[2] != "" then .[2] else "Arazzo Workflow Specification" end),
					summary: (if .[3] != "" then .[3] else null end),
					description: (if .[4] != "" then .[4] else null end),
					version: (if .[5] != "" then .[5] else "0.1.0" end)
				} + ((.[6] // "{}") | fromjson? // {}) | with_entries(select(.value != null))
			),
			arazzoExtensions: ((.[7] // "{}") | fromjson? // {}),
			arazzoComponents: ((.[8] // "{}") | fromjson? // {})
		}
	')

	sds_json=$(printf '%s\n' "${extracted_lines}" | awk '/^SD:/ { print substr($0, 4) }' | jq -R -s '
		split("\n") | map(select(length > 0) | split("\t") | (
			{
				name: .[0],
				type: .[1],
				url: .[2]
			} + ((.[3] // "{}") | fromjson? // {})
		))
	')

	steps_json=$(printf '%s\n' "${extracted_lines}" | awk '/^STEP:/ { print substr($0, 6) }' | jq -R -s '
		split("\n") | map(select(length > 0) | split("\t") | {
			wfId: .[0],
			step: (
				{
					stepId: .[1],
					description: (if .[2] != "" then .[2] else null end),
					(if .[3] != "" then .[3] else "operationId" end): (if .[4] != "" then .[4] else .[1] end),
					action: (if .[5] != "" then .[5] else null end),
					correlationId: (if .[6] != "" then .[6] else null end),
					timeout: (if .[7] != "" then (.[7] | tonumber? // null) else null end),
					dependsOn: (if .[8] != "" then (.[8] | split(",")) else null end),
					parameters: (if .[9] != "" then (.[9] | fromjson? // null) else null end),
					requestBody: (if .[10] != "" then (.[10] | fromjson? // null) else null end),
					successCriteria: (if .[11] != "" then (.[11] | fromjson? // null) else null end),
					onSuccess: (if .[12] != "" then (.[12] | fromjson? // null) else null end),
					onFailure: (if .[13] != "" then (.[13] | fromjson? // null) else null end),
					outputs: (if .[14] != "" then (.[14] | fromjson? // null) else null end)
				} + ((.[15] // "{}") | fromjson? // {}) | with_entries(select(.value != null))
			)
		})
	')

	wfs_json=$(printf '%s\n' "${extracted_lines}" | awk '/^WF:/ { print substr($0, 4) }' | jq -R -s --argjson steps "${steps_json}" '
		split("\n") | map(select(length > 0) | split("\t") | . as $row |
			($row[0]) as $wid |
			(
				{
					workflowId: $wid,
					summary: (if $row[1] != "" then $row[1] else null end),
					description: (if $row[2] != "" then $row[2] else null end),
					dependsOn: (if $row[3] != "" then ($row[3] | split(",")) else null end),
					inputs: (if $row[4] != "" then ($row[4] | fromjson? // null) else null end),
					parameters: (if $row[5] != "" then ($row[5] | fromjson? // null) else null end),
					steps: ([ $steps[] | select(.wfId == $wid) | .step ]),
					successActions: (if $row[6] != "" then ($row[6] | fromjson? // null) else null end),
					failureActions: (if $row[7] != "" then ($row[7] | fromjson? // null) else null end),
					outputs: (if $row[8] != "" then ($row[8] | fromjson? // null) else null end)
				} + (($row[9] // "{}") | fromjson? // {}) | with_entries(select(.value != null))
			)
		)
	')

	if [ "${wfs_json}" = "[]" ]; then
		heur_steps=$(printf '%s\n' "${extracted_lines}" | awk '/^HEUR_STEP:/ { print substr($0, 11) }' | jq -R -s '
			split("\n") | map(select(length > 0) | split("\t") | {
				wfId: .[0],
				step: {
					stepId: .[1],
					operationId: .[2],
					successCriteria: [{"condition": "$statusCode == 200"}]
				}
			})
		')
		wfs_json=$(printf '%s\n' "${extracted_lines}" | awk '/^HEUR_WF:/ { print substr($0, 9) }' | jq -R -s --argjson hsteps "${heur_steps}" '
			split("\n") | map(select(length > 0)) | unique | map(
				. as $wid |
				{
					workflowId: $wid,
					summary: ("Extracted workflow " + $wid),
					steps: ([ $hsteps[] | select(.wfId == $wid) | .step ])
				} | select((.steps | length) > 0)
			)
		')
	fi

	jq --argjson meta "${meta_json}" --argjson sds "${sds_json}" --argjson wfs "${wfs_json}" '
		.arazzo = $meta.arazzo |
		(if $meta.arazzoSelf != null then .arazzoSelf = $meta.arazzoSelf else . end) |
		.arazzoInfo = $meta.arazzoInfo |
		.arazzoExtensions = $meta.arazzoExtensions |
		(if ($meta.arazzoComponents | length) > 0 then .arazzoComponents = $meta.arazzoComponents else . end) |
		.sourceDescriptions = (if ($sds | length) > 0 then $sds else (.sourceDescriptions // [{"name": "default", "url": "./openapi.json", "type": "openapi"}]) end) |
		.workflows = $wfs
	' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
