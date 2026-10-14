#!/bin/sh
# @file src/mocks/emit.sh
# @description Emits mock response JSON payloads from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_mocks generates mock responses from the AST.
# @param $1: file_path - The destination JSON file path (default: mocks.json).
handle_emit_mocks() {
	file_path="${1:-mocks.json}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi
	# Simple mock generator from components.examples or operation responses
	jq '
    if .components and .components.examples then .components.examples
    elif .paths then
      [ .paths | to_entries[] | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .value.responses // {} | to_entries[] | select(.key == "200") | (if .value.content then .value.content | to_entries[0].value.example // {} else {} end) ]
    else {} end
  ' "${ast}" >"${file_path}"

	dir_path="${file_path%/*}"
	if [ "${dir_path}" = "${file_path}" ]; then dir_path="."; fi
	sh_path="${dir_path}/mocks.sh"
	json_name="${file_path##*/}"

	{
		printf "#!/bin/sh\n"
		printf "# shellcheck disable=SC3028,SC2034\n"
		printf "DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE:-\$0}\")\" && pwd)\"\n\n"
		printf "# curl overrides the system curl to return mock data from %s\n" "${json_name}"
		printf 'curl() {\n'
		printf '  if [ -f "$DIR/mocks.json" ]; then\n'
		printf '    # Simply return the first mock we find, or `{}`.\n'
		printf '    body=$(jq -r '"'"'if type == "array" and length > 0 then .[0] else . end | tojson'"'"' "$DIR/mocks.json" 2>/dev/null || echo "{}")\n'
		printf '  else\n'
		printf '    body="{}"\n'
		printf '  fi\n'
		printf '  printf "%%s\\n" "$body"\n'
		printf '}\n'
	} >"${sh_path}"
}
