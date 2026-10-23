# @file lib/_common/arazzo.jq
# @description Shared JQ helper functions for Arazzo 1.0.1 / 1.1.0 AST normalization, validation, expression parsing, and code generation.
include "openapi";
include "arazzo_expr";

# get_workflow_fn_name($wfId) converts an Arazzo workflowId into an idiomatic POSIX shell function name.
# @param $wfId - The workflow identifier string.
# @return The sanitized shell function name.
def get_workflow_fn_name($wfId):
  "workflow_" + ($wfId | to_snake_case | gsub("[^a-zA-Z0-9_]"; "_"));

# get_step_fn_name($wfId; $stepId) converts a workflowId and stepId into an idiomatic POSIX shell step function name.
# @param $wfId - The workflow identifier string.
# @param $stepId - The step identifier string.
# @return The sanitized shell step function name.
def get_step_fn_name($wfId; $stepId):
  "step_" + ($wfId | to_snake_case | gsub("[^a-zA-Z0-9_]"; "_")) + "_" + ($stepId | to_snake_case | gsub("[^a-zA-Z0-9_]"; "_"));

# resolve_reusable_object($root; $obj) dereferences Arazzo Reusable Objects ($components.parameters.*, $components.successActions.*, $components.failureActions.*, $components.inputs.*) while applying any value override.
# @param $root - The root AST object.
# @param $obj - The object or Reusable Object to resolve.
# @return The resolved object.
def resolve_reusable_object($root; $obj):
  if ($obj | type) == "object" and ($obj | has("reference")) and ($obj.reference | type) == "string" then
    ($root.arazzoComponents // $root.components // {}) as $comps |
    if ($obj.reference | startswith("$components.parameters.")) then
      ($obj.reference | ltrimstr("$components.parameters.")) as $pname |
      (($comps.parameters[$pname] // {}) + (if $obj | has("value") then {value: $obj.value} else {} end) + {"x-reusable-reference": $obj.reference})
    elif ($obj.reference | startswith("$components.successActions.")) then
      ($obj.reference | ltrimstr("$components.successActions.")) as $sname |
      (($comps.successActions[$sname] // {}) + {"x-reusable-reference": $obj.reference})
    elif ($obj.reference | startswith("$components.failureActions.")) then
      ($obj.reference | ltrimstr("$components.failureActions.")) as $fname |
      (($comps.failureActions[$fname] // {}) + {"x-reusable-reference": $obj.reference})
    elif ($obj.reference | startswith("$components.inputs.")) then
      ($obj.reference | ltrimstr("$components.inputs.")) as $iname |
      (($comps.inputs[$iname] // {}) + {"x-reusable-reference": $obj.reference})
    else
      $obj
    end
  else
    $obj
  end;

# resolve_operation_path($root; $opPath) resolves an Arazzo operationPath JSON Pointer (optionally prefixed with a sourceDescription expression) into a target operationId.
# @param $root - The root AST object.
# @param $opPath - The operationPath JSON Pointer expression.
# @return The resolved operationId string.
def resolve_operation_path($root; $opPath):
  if ($opPath | type) != "string" or $opPath == "" then
    ""
  else
    ($opPath | if contains("#/paths/") then split("#/paths/")[1] else ltrimstr("#/paths/") end) as $tail |
    ($tail | split("/")) as $parts |
    if ($parts | length) >= 2 then
      ("/" + (($parts[0] | gsub("~1"; "/") | gsub("~0"; "~")) | ltrimstr("/"))) as $rawPath |
      ($parts[1] | ascii_downcase) as $method |
      (
        if $root.paths and $root.paths[$rawPath] and $root.paths[$rawPath][$method] then
          ($root.paths[$rawPath][$method] | get_raw_op_id($method; $rawPath))
        elif $root.x_resolved_sources then
          (
            [ $root.x_resolved_sources | to_entries[] | select(.value.paths and .value.paths[$rawPath] and .value.paths[$rawPath][$method]) | (.value.paths[$rawPath][$method] | get_raw_op_id($method; $rawPath)) ][0]
            // "\($method | ascii_upcase)_\($rawPath | gsub("/"; "_") | gsub("[{}]"; ""))"
          )
        else
          "\($method | ascii_upcase)_\($rawPath | gsub("/"; "_") | gsub("[{}]"; ""))"
        end
      )
    else
      ($opPath | gsub("[^a-zA-Z0-9_]"; "_"))
    end
  end;

# resolve_channel_path($root; $channelPath; $action; $correlationId) resolves an Arazzo 1.1.0 AsyncAPI channelPath and action into a shell helper function name.
# @param $root - The root AST object.
# @param $channelPath - The AsyncAPI channel path string.
# @param $action - The channel action (send or receive).
# @param $correlationId - Optional correlation identifier.
# @return The resolved shell helper function name.
def resolve_channel_path($root; $channelPath; $action; $correlationId):
  "_async_" + (($action // "send") | ascii_downcase) + "_" + (($channelPath // "channel") | gsub("[^a-zA-Z0-9_]"; "_") | sub("^_+"; ""));

# normalize_payload_replacement normalizes an Arazzo 1.1.0 Payload Replacement Object, preserving or inferring targetSelectorType.
# @param none
# @return The normalized Payload Replacement Object.
def normalize_payload_replacement:
  if (type == "object") and has("target") then
    if has("targetSelectorType") and .targetSelectorType != null then
      .
    else
      . + {
        targetSelectorType: (
          if (.target | startswith("$")) then "jsonpath"
          elif (.target | contains("@")) or (.target | endswith("/text()")) then "xpath"
          else "jsonpointer"
          end
        )
      }
    end
  else
    .
  end;

# normalize_arazzo_root normalizes an Arazzo 1.0.x / 1.1.0 document for merging into the unified CDD AST.
# @param none
# @return The normalized Arazzo AST fragment object.
def normalize_arazzo_root:
  . as $doc |
  {
    arazzo: ($doc.arazzo // "1.1.0"),
    arazzoSelf: ($doc."$self" // null),
    arazzoInfo: (
      ($doc.info // {}) | {
        title: (.title // "Arazzo Workflow Specification"),
        version: (.version // "0.1.0"),
        summary: (.summary // null),
        description: (.description // null)
      } + (with_entries(select(.key | startswith("x-")))) | with_entries(select(.value != null))
    ),
    sourceDescriptions: (
      if ($doc.sourceDescriptions | type) == "array" and ($doc.sourceDescriptions | length) > 0 then
        $doc.sourceDescriptions
      else
        [{"name": "default", "url": "./openapi.json", "type": "openapi"}]
      end
    ),
    workflows: (
      ($doc.workflows // []) | map(
        if (.steps | type) == "array" then
          .steps |= map(
            if (.requestBody | type) == "object" and (.requestBody.replacements | type) == "array" then
              .requestBody.replacements |= map(normalize_payload_replacement)
            else . end
          )
        else . end
      )
    ),
    arazzoComponents: ($doc.components // {}),
    arazzoExtensions: ($doc | with_entries(select(.key | startswith("x-"))))
  } | with_entries(select(.value != null));

# extract_arazzo_spec reconstructs a clean, standard-compliant Arazzo 1.1.0 document from the unified CDD AST.
# @param none
# @return The extracted Arazzo 1.1.0 specification object.
def extract_arazzo_spec:
  . as $root |
  (
    {
      arazzo: ($root.arazzo // "1.1.0"),
      "$self": ($root.arazzoSelf // $root."$self" // null),
      info: (
        ($root.arazzoInfo // $root.info // {}) |
        {
          title: (.title // "Arazzo Workflow Specification"),
          summary: (.summary // null),
          description: (.description // null),
          version: (.version // "0.1.0")
        } + (with_entries(select(.key | startswith("x-")))) | with_entries(select(.value != null))
      ),
      sourceDescriptions: (
        if ($root.sourceDescriptions | type) == "array" and ($root.sourceDescriptions | length) > 0 then
          $root.sourceDescriptions
        else
          [{"name": "default", "url": "./openapi.json", "type": "openapi"}]
        end
      ),
      workflows: (
        ($root.workflows // []) | map(
          if (.steps | type) == "array" then
            .steps |= map(
              if (.requestBody | type) == "object" and (.requestBody.replacements | type) == "array" then
                .requestBody.replacements |= map(normalize_payload_replacement)
              else . end
            )
          else . end
        )
      ),
      components: (
        ($root.arazzoComponents // (
          if $root.components then
            ($root.components | with_entries(select(.key == "inputs" or .key == "parameters" or .key == "successActions" or .key == "failureActions" or (.key | startswith("x-")))))
          else {} end
        )) | if (. | length) > 0 then . else null end
      )
    } + ($root.arazzoExtensions // {})
  ) | with_entries(select(.value != null));

# emit_mcp_workflow_tools builds MCP tool definitions for all Arazzo workflows in the AST.
# @param none
# @return JSON array of MCP Tool Objects for workflows.
def emit_mcp_workflow_tools:
  if .workflows and (.workflows | length) > 0 then
    [
      .workflows[] |
      {
        name: ("workflow_" + .workflowId),
        description: (.summary // .description // "Execute Arazzo workflow \(.workflowId)"),
        inputSchema: (
          if .inputs and (.inputs | type) == "object" then
            {
              type: (.inputs.type // "object"),
              properties: (.inputs.properties // {}),
              required: (.inputs.required // [])
            }
          else
            {
              type: "object",
              properties: {},
              required: []
            }
          end
        )
      }
    ]
  else
    []
  end;
