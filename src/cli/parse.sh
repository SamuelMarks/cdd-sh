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

# handle_parse_cli parses the CLI application into the AST.
handle_parse_cli() {
	file_path="${1}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi":"3.2.0"}' >"${ast}"; fi
	if [ ! -f "${file_path}" ]; then return 0; fi

	awk '
    /^VERSION=/ { split($0, a, "\""); version=a[2] }
    /^TITLE=/ { split($0, a, "\""); title=a[2] }
    /^SUMMARY=/ { split($0, a, "\""); summary=a[2] }
    /^DESCRIPTION=/ { split($0, a, "\""); desc=a[2] }
    /^TOS=/ { split($0, a, "\""); tos=a[2] }
    /^LICENSE=/ { split($0, a, "\""); license=a[2] }
    /^LICENSE_URL=/ { split($0, a, "\""); lurl=a[2] }
    /^LICENSE_ID=/ { split($0, a, "\""); lid=a[2] }
    /^CONTACT_NAME=/ { split($0, a, "\""); cname=a[2] }
    /^CONTACT_EMAIL=/ { split($0, a, "\""); cemail=a[2] }
    /^CONTACT_URL=/ { split($0, a, "\""); curl=a[2] }
    /^DIALECT=/ { split($0, a, "\""); dialect=a[2] }
    /^OPENAPI_JSON=/ { openapi_json=substr($0, 15, length($0)-15) }
    /\) *echo \"Executing / {
       op=substr($1, 1, length($1)-1)
       ops[op]=1
    }
    /--[a-zA-Z0-9_-]+\)/ {
       flag=substr($1, 3, length($1)-3)
       if (flag != "body") {
         flags[op, flag]=1
       }
    }
    END {
      printf "{\"version\":\"%s\", \"title\":\"%s\", \"summary\":\"%s\", \"description\":\"%s\", \"termsOfService\":\"%s\", \"license\":{\"name\":\"%s\", \"url\": \"%s\", \"identifier\": \"%s\"}, \"contact\":{\"name\":\"%s\",\"email\":\"%s\", \"url\": \"%s\"}}\n", version, title, summary, desc, tos, license, lurl, lid, cname, cemail, curl > "cli_info.json"
      printf "{\"jsonSchemaDialect\": \"%s\"}\n", dialect > "cli_dialect.json"
      if (openapi_json != "") { print openapi_json > "cli_openapi.json" }
      
      printf "{\"paths\": {" > "cli_paths.json"
      first=1
      for (o in ops) {
         if (!first) printf ", " > "cli_paths.json"
         first=0
         printf "\"/cli/%s\": { \"post\": { \"operationId\": \"%s\", \"parameters\": [", o, o > "cli_paths.json"
         pfirst=1
         for (f in flags) {
           split(f, parts, SUBSEP)
           if (parts[1] == o) {
             if (!pfirst) printf ", " > "cli_paths.json"
             pfirst=0
             printf "{\"name\": \"%s\", \"in\": \"query\"}", parts[2] > "cli_paths.json"
           }
         }
         printf "] } }" > "cli_paths.json"
      }
      printf "} }\n" > "cli_paths.json"
    }
  ' "$file_path"

	if [ -f "cli_info.json" ]; then
		touch cli_openapi.json
		jq --slurpfile info cli_info.json --slurpfile paths cli_paths.json --slurpfile d cli_dialect.json --slurpfile o cli_openapi.json '
      .info = ((.info // {}) * $info[0]) |
      .paths = ((.paths // {}) * $paths[0].paths) |
      if $d[0].jsonSchemaDialect != "" then .jsonSchemaDialect = $d[0].jsonSchemaDialect else . end |
      (. + ($o[0] // {}))
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f cli_info.json cli_paths.json cli_dialect.json cli_openapi.json
	fi
}
