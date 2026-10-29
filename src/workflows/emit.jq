# @file src/workflows/emit.jq
# @description Emits POSIX shell workflow orchestrator functions and JSON Schema input validators from the Arazzo AST.
include "arazzo";

. as $root |
(extract_arazzo_spec) as $arz |
"# @arazzo \($arz.arazzo // "1.1.0")\n" +
(if $arz."$self" then "# @self \($arz."$self")\n" else "" end) +
"# @info_title \($arz.info.title // "Arazzo Workflows")\n" +
(if $arz.info.summary then "# @info_summary \($arz.info.summary)\n" else "" end) +
(if $arz.info.description then "# @info_description \($arz.info.description | gsub("\n"; " "))\n" else "" end) +
"# @info_version \($arz.info.version // "0.0.4")\n" +
(
  (($arz.info // {}) | with_entries(select(.key | startswith("x-")))) as $infoExt |
  if ($infoExt | length) > 0 then "# @info_extensions \($infoExt | tojson)\n" else "" end
) +
(
  (($arz // {}) | with_entries(select(.key | startswith("x-")))) as $rootExt |
  if ($rootExt | length) > 0 then "# @arazzo_extensions \($rootExt | tojson)\n" else "" end
) +
(
  [
    ($arz.sourceDescriptions // [])[] |
    "# @sourceDescription \(.name) \(.type // "openapi") \(.url) \((with_entries(select(.key | startswith("x-")))) | tojson)"
  ] | join("\n")
) + "\n" +
(if $arz.components then "# @arazzo_components_json \($arz.components | tojson)\n" else "" end) +
"\n" +
"ARAZZO_SOURCE_DESCRIPTIONS_JSON=\($arz.sourceDescriptions // [] | tojson | @sh)\n" +
"ARAZZO_COMPONENTS_JSON=\($arz.components // {} | tojson | @sh)\n" +
"ARAZZO_SELF_URI=\($arz."$self" // "" | @sh)\n\n" +
(
  [
    ($arz.workflows // [])[] |
    . as $wf |
    ($wf.workflowId) as $wfId |
    get_workflow_fn_name($wfId) as $fnName |
    (
      if $wf.inputs then
        resolve_reusable_object($root; $wf.inputs)
      else
        null
      end
    ) as $resolvedInputs |

    # Input validation function
    "# validate_\($fnName)_inputs validates input JSON against the workflow JSON Schema.\n" +
    "# @param $1: inputs_json - JSON object of workflow inputs.\n" +
    "validate_\($fnName)_inputs() {\n" +
    "  _wf_inp=\"${1:-}\"\n" +
    "  if [ -z \"${_wf_inp}\" ]; then _wf_inp=\"{}\"; fi\n" +
    "  if ! printf '%s' \"${_wf_inp}\" | jq -e 'type == \"object\"' >/dev/null 2>&1; then\n" +
    "    echo \"Validation error: workflow \($wfId) inputs must be a JSON object\" >&2\n" +
    "    return 1\n" +
    "  fi\n" +
    (
      if $resolvedInputs and ($resolvedInputs.required | type) == "array" and ($resolvedInputs.required | length) > 0 then
        [
          $resolvedInputs.required[] |
          "  if ! printf '%s' \"${_wf_inp}\" | jq -e --arg k \(. | @sh) 'has($k) and .[$k] != null' >/dev/null 2>&1; then\n" +
          "    echo \"Validation error: missing required workflow input '\(.)'\" >&2\n" +
          "    return 1\n" +
          "  fi"
        ] | join("\n") + "\n"
      else "" end
    ) +
    "  return 0\n" +
    "}\n\n" +

    # Workflow docblock annotations
    "# @workflow \($wfId)\n" +
    (if $wf.summary then "# @summary \($wf.summary | gsub("\n"; " "))\n" else "" end) +
    (if $wf.description then "# @description \($wf.description | gsub("\n"; " "))\n" else "# @description Executes the \($wfId) Arazzo workflow.\n" end) +
    (if $wf.dependsOn and ($wf.dependsOn | length) > 0 then "# @dependsOn \($wf.dependsOn | join(","))\n" else "" end) +
    (if $wf.inputs then "# @inputs_schema \($wf.inputs | tojson)\n" else "" end) +
    (if $wf.parameters then "# @workflow_parameters \($wf.parameters | tojson)\n" else "" end) +
    (if $wf.successActions then "# @workflow_success_actions \($wf.successActions | tojson)\n" else "" end) +
    (if $wf.failureActions then "# @workflow_failure_actions \($wf.failureActions | tojson)\n" else "" end) +
    (if $wf.outputs then "# @workflow_outputs \($wf.outputs | tojson)\n" else "" end) +
    (
      ($wf | with_entries(select(.key | startswith("x-")))) as $wfExt |
      if ($wfExt | length) > 0 then "# @workflow_extensions \($wfExt | tojson)\n" else "" end
    ) +
    "# @param $1: inputs_json - JSON object of workflow inputs.\n" +
    "# @param $2: target_step - Optional single stepId to run.\n" +
    "\($fnName)() {\n" +
    "  _wf_inputs=\"${1:-}\"\n" +
    "  _target_only_step=\"${2:-}\"\n" +
    "  if [ -z \"${_wf_inputs}\" ]; then _wf_inputs=\"{}\"; fi\n" +
    "  if ! validate_\($fnName)_inputs \"${_wf_inputs}\"; then return 1; fi\n" +
    "  arazzo_init_state \"${_wf_inputs}\" \"${ARAZZO_SOURCE_DESCRIPTIONS_JSON}\" \"${ARAZZO_COMPONENTS_JSON}\" \"${ARAZZO_SELF_URI}\"\n" +
    (
      if $wf.dependsOn and ($wf.dependsOn | length) > 0 then
        [
          $wf.dependsOn[] |
          . as $depId |
          get_workflow_fn_name($depId) as $depFn |
          "  if ! printf '%s' \"${WORKFLOW_STATE_JSON}\" | jq -e --arg d \($depId | @sh) '.workflows[$d] != null' >/dev/null 2>&1; then\n" +
          "    \($depFn) \"${_wf_inputs}\" >/dev/null || return 1\n" +
          "    arazzo_init_state \"${_wf_inputs}\" \"${ARAZZO_SOURCE_DESCRIPTIONS_JSON}\" \"${ARAZZO_COMPONENTS_JSON}\" \"${ARAZZO_SELF_URI}\"\n" +
          "  fi"
        ] | join("\n") + "\n"
      else "" end
    ) +
    (
      if ($wf.steps | type) == "array" and ($wf.steps | length) > 0 then
        (($wf.steps | length) - 1) as $maxIdx |
        "  _current_step=\($wf.steps[0].stepId | @sh)\n" +
        "  if [ -n \"${_target_only_step}\" ]; then _current_step=\"${_target_only_step}\"; fi\n" +
        "  while [ -n \"${_current_step}\" ] && [ \"${_current_step}\" != \"__END__\" ]; do\n" +
        "    case \"${_current_step}\" in\n" +
        (
          [
            range(0; $wf.steps | length) |
            . as $idx |
            $wf.steps[$idx] as $step |
            ($step.stepId) as $stepId |
            (if $idx < $maxIdx then $wf.steps[$idx + 1].stepId else "__END__" end) as $nextStepId |
            (
              if $step.operationId then
                {kind: "operationId", raw: $step.operationId, fn: ($step.operationId | sub("^\\$sourceDescriptions\\.[a-zA-Z0-9_-]+\\."; ""))}
              elif $step.operationPath then
                {kind: "operationPath", raw: $step.operationPath, fn: resolve_operation_path($root; $step.operationPath)}
              elif $step.channelPath then
                {kind: "channelPath", raw: $step.channelPath, fn: resolve_channel_path($root; $step.channelPath; $step.action; $step.correlationId)}
              elif $step.workflowId then
                {kind: "workflowId", raw: $step.workflowId, fn: get_workflow_fn_name($step.workflowId | sub("^\\$sourceDescriptions\\.[a-zA-Z0-9_-]+\\.workflows\\."; ""))}
              else
                {kind: "operationId", raw: $stepId, fn: $stepId}
              end
            ) as $targetInfo |

            "      \($stepId | @sh))\n" +
            "        # @step \($stepId)\n" +
            (if $step.description then "        # @step_description \($step.description | gsub("\n"; " "))\n" else "" end) +
            "        # @step_target \($targetInfo.kind) \($targetInfo.raw)\n" +
            (if $step.action then "        # @step_action \($step.action)\n" else "" end) +
            (if $step.correlationId then "        # @step_correlation_id \($step.correlationId)\n" else "" end) +
            (if $step.timeout != null then "        # @step_timeout \($step.timeout)\n" else "" end) +
            (if $step.dependsOn and ($step.dependsOn | length) > 0 then "        # @step_depends_on \($step.dependsOn | join(","))\n" else "" end) +
            (if $step.parameters then "        # @step_parameters \($step.parameters | tojson)\n" else "" end) +
            (if $step.requestBody then "        # @step_request_body \($step.requestBody | tojson)\n" else "" end) +
            (if $step.successCriteria then "        # @step_success_criteria \($step.successCriteria | tojson)\n" else "" end) +
            (if $step.onSuccess then "        # @step_on_success \($step.onSuccess | tojson)\n" else "" end) +
            (if $step.onFailure then "        # @step_on_failure \($step.onFailure | tojson)\n" else "" end) +
            (if $step.outputs then "        # @step_outputs \($step.outputs | tojson)\n" else "" end) +
            (
              ($step | with_entries(select(.key | startswith("x-")))) as $stExt |
              if ($stExt | length) > 0 then "        # @step_extensions \($stExt | tojson)\n" else "" end
            ) +
            "        if [ \"${ARAZZO_VERBOSE:-0}\" = \"1\" ]; then echo \"[arazzo] workflow=\($wfId) step=\($stepId) target=\($targetInfo.fn)\" >&2; fi\n" +
            "        _step_params_json=\((($wf.parameters // []) + ($step.parameters // [])) | map(resolve_reusable_object($root; .)) | tojson | @sh)\n" +
            "        _step_rb_json=\(($step.requestBody // {}) | tojson | @sh)\n" +
            "        _step_criteria_json=\(($step.successCriteria // []) | tojson | @sh)\n" +
            "        _step_on_success_json=\(((($step.onSuccess // []) + ($wf.successActions // [])) | map(resolve_reusable_object($root; .))) | tojson | @sh)\n" +
            "        _step_on_failure_json=\(((($step.onFailure // []) + ($wf.failureActions // [])) | map(resolve_reusable_object($root; .))) | tojson | @sh)\n" +
            "        _step_outputs_json=\(($step.outputs // {}) | tojson | @sh)\n" +
            "        _next_default_step=\($nextStepId | @sh)\n" +
            "        if [ -n \"${_target_only_step}\" ]; then _next_default_step=\"__END__\"; fi\n" +
            "        arazzo_execute_step \($wfId | @sh) \($stepId | @sh) \($targetInfo.kind | @sh) \($targetInfo.fn | @sh) \"${_step_params_json}\" \"${_step_rb_json}\" \"${_step_criteria_json}\" \"${_step_on_success_json}\" \"${_step_on_failure_json}\" \"${_step_outputs_json}\" \"${_next_default_step}\" \($step.timeout // 0)\n" +
            "        _step_rc=$?\n" +
            "        if [ \"${_step_rc}\" -ne 0 ]; then return \"${_step_rc}\"; fi\n" +
            "        ;;"
          ] | join("\n")
        ) + "\n" +
        "      *)\n" +
        "        echo \"Error: unknown step ${_current_step} in workflow \($wfId)\" >&2\n" +
        "        return 1\n" +
        "        ;;\n" +
        "    esac\n" +
        "  done\n"
      else "" end
    ) +
    "  _wf_outputs_def=\(($wf.outputs // {}) | tojson | @sh)\n" +
    "  arazzo_finalize_workflow \($wfId | @sh) \"${_wf_outputs_def}\"\n" +
    "}\n"
  ] | join("\n")
)
