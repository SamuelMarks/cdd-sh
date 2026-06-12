#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054,SC3043,SC2129
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	THIS_FILE="${BASH_SOURCE[0]}"
	set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
	eval 'THIS_FILE="${(%):-%x}"'
	set -o pipefail
else
	THIS_FILE="${0}"
fi
case "${STACK+x}" in
*':'"${THIS_FILE}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;;
esac
export STACK="${STACK:-}${THIS_FILE}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_parse_classes parses data classes and models into the AST.
handle_parse_classes() {
	file_path="${1:-classes.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${file_path}" ]; then return 1; fi
	if [ ! -f "${ast}" ]; then echo "{}" >"${ast}"; fi

	awk '
	function finish_class() {
	if (class_name == "") return
	printf "{\"name\": \"%s\", \"description\": \"%s\", \"required\": \"%s\", \"properties\": {", class_name, desc, req
	for (i=0; i<prop_count; i++) {
	printf "\"%s\": {\"type\": \"%s\"}", props[i, "name"], props[i, "type"]
	if (i < prop_count - 1) printf ", "
	}
	printf "}}\n"
	}
	BEGIN { in_class = 0; class_name = ""; desc = ""; req = ""; prop_count = 0 }
	/^# @class / {
	if (in_class) {
	finish_class()
	}
	class_name = $3
	desc = ""
	req = ""
	delete props
	prop_count = 0
	in_class = 1
	}
	/^# @description / {
	if (in_class) desc = substr($0, 16)
	}
	/^# @property / {
	if (in_class) {
	rest = substr($0, 13)
	split(rest, p, ":")
	gsub(/^[ \t]+|[ \t]+$/, "", p[1])
	gsub(/^[ \t]+|[ \t]+$/, "", p[2])
	props[prop_count, "name"] = p[1]
	props[prop_count, "type"] = p[2]
	prop_count++
	}
	}
	/^# @required / {
	if (in_class) req = substr($0, 13)
	}
	END {
	if (in_class) {
	finish_class()
	}
	}
	' <"${file_path}" >classes_temp.jsonl
	if [ -f "classes_temp.jsonl" ]; then
		jq -s '
      reduce .[] as $item ({};
        .[$item.name] = (
          {
            type: "object",
            description: (if $item.description != "" then $item.description else null end),
            properties: (if ($item.properties | length) > 0 then $item.properties else null end),
            required: (if $item.required != "" then ($item.required | split(", ") | map(gsub("^[ \t]+|[ \t]+$";""))) else null end)
          } | with_entries(select(.value != null))
        )
      ) | {components: {schemas: .}}
    ' classes_temp.jsonl >parsed_classes.json

		# Merge carefully: components.schemas might exist or components might not exist
		jq --slurpfile newschemas parsed_classes.json '
      if .components == null then .components = {} else . end |
      .components.schemas = (($newschemas[0].components.schemas // {}) * (.components.schemas // {}))
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f classes_temp.jsonl parsed_classes.json
	fi
}
