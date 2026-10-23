#!/bin/sh
# @file src/classes/parse.sh
# @description Parses annotated shell data classes into OpenAPI component schemas in the AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_classes parses data classes and models into the AST.
# @param $1: file_path - The input classes shell script path (default: classes.sh).
handle_parse_classes() {
	file_path="${1:-classes.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${file_path}" ]; then return 1; fi
	if [ ! -f "${ast}" ]; then echo "{}" >"${ast}"; fi

	parsed_classes=$(awk '
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
	# @function finish_class
	# @description Emits the accumulated class schema JSON object.
	# @param none
	function finish_class() {
	if (class_name == "") return
	printf "{\"name\": \"%s\", \"description\": \"%s\", \"required\": \"%s\", \"discriminator\": %s, \"xml\": %s, \"properties\": {", json_esc(class_name), json_esc(desc), json_esc(req), (disc != "" ? disc : "null"), (xml_obj != "" ? xml_obj : "null")
	for (i=0; i<prop_count; i++) {
	printf "\"%s\": {\"type\": \"%s\"}", json_esc(props[i, "name"]), json_esc(props[i, "type"])
	if (i < prop_count - 1) printf ", "
	}
	printf "}}\n"
	}
	BEGIN { in_class = 0; class_name = ""; desc = ""; req = ""; disc = ""; xml_obj = ""; prop_count = 0 }
	/^# @class / {
	if (in_class) {
	finish_class()
	}
	class_name = $3
	desc = ""
	req = ""
	disc = ""
	xml_obj = ""
	delete props
	prop_count = 0
	in_class = 1
	}
	/^# @description / {
	if (in_class) desc = substr($0, 16)
	}
	/^# @discriminator / {
	if (in_class) disc = substr($0, 18)
	}
	/^# @xml / {
	if (in_class) xml_obj = substr($0, 8)
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
	' <"${file_path}" | jq -s '
      reduce .[] as $item ({};
        .[$item.name] = (
          {
            type: "object",
            description: (if $item.description != "" then $item.description else null end),
            discriminator: $item.discriminator,
            xml: $item.xml,
            properties: (if ($item.properties | length) > 0 then $item.properties else null end),
            required: (if $item.required != "" then ($item.required | split(", ") | map(gsub("^[ \t]+|[ \t]+$";""))) else null end)
          } | with_entries(select(.value != null))
        )
      ) | {components: {schemas: .}}
    ')

	# Merge carefully: components.schemas might exist or components might not exist
	jq --argjson newschemas "$parsed_classes" '
      if .components == null then .components = {} else . end |
      .components.schemas = (($newschemas.components.schemas // {}) * (.components.schemas // {}))
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
}
