#!/bin/sh
# @file src/server/emit_models.sh
# @description Emits individual model validation scripts for the generated server.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_server_models generates individual model files for the server.
# @param $1: out_dir - The output directory for model scripts (default: models).
handle_emit_server_models() {
	out_dir="${1:-models}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	mkdir -p "${out_dir}"

	{
		printf "#!/bin/sh\n"
		printf "# @file _helpers.sh\n"
		printf "# @description Shared JSON property extraction helper for generated server models.\n"
		printf "# _get_prop extracts a top-level property from a JSON object string.\n"
		printf "# @param \$1: json - Raw JSON object string.\n"
		printf "# @param \$2: key - Property name to extract.\n"
		printf "_get_prop() {\n  printf '%%s' \"\$1\" | jq -r \".\\\\\"\$2\\\\\" | if . == null then empty elif (type == \\\\\"object\\\\\" or type == \\\\\"array\\\\\") then tojson else tostring end\"\n}\n"
	} >"${out_dir}/_helpers.sh"
	chmod +x "${out_dir}/_helpers.sh"

	jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/classes/emit.jq" "${ast}" | awk '
		/^# @class / {
			printf "###FILE###model_%s.sh\n#!/bin/sh\n# @file model_%s.sh\n# @description Generated validation model for %s.\n", $3, $3, $3
		}
		{ print $0 }
	' | emit_split_files "${out_dir}"
}
