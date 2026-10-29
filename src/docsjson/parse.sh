#!/bin/sh
# @file src/docsjson/parse.sh
# @description Parses documentation JSON (docs.json) supporting both flat string values and structured code objects into the unified AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_docsjson parses a documentation JSON file into the AST.
# @param $1: file_path - The input documentation JSON file path (default: docs.json).
handle_parse_docsjson() {
	file_path="${1:-docs.json}"
	if [ ! -f "${file_path}" ]; then
		echo "Error: file not found at ${file_path}" >&2
		return 1
	fi
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		echo '{"openapi": "3.2.0", "info": {"title": "Parsed API", "version": "0.0.4"}}' >"${ast}"
	fi

	jq --slurpfile docs "${file_path}" '
    def dq: [34] | implode;
    def sq: [39] | implode;
    def nl: [10] | implode;

    def extract_call_line($v):
      (if ($v | type) == "object" then
        ($v.snippet // $v.code // "")
      elif ($v | type) == "string" then
        $v
      else
        ""
      end) |
      split(nl) |
      map(gsub("^[[:space:]]+|[[:space:]]+$"; "")) |
      map(select(
        length > 0 and
        (startswith("#") | not) and
        (startswith(". ") | not) and
        (startswith("source ") | not) and
        (. != "main() {") and
        (. != "}") and
        (startswith("main ") | not)
      )) |
      (.[0] // "");

    def parse_call_tokens($line):
      if ($line | length) == 0 then
        { opId: "", args: [] }
      else
        ($line | split(" ")[0]) as $opId |
        ($line | sub("^[^ ]+ *"; "")) as $rest |
        (sq + "[^" + sq + "]*" + sq + "|" + dq + "[^" + dq + "]*" + dq + "|[^[:space:]" + dq + sq + "]+") as $tokPat |
        [
          $rest |
          scan($tokPat) |
          if (startswith(dq) and endswith(dq)) or (startswith(sq) and endswith(sq)) then
            .[1:-1]
          else
            .
          end
        ] as $args |
        { opId: $opId, args: $args }
      end;

    def infer_json_schema($raw):
      ($raw | fromjson?) as $parsed |
      if ($parsed | type) == "object" then
        {
          "type": "object",
          "properties": (
            $parsed | with_entries(
              .value = (
                if (.value | type) == "number" then
                  { "type": (if (.value | floor) == .value then "integer" else "number" end), "example": .value }
                elif (.value | type) == "boolean" then
                  { "type": "boolean", "example": .value }
                elif (.value | type) == "array" then
                  { "type": "array", "example": .value }
                elif (.value | type) == "object" then
                  { "type": "object", "example": .value }
                else
                  { "type": "string", "example": (.value | tostring) }
                end
              )
            )
          )
        }
      elif ($parsed | type) == "array" then
        { "type": "array", "items": { "type": "string" } }
      else
        { "type": "object" }
      end;

    def build_op_from_entry($entry; $path):
      extract_call_line($entry) as $line |
      parse_call_tokens($line) as $parsed |
      [ $path | scan("[{]([^}]+)[}]") | .[0] ] as $pathParamNames |
      ($pathParamNames | length) as $pathCount |
      [
        range(0; $pathCount) as $i |
        $pathParamNames[$i] as $pname |
        ($parsed.args[$i] // $pname) as $pval |
        (
          {
            "name": $pname,
            "in": "path",
            "required": true,
            "schema": { "type": "string" }
          } + (if $pval != $pname then { "example": $pval } else {} end)
        )
      ] as $pathParams |
      ($parsed.args[$pathCount:] // []) as $remArgs |
      (
        if ($remArgs | length) > 0 and (($remArgs[-1] | startswith("{")) or ($remArgs[-1] | startswith("[")) or $remArgs[-1] == "requestBody") then
          {
            queryArgs: $remArgs[0:-1],
            bodyArg: $remArgs[-1]
          }
        else
          {
            queryArgs: $remArgs,
            bodyArg: null
          }
        end
      ) as $splitArgs |
      [
        $splitArgs.queryArgs[] |
        {
          "name": .,
          "in": "query",
          "schema": { "type": "string" }
        }
      ] as $queryParams |
      ($pathParams + $queryParams) as $allParams |
      (
        {
          "operationId": (if $parsed.opId != "" then $parsed.opId else null end),
          "parameters": (if ($allParams | length) > 0 then $allParams else null end),
          "requestBody": (
            if $splitArgs.bodyArg != null then
              {
                "content": {
                  "application/json": {
                    "schema": infer_json_schema($splitArgs.bodyArg)
                  }
                }
              }
            else
              null
            end
          ),
          "responses": { "200": { "description": "OK" } }
        } | with_entries(select(.value != null))
      );

    ($docs[0] // {}) as $d |
    (
      if ($d.endpoints | type) == "object" then
        .paths = (
          (.paths // {}) as $origPaths |
          ($d.endpoints | to_entries | map(
            .key as $path |
            ($origPaths[$path] // {}) as $origPathItem |
            {
              "key": $path,
              "value": (
                $origPathItem * (
                  .value | to_entries | map(
                    .key as $method |
                    ($origPathItem[$method] // {}) as $origOp |
                    {
                      "key": $method,
                      "value": ($origOp * build_op_from_entry(.value; $path))
                    }
                  ) | from_entries
                )
              )
            }
          ) | from_entries)
        )
      else . end
    ) |
    (
      if ($d.webhooks | type) == "object" then
        .webhooks = (
          (.webhooks // {}) as $origWh |
          ($d.webhooks | to_entries | map(
            .key as $whName |
            ($origWh[$whName] // {}) as $origWhItem |
            {
              "key": $whName,
              "value": (
                $origWhItem * (
                  .value | to_entries | map(
                    .key as $method |
                    ($origWhItem[$method] // {}) as $origOp |
                    {
                      "key": $method,
                      "value": ($origOp * build_op_from_entry(.value; ""))
                    }
                  ) | from_entries
                )
              )
            }
          ) | from_entries)
        )
      else . end
    ) |
    (
      if ($d.workflows | type) == "object" then
        (.workflows // []) as $origWfs |
        .arazzo = (.arazzo // "1.1.0") |
        .workflows = (
          $d.workflows | to_entries | map(
            .key as $wfId |
            .value as $wfVal |
            extract_call_line($wfVal) as $line |
            parse_call_tokens($line) as $parsed |
            (if ($parsed.args | length) > 0 then infer_json_schema($parsed.args[0]) else { "type": "object", "properties": {} } end) as $inferredInputs |
            ([ $origWfs[] | select(.workflowId == $wfId) ][0] // null) as $existingWf |
            if $existingWf != null then
              $existingWf * { "workflowId": $wfId, "inputs": ($existingWf.inputs // $inferredInputs) }
            else
              {
                "workflowId": $wfId,
                "inputs": $inferredInputs,
                "steps": []
              }
            end
          )
        )
      else . end
    )
  ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
