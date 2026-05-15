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
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

handle_emit_tests() {
  file_path="${1:-test_routes.sh}"
  routes_source_path="${2:-emitted_routes.sh}"
  ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
  if [ ! -f "${ast}" ]; then
    printf "Error: AST file not found at %s\n" "${ast}" >&2
    return 1
  fi

  {
    printf "#!/bin/sh\nset -eu\n\n"
    printf "# shellcheck disable=SC3028,SC2034\n"
    printf 'DIR="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"\n'

    cat << 'EOF'
BASE_URL="${BASE_URL:-http://localhost:8080/v2}"
export BASE_URL

curl() {
  out=$(command curl -s -w "\n%{http_code}" "$@" || true)
  status=$(printf "%s\n" "$out" | tail -n1)
  body=$(printf "%s\n" "$out" | sed '$d')
  printf "%s\n" "$body"
  if [ "$status" -lt 200 ] || [ "$status" -ge 400 ]; then
    echo "HTTP error: $status" >&2
    exit 1
  fi
}
EOF

    printf "# shellcheck disable=SC1090,SC1091,SC2034\n"
    printf ". \"\${DIR}/%s\"\n\n" "${routes_source_path}"

    jq -r '
      . as $root |
      def get_dummy(obj):
        (if obj.schema then obj.schema else obj end) as $schema |
        if $schema == null then "\"test_string\""
        elif $schema.type == "integer" or $schema.type == "number" then "1"
        elif $schema.type == "boolean" then "true"
        elif $schema.type == "array" then "\"[]\""
        elif $schema.type == "object" or $schema.properties or $schema."$ref" then "\"{}\""
        else "\"test_string\"" end;
        
      if .paths then
        [ .paths | to_entries[] | .key as $path | .value | (.parameters // []) as $pathParams | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
          (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
          ((.parameters // []) + $pathParams | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
          
          ([
            $params[] | (get_dummy(.))
          ] + 
          (if .requestBody then 
             [get_dummy(.requestBody.content | to_entries | if length > 0 then .[0].value else null end)] 
           else [] end)) as $args |
          
          { id: $opId, args: $args }
        ] as $ops |
        
        ([ $ops[] | 
          "test_\(.id)() {\n" +
          "  echo \"Testing \(.id)\"\n" +
          "  out=$(\(.id) \(.args | join(" ")))\n" +
          "  if [ -n \"$out\" ]; then\n" +
          "    echo \"$out\" | jq empty >/dev/null || { echo \"Failed to deserialize\"; exit 1; }\n" +
          "  fi\n" +
          "}\n"
        ] | join("\n")) +
        "\nrun_all_tests() {\n" +
        ([ $ops[] | "  test_\(.id)" ] | join("\n")) +
        "\n}\n\n" +
        "if ! (return 0 2>/dev/null); then\n  run_all_tests \"$@\"\nfi\n"
      else empty end
    ' "${ast}"
  } > "${file_path}.tmp"

  if [ -f "${file_path}" ]; then
    awk -v new_file="${file_path}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" "${file_path}" > "${file_path}.merged"
    mv "${file_path}.merged" "${file_path}"
    rm -f "${file_path}.tmp"
  else
    mv "${file_path}.tmp" "${file_path}"
  fi
}
