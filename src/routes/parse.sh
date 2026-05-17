#!/bin/sh
set -feu
if [ "${SCRIPT_NAME-}" ]; then this_file="${SCRIPT_NAME}"; elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else this_file="${0}"; fi
case "${STACK+x}" in *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_parse_routes parses network routes into the AST.
handle_parse_routes() {
	file_path="${1:-routes.sh}"
	if [ ! -f "${file_path}" ]; then return 1; fi

	awk '
    BEGIN { in_func = 0; in_webhook = 0; in_callback = 0 }
    /^# @callback / { callbackName = $3; method = ""; summary = ""; in_callback = 1; in_func = 0 }
    /^# @method / { if (in_callback||in_webhook) method = tolower($3) }
    /^# @description / { if (in_callback||in_webhook||in_func) summary = substr($0, 16) }
    /^handle_callback_/ { if (in_callback) { printf "{\"name\": \"%s\", \"method\": \"%s\", \"summary\": \"%s\"}\n", callbackName, method, summary > "callbacks_temp.jsonl"; in_callback = 0 } }
    /^# @webhook / { webhookName = $3; method = ""; summary = ""; in_webhook = 1; in_func = 0 }
    /^handle_webhook_/ { if (in_webhook) { printf "{\"name\": \"%s\", \"method\": \"%s\", \"summary\": \"%s\"}\n", webhookName, method, summary > "webhooks_temp.jsonl"; in_webhook = 0 } }
    /^# @function / { operationId = $3; if (operationId ~ /^auth_login_/) { in_func = 0; next }; method = ""; path = ""; summary = ""; reqBody = "false"; reqBodyType = "application/json"; param_count = 0; delete params; openapi_json = ""; extUrl = ""; extDesc = ""; in_func = 1; in_webhook = 0 }
    /^# @externalDocs / { if (in_func) { extUrl = $3; extDesc = substr($0, length($1) + length($2) + length($3) + 4); } }
    /^# @openapi_json / { if (in_func) { openapi_json = substr($0, 16); } }
    /^# @param/ {
      if (in_func) {
        if ($3 == "requestBody" || $4 == "requestBody") {
          reqBody = "true"
          if ($4 == "requestBody") { p_in = $5; gsub(/[\(\)]/, "", p_in); if (p_in != "") reqBodyType = p_in }
        } else {
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
    /curl -s -X/ {
      if (in_func) {
        for (i=1; i<=NF; i++) { if ($i == "-X") method = tolower($(i+1)) }
        printf "{\"path\": \"%s\", \"method\": \"%s\", \"operationId\": \"%s\", \"summary\": \"%s\", \"extUrl\": \"%s\", \"extDesc\": \"%s\"", path, method, operationId, summary, extUrl, extDesc > "ops_temp.jsonl"
        if (openapi_json != "") { printf ", \"openapi_json\": %s", openapi_json > "ops_temp.jsonl" }
        if (param_count > 0) {
          printf ", \"parameters\": [" >> "ops_temp.jsonl"
          for (i=0; i<param_count; i++) {
            printf "{\"name\": \"%s\", \"in\": \"%s\", \"description\": \"%s\"}", params[i, "name"], params[i, "in"], params[i, "desc"] >> "ops_temp.jsonl"
            if (i < param_count - 1) printf ", " >> "ops_temp.jsonl"
          }
          printf "]" >> "ops_temp.jsonl"
        }
        if (reqBody == "true") printf ", \"requestBody\": {\"content\": {\"%s\": {}}}", reqBodyType >> "ops_temp.jsonl"
        printf "}\n" >> "ops_temp.jsonl"
        in_func = 0
      }
    }
  ' "${file_path}"

	ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
	if [ ! -f "${ast}" ]; then echo '{"openapi": "3.2.0", "info": {"title": "Parsed API", "version": "0.0.1"}}' >"${ast}"; fi

	if [ -f "ops_temp.jsonl" ]; then
		jq -s '
      group_by(.path) | map({
        path: .[0].path,
        ops: (map({
          key: .method,
          value: ({
            operationId: .operationId,
            summary: .summary,
            parameters: .parameters,
            requestBody: .requestBody,
            externalDocs: (if .extUrl != "" then {url: .extUrl, description: .extDesc} else null end)
          } | with_entries(select(.value != null)) | (. * (.openapi_json // {})))
        }) | from_entries)
      }) | reduce .[] as $item ({}; .[$item.path] = $item.ops)
    ' "ops_temp.jsonl" >parsed_paths.json
		jq --slurpfile newpaths parsed_paths.json '.paths = $newpaths[0]' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f ops_temp.jsonl parsed_paths.json
	fi

	if [ -f "callbacks_temp.jsonl" ]; then
		jq -s 'reduce .[] as $cb ({}; .[$cb.name] = {"{url}": {($cb.method): {summary: $cb.summary}}})' "callbacks_temp.jsonl" >parsed_callbacks.json
		jq --slurpfile newcallbacks parsed_callbacks.json '.components.callbacks = $newcallbacks[0]' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f callbacks_temp.jsonl parsed_callbacks.json
	fi

	if [ -f "webhooks_temp.jsonl" ]; then
		jq -s 'reduce .[] as $wh ({}; .[$wh.name] = {($wh.method): {summary: $wh.summary}})' "webhooks_temp.jsonl" >parsed_webhooks.json
		jq --slurpfile newwebhooks parsed_webhooks.json '.webhooks = $newwebhooks[0]' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f webhooks_temp.jsonl parsed_webhooks.json
	fi
}
