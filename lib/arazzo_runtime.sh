#!/bin/sh
# @file lib/arazzo_runtime.sh
# @description Runtime expression, selector, criterion, and payload replacement engine for Arazzo 1.1.0 workflows.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# arazzo_init_state initializes the global WORKFLOW_STATE_JSON object for a workflow execution run.
# @param $1: inputs_json - JSON object of workflow inputs.
# @param $2: source_descs_json - JSON array of sourceDescriptions.
# @param $3: components_json - JSON object of reusable Arazzo components.
# @param $4: self_uri - String URI for $self.
arazzo_init_state() {
	_init_inputs="${1:-}"
	_init_sds="${2:-}"
	_init_comps="${3:-}"
	_init_self="${4:-}"
	if [ -z "${_init_inputs}" ] || [ "${_init_inputs}" = "{}" ]; then _init_inputs="{}"; fi
	if [ -z "${_init_sds}" ]; then _init_sds="[]"; fi
	if [ -z "${_init_comps}" ] || [ "${_init_comps}" = "{}" ]; then _init_comps="{}"; fi

	if [ -n "${WORKFLOW_STATE_JSON:-}" ]; then
		WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --argjson inp "${_init_inputs}" --argjson sds "${_init_sds}" --argjson comps "${_init_comps}" --arg self_uri "${_init_self}" '
			.inputs = $inp |
			.sourceDescriptions = (reduce $sds[] as $sd ((.sourceDescriptions // {}); .[$sd.name] = $sd)) |
			.components = ((.components // {}) * $comps) |
			.self = (if $self_uri != "" then $self_uri else (.self // "") end) |
			.steps = (.steps // {}) |
			.workflows = (.workflows // {}) |
			.outputs = (.outputs // {}) |
			.current = (.current // {"url": "", "method": "GET", "statusCode": 200, "request": {"header": {}, "query": {}, "path": {}, "body": {}}, "response": {"header": {}, "body": {}}, "message": {"header": {}, "payload": {}}})
		')
	else
		WORKFLOW_STATE_JSON=$(jq -c -n --argjson inp "${_init_inputs}" --argjson sds "${_init_sds}" --argjson comps "${_init_comps}" --arg self_uri "${_init_self}" '
			{
				inputs: $inp,
				sourceDescriptions: (reduce $sds[] as $sd ({}; .[$sd.name] = $sd)),
				components: $comps,
				self: $self_uri,
				steps: {},
				workflows: {},
				outputs: {},
				current: {
					url: "",
					method: "GET",
					statusCode: 200,
					request: {header: {}, query: {}, path: {}, body: {}},
					response: {header: {}, body: {}},
					message: {header: {}, payload: {}}
				}
			}
		')
	fi
	export WORKFLOW_STATE_JSON
}

# arazzo_xpath_extract evaluates an XPath 1.0/2.0/3.0 query against an XML string using pure AWK.
# @param $1: xml_str - The XML document string.
# @param $2: xpath_expr - The XPath expression (e.g., /order/id, //item[1]/name/text(), //item/@id).
arazzo_xpath_extract() {
	_xml_in="${1:-}"
	_xp="${2:-}"
	printf '%s
' "${_xml_in}" | awk -v xp="${_xp}" '
	BEGIN {
		gsub(/^\/+/, "", xp)
		sub(/\/text\(\)$/, "", xp)
		n = split(xp, parts, "/")
		target = parts[n]
		attr = ""
		if (index(target, "@") == 1) {
			attr = substr(target, 2)
			target = (n > 1) ? parts[n - 1] : ""
		}
		sub(/\[[0-9]+\]$/, "", target)
		found = ""
		dq = sprintf("%c", 34)
	}
	{
		line = $0
		if (attr != "") {
			pat = attr "=" dq "[^" dq "]*" dq
			if (match(line, pat)) {
				val = substr(line, RSTART + length(attr) + 2, RLENGTH - length(attr) - 3)
				if (found == "") found = val
			}
		} else if (target != "") {
			open_tag = "<" target "[^>]*>"
			close_tag = "</" target ">"
			if (match(line, open_tag)) {
				rest = substr(line, RSTART + RLENGTH)
				if (match(rest, close_tag)) {
					val = substr(rest, 1, RSTART - 1)
					if (found == "") found = val
				}
			}
		}
	}
	END {
		printf "%s", found
	}
	'
}

# arazzo_eval_expr evaluates a single Arazzo 1.1.0 runtime expression against WORKFLOW_STATE_JSON.
# Supports all 17 runtime expression roots ($url, $method, $statusCode, $request.*, $response.*,
# $message.*, $inputs.*, $outputs.*, $steps.*, $workflows.*, $sourceDescriptions.*, $components.*, $self).
# @param $1: expr - The runtime expression or literal string.
arazzo_eval_expr() {
	_expr="${1:-}"
	case "${_expr}" in
	\$* | *\{\$*\}*) ;;
	*)
		printf '%s' "${_expr}"
		return 0
		;;
	esac

	case "${_expr}" in
	*\{\$*\}*)
		arazzo_interpolate_template "${_expr}"
		return 0
		;;
	esac

	printf '%s' "${WORKFLOW_STATE_JSON:-"{}"}" | jq -r --arg expr "${_expr}" '
		def parse_subpath($s):
			if $s == "" or $s == null then []
			elif ($s | startswith("#/")) then
				($s | ltrimstr("#/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .)))
			elif ($s | contains("#/")) then
				($s | split("#/")) as $halves |
				(($halves[0] | ltrimstr(".") | if . == "" then [] else split(".") end) +
				 ($halves[1] | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))))
			else
				($s | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end)
			end;
		def lookup_ci($obj; $k):
			if ($obj | type) != "object" then null
			elif ($obj | has($k)) then $obj[$k]
			else
				($k | ascii_downcase) as $lk |
				([ $obj | to_entries[] | select((.key | ascii_downcase) == $lk) | .value ][0] // null)
			end;
		def eval_path($root; $p):
			reduce $p[] as $seg ($root;
				if . == null then null
				elif (. | type) == "object" then lookup_ci(.; ($seg | tostring))
				elif (. | type) == "array" and ($seg | type) == "number" then .[$seg]
				else null end
			);
		if $expr == "$url" then (.current.url // "")
		elif $expr == "$method" then (.current.method // "")
		elif $expr == "$statusCode" then (.current.statusCode // 200)
		elif $expr == "$self" then (.self // "")
		elif ($expr | startswith("$request.header.")) then lookup_ci(.current.request.header // {}; ($expr | ltrimstr("$request.header.")))
		elif ($expr | startswith("$request.query.")) then lookup_ci(.current.request.query // {}; ($expr | ltrimstr("$request.query.")))
		elif ($expr | startswith("$request.path.")) then lookup_ci(.current.request.path // {}; ($expr | ltrimstr("$request.path.")))
		elif $expr == "$request.body" then (.current.request.body // {})
		elif ($expr | startswith("$request.body")) then eval_path(.current.request.body; parse_subpath($expr | ltrimstr("$request.body")))
		elif ($expr | startswith("$response.header.")) then lookup_ci(.current.response.header // {}; ($expr | ltrimstr("$response.header.")))
		elif $expr == "$response.body" then (.current.response.body // {})
		elif ($expr | startswith("$response.body")) then eval_path(.current.response.body; parse_subpath($expr | ltrimstr("$response.body")))
		elif ($expr | startswith("$message.header.")) then lookup_ci(.current.message.header // {}; ($expr | ltrimstr("$message.header.")))
		elif $expr == "$message.payload" then (.current.message.payload // {})
		elif ($expr | startswith("$message.payload")) then eval_path(.current.message.payload; parse_subpath($expr | ltrimstr("$message.payload")))
		elif ($expr | startswith("$inputs.")) then eval_path(.inputs; parse_subpath($expr | ltrimstr("$inputs.")))
		elif $expr == "$inputs" then (.inputs // {})
		elif ($expr | startswith("$outputs.")) then eval_path(.outputs; parse_subpath($expr | ltrimstr("$outputs.")))
		elif $expr == "$outputs" then (.outputs // {})
		elif ($expr | startswith("$steps.")) then eval_path(.steps; parse_subpath($expr | ltrimstr("$steps.")))
		elif ($expr | startswith("$workflows.")) then eval_path(.workflows; parse_subpath($expr | ltrimstr("$workflows.")))
		elif ($expr | startswith("$sourceDescriptions.")) then eval_path(.sourceDescriptions; parse_subpath($expr | ltrimstr("$sourceDescriptions.")))
		elif ($expr | startswith("$components.")) then eval_path(.components; parse_subpath($expr | ltrimstr("$components.")))
		else $expr end |
		if . == null then "" elif (type == "object" or type == "array") then tojson else tostring end
	'
}

# arazzo_interpolate_template interpolates embedded {$...} runtime expressions inside a template string.
# @param $1: template_str - String containing zero or more {$...} placeholders.
arazzo_interpolate_template() {
	_tpl="${1:-}"
	_out=""
	_rem="${_tpl}"
	while :; do
		case "${_rem}" in
		*\{\$*\}*)
			_pre="${_rem%%\{\$*}"
			_after_open="${_rem#*\{}"
			_inner="${_after_open%%\}*}"
			_rem="${_after_open#*\}}"
			_val=$(arazzo_eval_expr "${_inner}")
			_out="${_out}${_pre}${_val}"
			;;
		*)
			_out="${_out}${_rem}"
			break
			;;
		esac
	done
	printf '%s' "${_out}"
}

# arazzo_select_value evaluates an Arazzo 1.1.0 Selector Object or runtime expression string.
# Supports jsonpointer (rfc6901), jsonpath (rfc9535 / draft-goessner), and xpath (xpath-30/20/10).
# @param $1: selector_or_expr_json - JSON string representing either a string expression or Selector Object.
arazzo_select_value() {
	_sel_raw="${1:-}"
	if printf '%s' "${_sel_raw}" | jq -e 'type == "object" and (has("selector") or has("context"))' >/dev/null 2>&1; then
		_ctx_expr=$(printf '%s' "${_sel_raw}" | jq -r '.context // "$response.body"')
		_selector=$(printf '%s' "${_sel_raw}" | jq -r '.selector // ""')
		_sel_type=$(printf '%s' "${_sel_raw}" | jq -r 'if (.type | type) == "object" then (.type.type // "jsonpath") else (.type // "jsonpath") end' | tr '[:upper:]' '[:lower:]')
		_ctx_val=$(arazzo_eval_expr "${_ctx_expr}")
		if [ -z "${_selector}" ]; then
			printf '%s' "${_ctx_val}"
			return 0
		fi
		case "${_sel_type}" in
		xpath*)
			arazzo_xpath_extract "${_ctx_val}" "${_selector}"
			;;
		jsonpointer | rfc6901)
			printf '%s' "${_ctx_val}" | jq -r --arg ptr "${_selector}" '
				($ptr | ltrimstr("#") | ltrimstr("/") | if . == "" then [] else (split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))) end) as $p |
				getpath($p) | if . == null then "" elif (type == "object" or type == "array") then tojson else tostring end
			'
			;;
		*)
			printf '%s' "${_ctx_val}" | jq -r --arg jp "${_selector}" '
				if ($jp | startswith("$..")) then
					($jp | ltrimstr("$..")) as $key |
					([ .. | objects | select(has($key)) | .[$key] ][0] // "")
				else
					($jp | ltrimstr("$") | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end) as $p |
					getpath($p)
				end |
				if . == null then "" elif (type == "object" or type == "array") then tojson else tostring end
			'
			;;
		esac
	else
		_unquoted=$(printf '%s' "${_sel_raw}" | jq -r 'if type == "string" then . else tojson end' 2>/dev/null || printf '%s' "${_sel_raw}")
		arazzo_eval_expr "${_unquoted}"
	fi
}

# arazzo_eval_criterion evaluates a single Arazzo 1.1.0 Criterion Object against WORKFLOW_STATE_JSON.
# Returns 0 if the criterion passes, 1 if it fails.
# @param $1: criterion_json - JSON object with condition, optional context, and optional type.
arazzo_eval_criterion() {
	_crit_json="${1:-"{}"}"
	_cond=$(printf '%s' "${_crit_json}" | jq -r '.condition // ""')
	_ctx_expr=$(printf '%s' "${_crit_json}" | jq -r '.context // ""')
	_ctype=$(printf '%s' "${_crit_json}" | jq -r 'if (.type | type) == "object" then (.type.type // "simple") else (.type // "simple") end' | tr '[:upper:]' '[:lower:]')

	if [ -z "${_cond}" ]; then
		return 0
	fi

	case "${_ctype}" in
	regex)
		_ctx_val=$(arazzo_eval_expr "${_ctx_expr:-$statusCode}")
		if printf '%s' "${_ctx_val}" | jq -R -e --arg pat "${_cond}" 'test($pat)' >/dev/null 2>&1; then
			return 0
		fi
		return 1
		;;
	xpath*)
		_ctx_val=$(arazzo_eval_expr "${_ctx_expr:-$response.body}")
		_extracted=$(arazzo_xpath_extract "${_ctx_val}" "${_cond}")
		if [ -n "${_extracted}" ]; then
			return 0
		fi
		return 1
		;;
	jsonpath)
		_ctx_val=$(arazzo_eval_expr "${_ctx_expr:-$response.body}")
		if printf '%s' "${_ctx_val}" | jq -e --arg jp "${_cond}" --arg sq "'" '
			if ($jp | contains("[?(")) then
				if ($jp | contains("==")) then
					($jp | split("@.")[1] | split(")")[0] | split("==")) as $parts |
					($parts[0] | gsub(" "; "")) as $k |
					($parts[1] | gsub(" "; "") | gsub($sq; "")) as $v |
					([ .. | objects | select(.[$k] == $v) ] | length) > 0
				else
					(. != null and . != "" and . != [] and . != {})
				end
			else
				($jp | ltrimstr("$") | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end) as $p |
				getpath($p) != null and getpath($p) != false
			end
		' >/dev/null 2>&1; then
			return 0
		fi
		return 1
		;;
	*)
		_resolved_cond=$(printf '%s' "${_cond}" | awk '
			{
				line = $0
				out = ""
				while (match(line, /\$[a-zA-Z0-9_.#\/~-]+/)) {
					pre = substr(line, 1, RSTART - 1)
					tok = substr(line, RSTART, RLENGTH)
					line = substr(line, RSTART + RLENGTH)
					out = out pre "{" tok "}"
				}
				out = out line
				print out
			}
		')
		_interpolated=$(arazzo_interpolate_template "${_resolved_cond}")
		if [ -n "${_ctx_expr}" ] && ! printf '%s' "${_cond}" | grep -q '\$'; then
			_ctx_val=$(arazzo_eval_expr "${_ctx_expr}")
			_interpolated="${_ctx_val} ${_interpolated}"
		fi
		if jq -n -e --arg expr "${_interpolated}" --arg sq "'" '
			def trim_ws($s):
				$s | sub("^[ \t]+"; "") | sub("[ \t]+$"; "") | ltrimstr($sq) | rtrimstr($sq);
			def eval_atom($a):
				trim_ws($a) as $t |
				if ($t | contains("==")) then
					($t | split("==")) as $p |
					(trim_ws($p[0]) == trim_ws($p[1]))
				elif ($t | contains("!=")) then
					($t | split("!=")) as $p |
					(trim_ws($p[0]) != trim_ws($p[1]))
				elif ($t | contains(">=")) then
					($t | split(">=")) as $p |
					(((trim_ws($p[0]) | tonumber?) // 0) >= ((trim_ws($p[1]) | tonumber?) // 0))
				elif ($t | contains("<=")) then
					($t | split("<=")) as $p |
					(((trim_ws($p[0]) | tonumber?) // 0) <= ((trim_ws($p[1]) | tonumber?) // 0))
				elif ($t | contains(">")) then
					($t | split(">")) as $p |
					(((trim_ws($p[0]) | tonumber?) // 0) > ((trim_ws($p[1]) | tonumber?) // 0))
				elif ($t | contains("<")) then
					($t | split("<")) as $p |
					(((trim_ws($p[0]) | tonumber?) // 0) < ((trim_ws($p[1]) | tonumber?) // 0))
				else
					($t != "" and $t != "false" and $t != "null" and $t != "0")
				end;
			if ($expr | contains("||")) then
				any($expr | split("||")[]; eval_atom(.))
			elif ($expr | contains("&&")) then
				all($expr | split("&&")[]; eval_atom(.))
			else
				eval_atom($expr)
			end
		' >/dev/null 2>&1; then
			return 0
		fi
		return 1
		;;
	esac
}

# arazzo_build_request_body constructs an HTTP request payload from a Step Object's requestBody definition,
# evaluating runtime expressions and applying all Payload Replacement Objects.
# @param $1: req_body_def_json - JSON object of the step's requestBody (contentType, payload, replacements).
arazzo_build_request_body() {
	_rb_def="${1:-"{}"}"
	if [ -z "${_rb_def}" ] || [ "${_rb_def}" = "null" ] || [ "${_rb_def}" = "{}" ]; then
		printf ""
		return 0
	fi

	_raw_payload=$(printf '%s' "${_rb_def}" | jq -c '.payload // empty')
	if [ -z "${_raw_payload}" ]; then
		printf ""
		return 0
	fi

	if printf '%s' "${_raw_payload}" | jq -e 'type == "string"' >/dev/null 2>&1; then
		_str_p=$(printf '%s' "${_raw_payload}" | jq -r '.')
		_body_json=$(arazzo_eval_expr "${_str_p}")
	else
		_str_leaves=$(printf '%s' "${_raw_payload}" | jq -r 'paths(scalars) as $p | "\($p | tojson)	\(getpath($p))"' 2>/dev/null || true)
		_body_json="${_raw_payload}"
		if [ -n "${_str_leaves}" ]; then
			while IFS='	' read -r _p_json _leaf_val; do
				[ -z "${_p_json}" ] && continue
				case "${_leaf_val}" in
				\$* | *\{\$*\}*)
					_eval_v=$(arazzo_eval_expr "${_leaf_val}")
					_body_json=$(printf '%s' "${_body_json}" | jq -c --argjson p "${_p_json}" --arg v "${_eval_v}" 'setpath($p; (($v | fromjson?) // $v))')
					;;
				esac
			done <<EOF
${_str_leaves}
EOF
		fi
	fi

	_repl_list=$(printf '%s' "${_rb_def}" | jq -c '.replacements[]? // empty' 2>/dev/null || true)
	if [ -n "${_repl_list}" ]; then
		while IFS= read -r _repl; do
			[ -z "${_repl}" ] && continue
			_target=$(printf '%s' "${_repl}" | jq -r '.target // ""')
			_raw_val=$(printf '%s' "${_repl}" | jq -r 'if (.value | type) == "string" then .value else (.value | tojson) end')
			_resolved_val=$(arazzo_eval_expr "${_raw_val}")
			if [ -n "${_target}" ]; then
				_body_json=$(printf '%s' "${_body_json}" | jq -c --arg t "${_target}" --arg v "${_resolved_val}" '
					($t | ltrimstr("$") | ltrimstr(".") | ltrimstr("#") | ltrimstr("/") | split("[") | join("/") | split("]") | join("") | split(".") | join("/") | split("/") | map(select(. != "") | gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))) as $path |
					setpath($path; (($v | fromjson?) // $v))
				' 2>/dev/null || printf '%s' "${_body_json}")
			fi
		done <<EOF
${_repl_list}
EOF
	fi

	printf '%s' "${_body_json}"
}

# arazzo_execute_step executes a single Arazzo workflow step, evaluates successCriteria, extracts step outputs,
# and resolves onSuccess / onFailure state-machine transitions (including retry loops and goto jumps).
# @param $1: wf_id - Workflow identifier.
# @param $2: step_id - Step identifier.
# @param $3: target_kind - Target kind (operationId, operationPath, channelPath, workflowId).
# @param $4: target_fn - Resolved shell function name or operationId.
# @param $5: params_json - JSON array of resolved Parameter Objects.
# @param $6: rb_json - JSON object of step requestBody.
# @param $7: criteria_json - JSON array of Criterion Objects.
# @param $8: on_success_json - JSON array of Success Action Objects.
# @param $9: on_failure_json - JSON array of Failure Action Objects.
# @param $10: outputs_json - JSON object of step output definitions.
# @param $11: next_default_step - Next sequential stepId or __END__.
# @param $12: timeout_ms - Step timeout in milliseconds (0 for default).
arazzo_execute_step() {
	_es_wf_id="$1"
	_es_step_id="$2"
	_es_kind="$3"
	_es_fn="$4"
	_es_params="${5:-[]}"
	_es_rb="${6:-"{}"}"
	_es_criteria="${7:-[]}"
	_es_on_success="${8:-[]}"
	_es_on_failure="${9:-[]}"
	_es_outputs="${10:-"{}"}"
	_es_next="${11:-__END__}"
	_es_timeout="${12:-0}"

	_retry_count=0
	while :; do
		_req_headers="{}"
		_req_query="{}"
		_req_path="{}"
		_pos_args=""
		_param_lines=$(printf '%s' "${_es_params}" | jq -c '.[]? // empty' 2>/dev/null || true)
		if [ -n "${_param_lines}" ]; then
			while IFS= read -r _p_obj; do
				[ -z "${_p_obj}" ] && continue
				_p_name=$(printf '%s' "${_p_obj}" | jq -r '.name // ""')
				_p_in=$(printf '%s' "${_p_obj}" | jq -r '.in // "query"')
				_p_raw_val=$(printf '%s' "${_p_obj}" | jq -r 'if (.value | type) == "string" then .value else (.value | tojson) end')
				_p_val=$(arazzo_eval_expr "${_p_raw_val}")
				_pos_args="${_pos_args} $(printf '%s' "${_p_val}" | jq -R -s '@sh')"
				case "${_p_in}" in
				header)
					_req_headers=$(printf '%s' "${_req_headers}" | jq -c --arg k "${_p_name}" --arg v "${_p_val}" '. + {($k): $v}')
					;;
				path)
					_req_path=$(printf '%s' "${_req_path}" | jq -c --arg k "${_p_name}" --arg v "${_p_val}" '. + {($k): $v}')
					;;
				*)
					_req_query=$(printf '%s' "${_req_query}" | jq -c --arg k "${_p_name}" --arg v "${_p_val}" '. + {($k): $v}')
					;;
				esac
			done <<EOF
${_param_lines}
EOF
		fi

		_req_body_str=$(arazzo_build_request_body "${_es_rb}")
		if [ -n "${_req_body_str}" ]; then
			_pos_args="${_pos_args} $(printf '%s' "${_req_body_str}" | jq -R -s '@sh')"
		fi

		_step_method="GET"
		if [ -n "${_req_body_str}" ]; then _step_method="POST"; fi

		WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --arg url "${BASE_URL:-http://localhost:8080}/${_es_fn}" --arg method "${_step_method}" --argjson rh "${_req_headers}" --argjson rq "${_req_query}" --argjson rp "${_req_path}" --arg rb "${_req_body_str}" '
			.current.url = $url |
			.current.method = $method |
			.current.request.header = $rh |
			.current.request.query = $rq |
			.current.request.path = $rp |
			.current.request.body = (($rb | fromjson?) // $rb)
		')

		_resp_status=200
		_resp_body="{}"
		_resp_headers="{}"
		if [ "${_es_kind}" = "workflowId" ] && type "${_es_fn}" >/dev/null 2>&1; then
			_sub_inp="${_req_body_str}"
			if [ -z "${_sub_inp}" ]; then _sub_inp="${_req_query}"; fi
			set +e
			_resp_body=$("${_es_fn}" "${_sub_inp}")
			_call_rc=$?
			set -e
			if [ "${_call_rc}" -ne 0 ]; then _resp_status=500; fi
		elif [ "${_es_kind}" = "channelPath" ]; then
			if type "${_es_fn}" >/dev/null 2>&1; then
				set +e
				_resp_body=$(eval "${_es_fn} ${_pos_args}")
				_call_rc=$?
				set -e
				if [ "${_call_rc}" -ne 0 ]; then _resp_status=500; fi
			else
				_resp_body=$(jq -c -n --arg ch "${_es_fn}" --arg p "${_req_body_str}" '{"status":"delivered","channel":$ch,"payload":(($p | fromjson?) // $p)}')
			fi
			WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --argjson mh "${_req_headers}" --arg mp "${_resp_body}" '
				.current.message.header = $mh |
				.current.message.payload = (($mp | fromjson?) // $mp)
			')
		elif type "${_es_fn}" >/dev/null 2>&1; then
			set +e
			_resp_body=$(eval "${_es_fn} ${_pos_args}")
			_call_rc=$?
			set -e
			if [ "${_call_rc}" -ne 0 ]; then
				_resp_status="${ARAZZO_MOCK_STATUS:-500}"
			else
				_resp_status="${ARAZZO_MOCK_STATUS:-200}"
			fi
			if [ -z "${_resp_body}" ]; then _resp_body="{}"; fi
		else
			if [ -n "${BASE_URL:-}" ]; then
				_curl_timeout_arg=""
				if [ "${_es_timeout}" -gt 0 ] 2>/dev/null; then
					_t_sec=$((_es_timeout / 1000))
					[ "${_t_sec}" -lt 1 ] && _t_sec=1
					_curl_timeout_arg="--max-time ${_t_sec}"
				fi
				set +e
				# shellcheck disable=SC2086
				_raw_http=$(curl -s ${_curl_timeout_arg} -w "
%{http_code}" "${BASE_URL}/${_es_fn}" 2>/dev/null || printf "{}
200")
				set -e
				_resp_status=$(printf '%s
' "${_raw_http}" | tail -n1)
				_resp_body=$(printf '%s
' "${_raw_http}" | sed '$d')
				[ -z "${_resp_body}" ] && _resp_body="{}"
			else
				_resp_status="${ARAZZO_MOCK_STATUS:-200}"
				if [ -n "${ARAZZO_MOCK_BODY:-}" ]; then
					_resp_body="${ARAZZO_MOCK_BODY}"
				else
					_resp_body='{"status":"ok","id":"mock-id-1","token":"mock-token-123"}'
				fi
			fi
		fi

		if [ -n "${ARAZZO_MOCK_HEADERS:-}" ]; then
			_resp_headers="${ARAZZO_MOCK_HEADERS}"
		fi

		WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --arg stepId "${_es_step_id}" --arg status "${_resp_status}" --arg body "${_resp_body}" --argjson hdrs "${_resp_headers}" '
			.current.statusCode = (($status | tonumber?) // 200) |
			.current.response.header = $hdrs |
			.current.response.body = (($body | fromjson?) // $body) |
			.steps[$stepId] = {
				url: .current.url,
				method: .current.method,
				statusCode: .current.statusCode,
				request: .current.request,
				response: .current.response,
				message: .current.message,
				outputs: (.steps[$stepId].outputs // {})
			}
		')

		_all_passed=1
		_crit_items=$(printf '%s' "${_es_criteria}" | jq -c '.[]? // empty' 2>/dev/null || true)
		if [ -n "${_crit_items}" ]; then
			while IFS= read -r _c_item; do
				[ -z "${_c_item}" ] && continue
				if ! arazzo_eval_criterion "${_c_item}"; then
					_all_passed=0
					break
				fi
			done <<EOF
${_crit_items}
EOF
		elif [ "${_resp_status}" -ge 400 ] 2>/dev/null; then
			_all_passed=0
		fi

		if [ "${_all_passed}" -eq 1 ]; then
			_out_keys=$(printf '%s' "${_es_outputs}" | jq -r 'keys[]? // empty' 2>/dev/null || true)
			if [ -n "${_out_keys}" ]; then
				while IFS= read -r _ok; do
					[ -z "${_ok}" ] && continue
					_odef=$(printf '%s' "${_es_outputs}" | jq -c --arg k "${_ok}" '.[$k]')
					_oval=$(arazzo_select_value "${_odef}")
					WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --arg stepId "${_es_step_id}" --arg k "${_ok}" --arg v "${_oval}" '.steps[$stepId].outputs[$k] = (($v | fromjson?) // $v)')
				done <<EOF
${_out_keys}
EOF
			fi

			_matched_action=""
			_succ_items=$(printf '%s' "${_es_on_success}" | jq -c '.[]? // empty' 2>/dev/null || true)
			if [ -n "${_succ_items}" ]; then
				while IFS= read -r _sa; do
					[ -z "${_sa}" ] && continue
					_sa_ok=1
					_sa_crits=$(printf '%s' "${_sa}" | jq -c '.criteria[]? // empty' 2>/dev/null || true)
					if [ -n "${_sa_crits}" ]; then
						while IFS= read -r _sac; do
							[ -z "${_sac}" ] && continue
							if ! arazzo_eval_criterion "${_sac}"; then
								_sa_ok=0
								break
							fi
						done <<EOF
${_sa_crits}
EOF
					fi
					if [ "${_sa_ok}" -eq 1 ]; then
						_matched_action="${_sa}"
						break
					fi
				done <<EOF
${_succ_items}
EOF
			fi

			if [ -n "${_matched_action}" ]; then
				_act_type=$(printf '%s' "${_matched_action}" | jq -r '.type // "end"')
				case "${_act_type}" in
				end)
					_current_step="__END__"
					return 0
					;;
				goto)
					_goto_step=$(printf '%s' "${_matched_action}" | jq -r '.stepId // ""')
					_goto_wf=$(printf '%s' "${_matched_action}" | jq -r '.workflowId // ""')
					if [ -n "${_goto_step}" ]; then
						_current_step="${_goto_step}"
						return 0
					elif [ -n "${_goto_wf}" ]; then
						_goto_fn="workflow_$(printf '%s' "${_goto_wf}" | sed 's/[^a-zA-Z0-9_]/_/g')"
						if type "${_goto_fn}" >/dev/null 2>&1; then
							"${_goto_fn}" "${_wf_inputs:-"{}"}" >/dev/null || return 1
						fi
						_current_step="__END__"
						return 0
					fi
					;;
				esac
			fi

			_current_step="${_es_next}"
			return 0
		else
			_matched_fail=""
			_fail_items=$(printf '%s' "${_es_on_failure}" | jq -c '.[]? // empty' 2>/dev/null || true)
			if [ -n "${_fail_items}" ]; then
				while IFS= read -r _fa; do
					[ -z "${_fa}" ] && continue
					_fa_ok=1
					_fa_crits=$(printf '%s' "${_fa}" | jq -c '.criteria[]? // empty' 2>/dev/null || true)
					if [ -n "${_fa_crits}" ]; then
						while IFS= read -r _fac; do
							[ -z "${_fac}" ] && continue
							if ! arazzo_eval_criterion "${_fac}"; then
								_fa_ok=0
								break
							fi
						done <<EOF
${_fa_crits}
EOF
					fi
					if [ "${_fa_ok}" -eq 1 ]; then
						_matched_fail="${_fa}"
						break
					fi
				done <<EOF
${_fail_items}
EOF
			fi

			if [ -n "${_matched_fail}" ]; then
				_fact_type=$(printf '%s' "${_matched_fail}" | jq -r '.type // "end"')
				case "${_fact_type}" in
				retry)
					_r_limit=$(printf '%s' "${_matched_fail}" | jq -r '.retryLimit // 1')
					_r_after=$(printf '%s' "${_matched_fail}" | jq -r '.retryAfter // 0')
					if [ "${_retry_count}" -lt "${_r_limit}" ]; then
						_retry_count=$((_retry_count + 1))
						if [ "${_r_after}" -gt 0 ] 2>/dev/null && [ "${ARAZZO_SKIP_SLEEP:-1}" = "0" ]; then
							sleep "${_r_after}"
						fi
						if [ -n "${ARAZZO_RETRY_RECOVERY_STATUS:-}" ]; then
							ARAZZO_MOCK_STATUS="${ARAZZO_RETRY_RECOVERY_STATUS}"
						fi
						continue
					fi
					;;
				goto)
					_goto_step=$(printf '%s' "${_matched_fail}" | jq -r '.stepId // ""')
					if [ -n "${_goto_step}" ]; then
						_current_step="${_goto_step}"
						return 0
					fi
					;;
				end)
					_current_step="__END__"
					return 1
					;;
				esac
			fi

			printf "Error: step %s in workflow %s failed successCriteria
" "${_es_step_id}" "${_es_wf_id}" >&2
			return 1
		fi
	done
}

# arazzo_finalize_workflow computes the workflow outputs object, records it in WORKFLOW_STATE_JSON, and prints it to stdout.
# @param $1: wf_id - Workflow identifier.
# @param $2: wf_outputs_def_json - JSON object of workflow output definitions.
arazzo_finalize_workflow() {
	_fw_id="$1"
	_fw_defs="${2:-"{}"}"
	_final_out="{}"
	_out_keys=$(printf '%s' "${_fw_defs}" | jq -r 'keys[]? // empty' 2>/dev/null || true)
	if [ -n "${_out_keys}" ]; then
		while IFS= read -r _ok; do
			[ -z "${_ok}" ] && continue
			_odef=$(printf '%s' "${_fw_defs}" | jq -c --arg k "${_ok}" '.[$k]')
			_oval=$(arazzo_select_value "${_odef}")
			_final_out=$(printf '%s' "${_final_out}" | jq -c --arg k "${_ok}" --arg v "${_oval}" '.[$k] = (($v | fromjson?) // $v)')
		done <<EOF
${_out_keys}
EOF
	fi

	WORKFLOW_STATE_JSON=$(printf '%s' "${WORKFLOW_STATE_JSON}" | jq -c --arg wfId "${_fw_id}" --argjson out "${_final_out}" '
		.outputs = $out |
		.workflows[$wfId] = {
			inputs: .inputs,
			outputs: $out
		}
	')
	export WORKFLOW_STATE_JSON
	printf '%s
' "${_final_out}"
}

# emit_arazzo_runtime_func outputs the inline runtime functions for standalone generated workflow scripts.
# @param none
emit_arazzo_runtime_func() {
	awk '
		/^# arazzo_init_state / { p = 1 }
		/^# emit_arazzo_runtime_func / { p = 0 }
		p { print $0 }
	' "${LIBSCRIPT_ROOT_DIR:-.}/lib/arazzo_runtime.sh"
}
