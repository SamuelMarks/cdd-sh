#!/bin/sh
# @file src/arazzo/parse.sh
# @description Parses Arazzo 1.0.1 and 1.1.0 workflow specifications into the unified CDD AST and resolves linked sourceDescriptions.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_parse_arazzo parses a single Arazzo JSON specification into the AST and resolves local sourceDescriptions.
# @param $1: file_path - The input Arazzo JSON specification path (default: arazzo.json).
handle_parse_arazzo() {
	file_path="${1:-arazzo.json}"
	if [ ! -f "${file_path}" ]; then
		printf "Error: Arazzo file not found at %s\n" "${file_path}" >&2
		return 1
	fi
	if ! jq -e '.' "${file_path}" >/dev/null 2>&1; then
		printf "Error: Invalid JSON in Arazzo file %s\n" "${file_path}" >&2
		return 1
	fi

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "{}\n" >"${ast}"
	fi

	spec_dir=$(dirname -- "${file_path}")
	normalized=$(jq -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "arazzo"; normalize_arazzo_root' "${file_path}")

	jq --argjson norm "${normalized}" '
		. * $norm |
		if .info == null and $norm.arazzoInfo != null then .info = $norm.arazzoInfo else . end
	' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"

	# Resolve local sourceDescriptions (openapi or arazzo) relative to spec_dir
	sd_entries=$(jq -r '.sourceDescriptions[]? | "\(.name)\t\(.type // "openapi")\t\(.url)"' "${ast}")
	if [ -n "${sd_entries}" ]; then
		printf '%s\n' "${sd_entries}" | while IFS='	' read -r sd_name sd_type sd_url; do
			[ -z "${sd_url}" ] && continue
			resolved_path=""
			if [ -f "${spec_dir}/${sd_url}" ]; then
				resolved_path="${spec_dir}/${sd_url}"
			elif [ -f "${sd_url}" ]; then
				resolved_path="${sd_url}"
			fi
			if [ -n "${resolved_path}" ]; then
				if [ "${sd_type}" = "openapi" ]; then
					src_oas=$(jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/swagger2openapi.jq" "${resolved_path}")
					jq --arg name "${sd_name}" --argjson src "${src_oas}" '
						.x_resolved_sources = ((.x_resolved_sources // {}) + {($name): $src}) |
						if .paths == null and $src.paths != null then .paths = $src.paths else . end |
						if .components == null and $src.components != null then .components = $src.components else . end |
						if .servers == null and $src.servers != null then .servers = $src.servers else . end
					' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
				elif [ "${sd_type}" = "arazzo" ]; then
					src_arz=$(jq -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" 'include "arazzo"; normalize_arazzo_root' "${resolved_path}")
					jq --arg name "${sd_name}" --argjson src "${src_arz}" '
						.x_resolved_sources = ((.x_resolved_sources // {}) + {($name): $src})
					' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
				fi
			fi
		done
	fi
}

# handle_parse_arazzo_dir recursively parses all Arazzo and OpenAPI JSON files in a directory into a unified AST.
# @param $1: dir_path - Directory path containing Arazzo and/or OpenAPI specifications.
handle_parse_arazzo_dir() {
	dir_path="$1"
	if [ ! -d "${dir_path}" ]; then
		printf "Error: Directory %s not found\n" "${dir_path}" >&2
		return 1
	fi

	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	printf "{}\n" >"${ast}"

	set +f
	for f in "${dir_path}"/*.json "${dir_path}"/*/*.json "${dir_path}"/*/*/*.json; do
		if [ -f "$f" ]; then
			if jq -e 'has("arazzo") or has("workflows")' "$f" >/dev/null 2>&1; then
				handle_parse_arazzo "$f"
			elif jq -e 'has("openapi") or has("swagger") or has("paths")' "$f" >/dev/null 2>&1; then
				src_oas=$(jq -f "${LIBSCRIPT_ROOT_DIR}/src/openapi/swagger2openapi.jq" "$f")
				jq --argjson src "${src_oas}" '. * $src' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
			fi
		fi
	done
	set -f
}
