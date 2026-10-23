#!/bin/sh
# @file src/routes/parse.sh
# @description Parses client HTTP route functions, webhooks, and callbacks into the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_routes parses network routes into the AST.
# @param $1: file_path - The input routes script path (default: routes.sh).
handle_parse_routes() {
	file_path="${1:-routes.sh}"
	if [ ! -f "${file_path}" ]; then return 1; fi

	all_raw=$(awk '
    # @function json_esc
    # @description Escapes backslashes, double quotes, and control characters for safe JSON string interpolation.
    # @param s - Input string to escape.
    function json_esc(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      gsub(/\t/, "\\t", s)
      gsub(/\r/, "\\r", s)
      gsub(/\n/, "\\n", s)
      return s
    }
    BEGIN { in_func = 0; in_webhook = 0; in_callback = 0 }
    /^# @callback / { callbackName = $3; method = ""; summary = ""; in_callback = 1; in_func = 0 }
    /^# @method / { if (in_callback||in_webhook) method = tolower($3) }
    /^# @description / { if (in_callback||in_webhook||in_func) summary = substr($0, 16) }
    /^handle_callback_/ { if (in_callback) { printf "CALLBACK:{\"name\": \"%s\", \"method\": \"%s\", \"summary\": \"%s\"}\n", json_esc(callbackName), json_esc(method), json_esc(summary); in_callback = 0 } }
    /^# @webhook / { webhookName = $3; method = ""; summary = ""; in_webhook = 1; in_func = 0 }
    /^handle_webhook_/ { if (in_webhook) { printf "WEBHOOK:{\"name\": \"%s\", \"method\": \"%s\", \"summary\": \"%s\"}\n", json_esc(webhookName), json_esc(method), json_esc(summary); in_webhook = 0 } }
    /^# @function / { operationId = $3; if (operationId ~ /^auth_(login|password|device)_/) { in_func = 0; next }; method = ""; path = ""; summary = ""; deprecated = "false"; reqBody = "false"; reqBodyType = "application/json"; param_count = 0; delete params; openapi_json = ""; extUrl = ""; extDesc = ""; in_func = 1; in_webhook = 0 }
    /^# @deprecated / { if (in_func && $3 == "true") deprecated = "true" }
    /^# @externalDocs / { if (in_func) { extUrl = $3; extDesc = substr($0, length($1) + length($2) + length($3) + 4); } }
    /^# @openapi_json / { if (in_func) { openapi_json = substr($0, 16); } }
    /^# @param/ {
      if (in_func) {
        if ($3 == "requestBody" || $4 == "requestBody") {
          reqBody = "true"
          if ($4 == "requestBody") { p_in = $5; gsub(/[\(\)]/, "", p_in); if (p_in != "") reqBodyType = p_in }
        } else if ($3 != "none") {
          p_name = $4; p_in = $5; if (substr(p_name, length(p_name)) == ":") p_name = substr(p_name, 1, length(p_name)-1)
          gsub(/[\(\)]/, "", p_in); idx = index($0, "- "); if (idx > 0) p_desc = substr($0, idx + 2); else p_desc = ""
          params[param_count, "name"] = p_name; params[param_count, "in"] = p_in; params[param_count, "desc"] = p_desc; param_count++
        }
      }
    }
    /^[ \t]*url=/ {
      if (in_func) {
        split($0, arr, "="); url = arr[2]; gsub("\"", "", url); gsub("\\$\\{BASE_URL\\}", "", url); gsub(/\$\{/, "{", url)
        for (i=0; i<param_count; i++) { if (params[i, "in"] == "path") { orig_name = params[i, "name"]; var_name = orig_name; gsub(/-/, "_", var_name); gsub("{" var_name "}", "{" orig_name "}", url) } }
        path = url
      }
    }
    /set -- -s -X|curl -s -X/ {
      if (in_func) {
        for (i=1; i<=NF; i++) { if ($i == "-X") method = tolower($(i+1)) }
        printf "OP:{\"path\": \"%s\", \"method\": \"%s\", \"operationId\": \"%s\", \"summary\": \"%s\", \"extUrl\": \"%s\", \"extDesc\": \"%s\", \"deprecated\": %s", json_esc(path), json_esc(method), json_esc(operationId), json_esc(summary), json_esc(extUrl), json_esc(extDesc), deprecated
        if (openapi_json != "") { printf ", \"openapi_json\": %s", openapi_json }
        if (param_count > 0) {
          printf ", \"parameters\": ["
          for (i=0; i<param_count; i++) {
            printf "{\"name\": \"%s\", \"in\": \"%s\", \"description\": \"%s\"}", json_esc(params[i, "name"]), json_esc(params[i, "in"]), json_esc(params[i, "desc"])
            if (i < param_count - 1) printf ", "
          }
          printf "]"
        }
        if (reqBody == "true") printf ", \"requestBody\": {\"content\": {\"%s\": {}}}", json_esc(reqBodyType)
        printf "}\n"
        in_func = 0
      }
    }
  ' <"${file_path}")

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi": "3.2.0", "info": {"title": "Parsed API", "version": "0.0.4"}}' >"${ast}"; fi

	parsed_paths=$(printf '%s\n' "$all_raw" | awk '/^OP:/ { print substr($0, 4) }' | jq -s '
      group_by(.path) | map({
        path: .[0].path,
        ops: (map({
          key: .method,
          value: ({
            operationId: .operationId,
            summary: .summary,
            deprecated: (if .deprecated == true then true else null end),
            parameters: .parameters,
            requestBody: .requestBody,
            externalDocs: (if .extUrl != "" then {url: .extUrl, description: .extDesc} else null end)
          } | with_entries(select(.value != null)) | (. * (.openapi_json // {})))
        }) | from_entries)
      }) | reduce .[] as $item ({}; .[$item.path] = $item.ops)
    ')

	parsed_callbacks=$(printf '%s\n' "$all_raw" | awk '/^CALLBACK:/ { print substr($0, 10) }' | jq -s '
      reduce .[] as $cb ({}; .[$cb.name] = {"{url}": {($cb.method): {summary: $cb.summary}}})
    ')

	parsed_webhooks=$(printf '%s\n' "$all_raw" | awk '/^WEBHOOK:/ { print substr($0, 9) }' | jq -s '
      reduce .[] as $wh ({}; .[$wh.name] = {($wh.method): {summary: $wh.summary}})
    ')

	jq --argjson newpaths "$parsed_paths" --argjson newcallbacks "$parsed_callbacks" --argjson newwebhooks "$parsed_webhooks" '
      .paths = $newpaths |
      .components.callbacks = $newcallbacks |
      .webhooks = $newwebhooks
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
