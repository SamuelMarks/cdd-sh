#!/bin/sh
set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054,SC3043,SC2129
if [ "${SCRIPT_NAME-}" ]; then
	this_file="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else
	this_file="${0}"
fi
case "${STACK+x}" in
*':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;;
esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_emit_tests generates test scripts from the AST.
handle_emit_tests() {
	file_path="${1:-test_routes.sh}"
	routes_source_path="${2:-emitted_routes.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi

	{
		printf "#!/bin/sh\nset -eu\n\n"
		printf "# shellcheck disable=SC3028,SC2034\n"
		printf 'DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"\n'

		printf 'BASE_URL="${BASE_URL:-http://localhost:8080/v2}"\n'
		printf 'export BASE_URL\n'
		printf 'export API_KEY="special-key"\n'
		printf 'export OAUTH_TOKEN="special-key"\n'
		printf 'export BASIC_AUTH="user:pass"\n\n'
		printf '# curl is a wrapper around the system curl command.\n'
		printf 'curl() {\n'
		printf '  out=$(command curl -s -w "\\n%%{http_code}" "$@" || true)\n'
		printf '  status=$(printf "%%s\\n" "$out" | tail -n1)\n'
		printf "  body=\$(printf \"%%s\\\\n\" \"\$out\" | sed '\$d')\n"
		printf '  printf "%%s\\n" "$body"\n'
		printf '  if [ "$status" -lt 200 ] || [ "$status" -ge 400 ]; then\n'
		printf '    echo "HTTP error: $status" >&2\n'
		printf '    exit 1\n'
		printf '  fi\n'
		printf '}\n'
		printf "# shellcheck disable=SC1090,SC1091,SC2034\n"
		printf ". \"\${DIR}/%s\"\n\n" "${routes_source_path}"

		jq -r '
      . as $root |
      def generate_json(schema; root):
        if schema."$ref" then
          generate_json(root.components.schemas[schema."$ref" | sub("^#/components/schemas/"; "")] // {}; root)
        elif schema.type == "object" or schema.properties then
          "{" + ((schema.properties // {}) | to_entries | map("\"\(.key)\": \(generate_json(.value; root))") | join(", ")) + "}"
        elif schema.type == "array" then
          "[" + generate_json(schema.items // {}; root) + "]"
        elif schema.type == "integer" or schema.type == "number" then
          "1"
        elif schema.type == "boolean" then
          "true"
        elif schema.format == "date-time" then
          "\"2024-01-01T00:00:00Z\""
        elif schema.format == "byte" then
          "\"VGVzdA==\""
        elif schema.format == "uuid" then
          "\"00000000-0000-0000-0000-000000000000\""
        elif schema.enum and (schema.enum | length > 0) then
          "\"\(schema.enum[0])\""
        else
          "\"test_string\""
        end;

      def get_dummy(obj; content_type; root):
        (if obj.schema then obj.schema else obj end) as $schema |
        if obj.name == "api_key" or obj.name == "apiKey" then "\"special-key\""
        elif $schema == null then "\"test_string\""
        elif content_type == "application/x-www-form-urlencoded" then
          (if $schema."$ref" then root.components.schemas[$schema."$ref" | sub("^#/components/schemas/"; "")] else $schema end) as $s |
          (($s.properties // {}) | to_entries | map("\(.key)=test_string") | join("&")) | @json
        elif $schema.type == "integer" or $schema.type == "number" then "1"
        elif $schema.type == "boolean" then "true"
        elif $schema.format == "date-time" then "\"2024-01-01T00:00:00Z\""
        elif $schema.format == "byte" then "\"VGVzdA==\""
        elif $schema.format == "uuid" then "\"00000000-0000-0000-0000-000000000000\""
        elif $schema.type == "array" then
          if content_type == "application/json" then
            generate_json($schema; root) | @json
          else
            "\"test_string\""
          end
        elif $schema.enum and ($schema.enum | length > 0) then "\"\($schema.enum[0])\""
        elif $schema.type == "object" or $schema.properties or $schema."$ref" then 
          generate_json($schema; root) | @json
        else "\"test_string\"" end;
        
      if .paths then
        [ .paths | to_entries[] | .key as $path | .value | (.parameters // []) as $pathParams | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
          (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
          ((.parameters // []) + $pathParams | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
          
          ([
            $params[] | (get_dummy(.; ""; $root))
          ] + 
          (if .requestBody then 
             (.requestBody.content | to_entries | if length > 0 then .[0] else null end) as $ct |
             if $ct then [get_dummy($ct.value; $ct.key; $root)] else [] end
           else [] end)) as $args |
          
          { id: $opId, args: $args, method: $method }
        ] | sort_by(if .method == "post" then 1 elif .method == "put" then 2 elif .method == "get" then 3 else 4 end) as $ops |
        
        ([ $ops[] | 
          "test_\(.id)() {\n" +
          "  echo \"Testing \(.id)\"\n" +
          "  out=$(\(.id) \(.args | join(" ")))\n" +
          "  if [ -n \"$out\" ]; then\n" +
          "    echo \"$out\" | jq empty >/dev/null || { echo \"Failed to deserialize\"; exit 1; }\n" +
          "  fi\n" +
          "}\n"
        ] | join("\n")) +
        "\nrun_all_tests() {\n  touch test_string\n" +
        ([ $ops[] | "  test_\(.id)" ] | join("\n")) +
        "\n}\n\n" +
        "if ! (return 0 2>/dev/null); then\n  run_all_tests \"$@\"\nfi\n"
      else empty end
    ' "${ast}"
	} >"${file_path}.tmp"

	if [ -f "${file_path}" ]; then
		awk -v new_file="${file_path}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" "${file_path}" >"${file_path}.merged"
		mv "${file_path}.merged" "${file_path}"
		rm -f "${file_path}.tmp"
	else
		mv "${file_path}.tmp" "${file_path}"
	fi
}
