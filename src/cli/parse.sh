#!/bin/sh
# @file src/cli/parse.sh
# @description Parses a generated CLI script into the unified OpenAPI and Arazzo AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_cli parses the CLI application into the AST.
# @param $1: file_path - The input CLI script path.
handle_parse_cli() {
	file_path="${1}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi":"3.2.0"}' >"${ast}"; fi
	if [ ! -f "${file_path}" ]; then return 0; fi

	all_raw=$(awk -v sq="'" '
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
	/^ARAZZO_JSON=/ {
		aj = substr($0, 13)
		if (substr(aj, 1, 1) == sq) aj = substr(aj, 2)
		if (substr(aj, length(aj), 1) == sq) aj = substr(aj, 1, length(aj) - 1)
		gsub(sq "\\\\" sq sq, sq, aj)
		gsub(sq "\\" sq sq, sq, aj)
		if (aj != "\"\"") arazzo_json = aj
	}
	/\) *echo \"Executing / {
	op=substr($1, 1, length($1)-1)
	ops[op]=1
	}
	/--[a-zA-Z0-9_-]+\)/ {
	flag=substr($1, 3, length($1)-3)
	if (flag != "body" && flag != "help" && flag != "version" && flag != "inputs" && flag != "input-file" && flag != "step" && flag != "format" && flag != "server" && flag != "verbose") {
	 flags[op, flag]=1
	}
	}
	END {
	printf "INFO:{\"version\":\"%s\", \"title\":\"%s\", \"summary\":\"%s\", \"description\":\"%s\", \"termsOfService\":\"%s\", \"license\":{\"name\":\"%s\", \"url\": \"%s\", \"identifier\": \"%s\"}, \"contact\":{\"name\":\"%s\",\"email\":\"%s\", \"url\": \"%s\"}}\n", version, title, summary, desc, tos, license, lurl, lid, cname, cemail, curl
	printf "DIALECT:{\"jsonSchemaDialect\": \"%s\"}\n", dialect
	if (openapi_json != "") { printf "OPENAPI:%s\n", openapi_json }
	if (arazzo_json != "") { printf "ARAZZO:%s\n", arazzo_json }

	printf "PATHS:{\"paths\": {"
	first=1
	for (o in ops) {
	 if (!first) printf ", "
	 first=0
	 printf "\"/cli/%s\": { \"post\": { \"operationId\": \"%s\", \"parameters\": [", o, o
	 pfirst=1
	 for (f in flags) {
	   split(f, parts, SUBSEP)
	   if (parts[1] == o) {
	     if (!pfirst) printf ", "
	     pfirst=0
	     printf "{\"name\": \"%s\", \"in\": \"query\"}", parts[2]
	   }
	 }
	 printf "] } }"
	}
	printf "} }\n"
	}
	' <"$file_path")

	cli_info=$(printf '%s\n' "$all_raw" | awk '/^INFO:/ { print substr($0, 6) }')
	cli_dialect=$(printf '%s\n' "$all_raw" | awk '/^DIALECT:/ { print substr($0, 9) }')
	cli_openapi=$(printf '%s\n' "$all_raw" | awk '/^OPENAPI:/ { print substr($0, 9) }')
	cli_arazzo=$(printf '%s\n' "$all_raw" | awk '/^ARAZZO:/ { print substr($0, 8) }')
	cli_paths=$(printf '%s\n' "$all_raw" | awk '/^PATHS:/ { print substr($0, 7) }')
	if [ -z "$cli_openapi" ]; then cli_openapi="{}"; fi

	if [ -n "$cli_info" ]; then
		jq --argjson info "$cli_info" --argjson paths "$cli_paths" --argjson d "$cli_dialect" --argjson o "$cli_openapi" '
      .info = ((.info // {}) * $info) |
      .paths = ((.paths // {}) * $paths.paths) |
      if $d.jsonSchemaDialect != "" then .jsonSchemaDialect = $d.jsonSchemaDialect else . end |
      (. + $o)
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	fi

	if [ -n "$cli_arazzo" ] && printf '%s' "$cli_arazzo" | jq -e '.' >/dev/null 2>&1; then
		norm_arz=$(printf '%s' "$cli_arazzo" | jq -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "arazzo"; normalize_arazzo_root')
		jq --argjson arz "$norm_arz" '. * $arz' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
	fi
}
