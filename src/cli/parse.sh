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
	# @function extract_quoted
	# @description Extracts the string value from a KEY="VALUE" or KEY='\''VALUE'\'' assignment line.
	# @param line - Raw shell assignment line.
	function extract_quoted(line,    idx, val) {
		idx = index(line, "=")
		if (idx == 0) return ""
		val = substr(line, idx + 1)
		if (substr(val, 1, 1) == "\"" && substr(val, length(val), 1) == "\"") {
			val = substr(val, 2, length(val) - 2)
			gsub(/\\"/, "\"", val)
			gsub(/\\\\/, "\\", val)
		} else if (substr(val, 1, 1) == sq && substr(val, length(val), 1) == sq) {
			val = substr(val, 2, length(val) - 2)
			gsub(sq "\\\\" sq sq, sq, val)
			gsub(sq "\\" sq sq, sq, val)
		}
		return val
	}
	# @function json_esc
	# @description Escapes backslashes and double quotes for safe JSON string interpolation.
	# @param s - Input string to escape.
	function json_esc(s) {
		gsub(/\\/, "\\\\", s)
		gsub(/"/, "\\\"", s)
		return s
	}
	/^VERSION=/ { version = extract_quoted($0) }
	/^TITLE=/ { title = extract_quoted($0) }
	/^SUMMARY=/ { summary = extract_quoted($0) }
	/^DESCRIPTION=/ { desc = extract_quoted($0) }
	/^TOS=/ { tos = extract_quoted($0) }
	/^LICENSE=/ { license = extract_quoted($0) }
	/^LICENSE_URL=/ { lurl = extract_quoted($0) }
	/^LICENSE_ID=/ { lid = extract_quoted($0) }
	/^CONTACT_NAME=/ { cname = extract_quoted($0) }
	/^CONTACT_EMAIL=/ { cemail = extract_quoted($0) }
	/^CONTACT_URL=/ { curl = extract_quoted($0) }
	/^DIALECT=/ { dialect = extract_quoted($0) }
	/^OPENAPI_JSON=/ {
		oj = extract_quoted($0)
		if (oj != "" && oj != "\"\"") openapi_json = oj
	}
	/^ARAZZO_JSON=/ {
		aj = extract_quoted($0)
		if (aj != "" && aj != "\"\"") arazzo_json = aj
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
	printf "INFO:{\"version\":\"%s\", \"title\":\"%s\", \"summary\":\"%s\", \"description\":\"%s\", \"termsOfService\":\"%s\", \"license\":{\"name\":\"%s\", \"url\": \"%s\", \"identifier\": \"%s\"}, \"contact\":{\"name\":\"%s\",\"email\":\"%s\", \"url\": \"%s\"}}\n", json_esc(version), json_esc(title), json_esc(summary), json_esc(desc), json_esc(tos), json_esc(license), json_esc(lurl), json_esc(lid), json_esc(cname), json_esc(cemail), json_esc(curl)
	printf "DIALECT:{\"jsonSchemaDialect\": \"%s\"}\n", json_esc(dialect)
	if (openapi_json != "") { printf "OPENAPI:%s\n", openapi_json }
	if (arazzo_json != "") { printf "ARAZZO:%s\n", arazzo_json }

	printf "PATHS:{\"paths\": {"
	first=1
	for (o in ops) {
	 if (!first) printf ", "
	 first=0
	 printf "\"/cli/%s\": { \"post\": { \"operationId\": \"%s\", \"parameters\": [", json_esc(o), json_esc(o)
	 pfirst=1
	 for (f in flags) {
	   split(f, parts, SUBSEP)
	   if (parts[1] == o) {
	     if (!pfirst) printf ", "
	     pfirst=0
	     printf "{\"name\": \"%s\", \"in\": \"query\"}", json_esc(parts[2])
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
