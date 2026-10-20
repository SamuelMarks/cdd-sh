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
		printf "#!/bin/sh\n# @file %s\n# @description Auto-generated Data Classes\nset -eu\n\n" "${file_path##*/}"
		printf "# _get_prop extracts a property value from a JSON object string.\n# @param \$1: json - Raw JSON object string.\n# @param \$2: key - Property name.\n_get_prop() {\n  printf '%%s' \"\$1\" | jq -r \".\\\\\"\$2\\\\\" | if . == null then empty elif (type == \\\\\"object\\\\\" or type == \\\\\"array\\\\\") then tojson else tostring end\"\n}\n\n"
		jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/classes/emit.jq" "${ast}"
	} >"${file_path}.tmp"

	merge_or_move_emitted_file "${file_path}" "0"
}
