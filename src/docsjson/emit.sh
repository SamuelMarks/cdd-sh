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

handle_to_docs_json() {
	input_file=""
	no_imports="false"
	no_wrapping="false"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-i | --input)
			input_file="$2"
			shift 2
			;;
		-o | --output) shift 2 ;;
		--no-imports)
			no_imports="true"
			shift 1
			;;
		--no-wrapping)
			no_wrapping="true"
			shift 1
			;;
		*)
			printf "Unknown option %s\n" "$1" >&2
			exit 1
			;;
		esac
	done

	if [ -z "$input_file" ]; then
		printf "Error: -i/--input is required\n" >&2
		exit 1
	fi
	if [ ! -f "$input_file" ]; then
		printf "Error: Input file %s not found\n" "$input_file" >&2
		exit 1
	fi

	jq -n --slurpfile spec "$input_file" \
		--arg no_imports "$no_imports" \
		--arg no_wrapping "$no_wrapping" '
    {
      "endpoints": (
        if $spec[0].paths then
          $spec[0].paths | to_entries | map(
            .key as $path |
            .value | to_entries | map(
              select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") |
              .key as $method |
              .value |
              (if .operationId then .operationId else "\($method)_\($path | gsub("/"; "_") | gsub("[{}]"; "") | sub("^_"; ""))" end) as $opId |
              
              (
                (if $no_imports == "false" then ". ./routes.sh\n\n" else "" end) +
                (if $no_wrapping == "false" then "main() {\n" else "" end) +
                "  " + $opId + (if .parameters then (.parameters | map(" \"dummy\"") | join("")) else "" end) + "\n" +
                (if $no_wrapping == "false" then "}\n\nmain \"$@\"\n" else "" end)
              ) as $finalCode |
              
              {
                "key": ($method | ascii_downcase),
                "value": $finalCode
              }
            ) | from_entries |
            { "key": $path, "value": . }
          ) | from_entries
        else
          {}
        end
      )
    }
  '
}
