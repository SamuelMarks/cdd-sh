#!/bin/sh
# @file src/docsjson/emit.sh
# @description Emits JSON documentation with structured shell code objects and realistic SDK primitive calls from an OpenAPI or Arazzo specification.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_to_docs_json outputs the AST or specification as a documentation JSON format.
# @param $@: CLI flags (-i/-f/--input, -o/--output, --no-imports, --no-wrapping)
handle_to_docs_json() {
	input_file="${CDD_INPUT:-}"
	output_file="${CDD_OUTPUT:-}"
	no_imports="false"
	no_wrapping="false"
	if [ "${CDD_NO_IMPORTS:-0}" = "1" ]; then no_imports="true"; fi
	if [ "${CDD_NO_WRAPPING:-0}" = "1" ]; then no_wrapping="true"; fi

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-i | -f | --input)
			input_file="$2"
			shift 2
			;;
		-o | --output)
			output_file="$2"
			shift 2
			;;
		--no-imports)
			no_imports="true"
			shift 1
			;;
		--no-wrapping)
			no_wrapping="true"
			shift 1
			;;
		*)
			echo "Unknown option $1" >&2
			exit 1
			;;
		esac
	done

	if [ -z "$input_file" ]; then
		echo "Error: -i/--input is required" >&2
		exit 1
	fi
	if [ ! -f "$input_file" ]; then
		echo "Error: Input file $input_file not found" >&2
		exit 1
	fi

	jq_filter='
    include "openapi";
    include "arazzo";

    def sq: [39] | implode;
    def nl: [10] | implode;

    def resolve_schema($s; $root):
      if ($s | type) == "object" and ($s."$ref" | type) == "string" then
        if ($s."$ref" | startswith("#/components/schemas/")) then
          ($root.components.schemas[$s."$ref" | sub("^#/components/schemas/"; "")] // $s)
        elif ($s."$ref" | startswith("#/definitions/")) then
          ($root.definitions[$s."$ref" | sub("^#/definitions/"; "")] // $s)
        elif ($s."$ref" | startswith("$components.inputs.")) then
          (($root.arazzoComponents.inputs // $root.components.inputs // {})[$s."$ref" | ltrimstr("$components.inputs.")] // $s)
        else
          $s
        end
      else
        ($s // {})
      end;

    def extract_prop_sample($prop; $propName; $root):
      resolve_schema($prop; $root) as $p |
      if ($p | type) != "object" then
        $propName
      elif $p.example != null then
        $p.example
      elif ($p.examples | type) == "array" and ($p.examples | length) > 0 then
        $p.examples[0]
      elif $p.default != null then
        $p.default
      elif ($p.enum | type) == "array" and ($p.enum | length) > 0 then
        $p.enum[0]
      elif $p.format == "date-time" then
        "2024-01-01T00:00:00Z"
      elif $p.format == "date" then
        "2024-01-01"
      elif $p.format == "uuid" then
        "00000000-0000-0000-0000-000000000000"
      elif $p.format == "email" then
        "user@example.com"
      elif $p.format == "uri" or $p.format == "url" then
        "https://example.com"
      elif $p.type == "integer" or $p.type == "number" then
        ($p.minimum // 1)
      elif $p.type == "boolean" then
        true
      elif $p.type == "array" then
        if $p.items then [extract_prop_sample($p.items; $propName; $root)] else [] end
      elif $p.type == "object" or ($p.properties | type) == "object" then
        (($p.properties // {}) | with_entries(.key as $k | .value = extract_prop_sample(.value; $k; $root)))
      else
        $propName
      end;

    def extract_schema_sample($schema; $root):
      resolve_schema($schema; $root) as $s |
      if ($s | type) != "object" then
        {}
      elif $s.example != null then
        $s.example
      elif ($s.examples | type) == "array" and ($s.examples | length) > 0 then
        $s.examples[0]
      elif $s.default != null then
        $s.default
      elif ($s.enum | type) == "array" and ($s.enum | length) > 0 then
        $s.enum[0]
      elif $s.type == "object" or ($s.properties | type) == "object" then
        (($s.properties // {}) | with_entries(.key as $k | .value = extract_prop_sample(.value; $k; $root)))
      elif $s.type == "array" then
        if $s.items then [extract_schema_sample($s.items; $root)] else [] end
      elif $s.type == "integer" or $s.type == "number" then
        ($s.minimum // 1)
      elif $s.type == "boolean" then
        true
      else
        {}
      end;

    def format_shell_arg($val):
      if ($val | type) == "object" or ($val | type) == "array" then
        " " + sq + ($val | tojson) + sq
      else
        " " + (($val | tostring) | tojson)
      end;

    def extract_param_arg($param; $root):
      (if ($param."$ref" | type) == "string" and $root.components and $root.components.parameters then
        ($root.components.parameters[$param."$ref" | sub("^#/components/parameters/"; "")] // $param)
      else
        $param
      end) as $p |
      if $p.in == "body" and $p.schema then
        format_shell_arg(extract_schema_sample($p.schema; $root))
      else
        resolve_schema($p.schema // {}; $root) as $s |
        (
          if $p.example != null then $p.example
          elif ($p.examples | type) == "object" and ($p.examples | length) > 0 then
            ($p.examples | to_entries[0].value | if (type == "object") and has("value") then .value else . end)
          elif $p.value != null then $p.value
          elif $p.default != null then $p.default
          elif $s.example != null then $s.example
          elif ($s.examples | type) == "array" and ($s.examples | length) > 0 then $s.examples[0]
          elif $s.default != null then $s.default
          elif ($s.enum | type) == "array" and ($s.enum | length) > 0 then $s.enum[0]
          elif $s.format == "date-time" then "2024-01-01T00:00:00Z"
          elif $s.format == "date" then "2024-01-01"
          elif $s.format == "uuid" then "00000000-0000-0000-0000-000000000000"
          elif $s.format == "email" then "user@example.com"
          elif $s.format == "uri" or $s.format == "url" then "https://example.com"
          else ($p.name // "param")
          end
        ) as $val |
        format_shell_arg($val)
      end;

    def extract_request_body_arg($rb; $root):
      if $rb == null then
        ""
      else
        (if ($rb."$ref" | type) == "string" and $root.components and $root.components.requestBodies then
          ($root.components.requestBodies[$rb."$ref" | sub("^#/components/requestBodies/"; "")] // $rb)
        else
          $rb
        end) as $resolvedRb |
        (
          if ($resolvedRb.content | type) == "object" and ($resolvedRb.content | length) > 0 then
            ($resolvedRb.content["application/json"] // ($resolvedRb.content | to_entries[0].value) // {})
          else
            {}
          end
        ) as $media |
        (
          if $media.example != null then
            $media.example
          elif ($media.examples | type) == "object" and ($media.examples | length) > 0 then
            ($media.examples | to_entries[0].value | if (type == "object") and has("value") then .value else . end)
          elif $media.schema != null then
            extract_schema_sample($media.schema; $root)
          else
            {}
          end
        ) as $bodyVal |
        format_shell_arg($bodyVal)
      end;

    def build_code_obj($imports_str; $snippet_str; $no_imports; $no_wrapping):
      (if $no_imports == "false" then $imports_str else "" end) as $imp |
      (if $no_wrapping == "false" then "main() {" else "" end) as $wstart |
      (if $no_wrapping == "false" then (["}", "", "main " + ("$@" | tojson)] | join(nl)) else "" end) as $wend |
      {
        "imports": $imp,
        "wrapper_start": $wstart,
        "snippet": $snippet_str,
        "wrapper_end": $wend,
        "code": (
          ((if $imp != "" then [$imp, ""] else [] end) + ([ $wstart, $snippet_str, $wend ] | map(select(. != "")))) | join(nl)
        )
      };

    def build_op_entries($itemObj; $itemKey; $isWebhook; $root; $no_imports; $no_wrapping):
      (if ($itemObj."$ref" | type) == "string" and $root.components and $root.components.pathItems then
        ($root.components.pathItems[$itemObj."$ref" | sub("^#/components/pathItems/"; "")] // $itemObj)
      else
        $itemObj
      end) as $resolvedItem |
      ($resolvedItem.parameters // []) as $itemParams |
      (
        ($resolvedItem | to_entries | map(select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers" and .key != "$ref" and .key != "additionalOperations"))) +
        (if ($resolvedItem.additionalOperations | type) == "object" then ($resolvedItem.additionalOperations | to_entries) else [] end)
      ) | map(
        .key as $method |
        .value |
        (if $isWebhook then
          (if .operationId then .operationId else "handle_webhook_" + ($itemKey | gsub("-"; "_") | gsub("[^a-zA-Z0-9_]"; "_")) end)
        else
          get_docs_op_id($method; $itemKey)
        end) as $opId |
        (((.parameters // []) + $itemParams) | map(extract_param_arg(.; $root)) | join("")) as $paramArgs |
        extract_request_body_arg(.requestBody; $root) as $bodyArg |
        ("  " + $opId + $paramArgs + $bodyArg) as $snippet |
        {
          "key": ($method | ascii_downcase),
          "value": build_code_obj(". ./routes.sh"; $snippet; $no_imports; $no_wrapping)
        }
      ) | from_entries;

    $spec[0] as $root |
    {
      "endpoints": (
        if $root.paths then
          $root.paths | to_entries | map(
            .key as $path |
            {
              "key": $path,
              "value": build_op_entries(.value; $path; false; $root; $no_imports; $no_wrapping)
            }
          ) | from_entries
        else
          {}
        end
      )
    } + (
      if $root.webhooks and ($root.webhooks | length) > 0 then
        {
          "webhooks": (
            $root.webhooks | to_entries | map(
              .key as $whName |
              {
                "key": $whName,
                "value": build_op_entries(.value; $whName; true; $root; $no_imports; $no_wrapping)
              }
            ) | from_entries
          )
        }
      else
        {}
      end
    ) + (
      if $root.workflows and ($root.workflows | length) > 0 then
        {
          "workflows": (
            $root.workflows | map(
              .workflowId as $wfId |
              get_workflow_fn_name($wfId) as $fnName |
              (
                if .inputs then
                  resolve_reusable_object($root; .inputs) as $resolvedInputs |
                  extract_schema_sample($resolvedInputs; $root)
                else
                  {}
                end
              ) as $wfInputs |
              ("  " + $fnName + format_shell_arg($wfInputs)) as $snippet |
              {
                "key": $wfId,
                "value": build_code_obj(". ./workflows.sh"; $snippet; $no_imports; $no_wrapping)
              }
            ) | from_entries
          )
        }
      else
        {}
      end
    )
  '
	if [ -n "$output_file" ]; then
		if [ -d "$output_file" ]; then
			output_file="${output_file%/}/docs.json"
		fi
		jq -n -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" --slurpfile spec "$input_file" --arg no_imports "$no_imports" --arg no_wrapping "$no_wrapping" "$jq_filter" >"$output_file"
	else
		jq -n -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" --slurpfile spec "$input_file" --arg no_imports "$no_imports" --arg no_wrapping "$no_wrapping" "$jq_filter"
	fi
}

# handle_emit_docsjson emits the documentation JSON from the current AST file.
# @param $1: file_path - The destination path for the documentation JSON.
handle_emit_docsjson() {
	file_path="${1:-emitted_docsjson.json}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi
	handle_to_docs_json -i "${ast}" -o "${file_path}"
}
