#!/bin/sh
# @file src/classes/emit.sh
# @description Emits data class validation and constructor functions from the OpenAPI AST.
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_classes generates data classes and models from the AST.
# @param $1: file_path - The destination path for the generated classes script (default: classes.sh).
handle_emit_classes() {
	file_path="${1:-classes.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n# Auto-generated Data Classes\nset -eu\n\n"
		printf "# get property\n_get_prop() {\n  printf '%%s' \"\$1\" | jq -c \".\\\\\"\$2\\\\\" // empty\"\n}\n\n"
		jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/classes/emit.jq" "${ast}"
	} >"${file_path}.tmp"

	if [ -f "${file_path}" ]; then
		awk -v new_file="${file_path}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" <"${file_path}" >"${file_path}.merged"
		mv "${file_path}.merged" "${file_path}"
		rm -f "${file_path}.tmp"
	else
		mv "${file_path}.tmp" "${file_path}"
	fi
}
