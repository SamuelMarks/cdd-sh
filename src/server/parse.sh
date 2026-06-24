#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
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
case "${STACK+x}" in *':'"${THIS_FILE}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${THIS_FILE}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

handle_parse_server() {
	file_path="${1:-server.sh}"
	if [ ! -f "${file_path}" ]; then return 1; fi

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi": "3.2.0", "info": {"title": "Parsed API", "version": "0.0.2"}}' >"${ast}"; fi

	# Extract tools_json array
	awk '
      BEGIN { in_tools = 0; tools_data = "" }
      /tools_json='\''\\\[/ { in_tools = 1; tools_data = substr($0, index($0, "'\''") + 1); next }
      in_tools == 1 {
          idx = index($0, "'\''")
          if (idx > 0) {
              tools_data = tools_data substr($0, 1, idx - 1)
              in_tools = 0
              print tools_data
          } else {
              tools_data = tools_data $0
          }
      }
    ' "$file_path" >temp_tools.json

	if [ -s temp_tools.json ]; then
		cat <<'PY_EOF' >temp_parse.py
import re, json, sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

routes = []
path = ''
method = ''
for line in content.splitlines():
    if 'elif [ "$path" =' in line:
        match1 = re.search(r'"\$path" = "([^"]+)"', line)
        if match1:
            path = match1.group(1)
        match2 = re.search(r'"\$method" = "([^"]+)"', line)
        if match2:
            method = match2.group(1).lower()
    elif 'res=$(dao_${ACTIVE_DAO}_' in line:
        match = re.search(r'res=$\(dao_$\{ACTIVE_DAO\}_([a-zA-Z0-9_]+)\)', line)
        if match:
            operationId = match.group(1)
            routes.append({"method": method, "path": path, "operationId": operationId})

with open('temp_routes.json', 'w') as f:
    json.dump(routes, f)
PY_EOF
		python3 temp_parse.py "$file_path"

		# Combine tools and routes to build paths
		jq --slurpfile routes temp_routes.json '
           . as $tools |
           reduce $routes[0][] as $route (
             {"paths": {}};
             .paths[$route.path] = (.paths[$route.path] // {}) + {
               ($route.method): (
                 ($tools | map(select(.name == $route.operationId))[0]) as $tool |
                 {
                   operationId: $route.operationId,
                   summary: ($tool.description // ""),
                   parameters: (
                     if $tool.inputSchema and $tool.inputSchema.properties then
                       $tool.inputSchema.properties | to_entries | map(
                         # heuristic: if property is in path string, it is path param, else query or body
                         if ($route.path | contains("{" + .key + "}")) then
                           {name: .key, in: "path", required: true, schema: .value}
                         elif (.key == "body") then
                           empty
                         else
                           {name: .key, in: "query", required: ($tool.inputSchema.required | contains([.key])), schema: .value}
                         end
                       )
                     else [] end
                   ),
                   requestBody: (
                     if $tool.inputSchema and $tool.inputSchema.properties and $tool.inputSchema.properties.body then
                       {
                         content: {
                           "application/json": {
                             schema: $tool.inputSchema.properties.body
                           }
                         }
                       }
                     else null end
                   )
                 } | with_entries(select(.value != null and .value != []))
               )
             }
           )
        ' temp_tools.json >parsed_paths.json

		jq --slurpfile newpaths parsed_paths.json '.paths = $newpaths[0].paths' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f temp_tools.json temp_routes.json parsed_paths.json temp_parse.py
	fi
}
