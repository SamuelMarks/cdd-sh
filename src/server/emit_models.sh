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
		printf "# get property\n_get_prop() {\n  printf '%%s' \"\$1\" | jq -c \".\\\\\"\$2\\\\\" // empty\"\n}\n"
	} >"${out_dir}/_helpers.sh"
	chmod +x "${out_dir}/_helpers.sh"

	# We use the existing classes/emit.jq, but split it into multiple files using awk.
	# The output of emit.jq starts a new model with `# @class ModelName`.
	jq -r -f "${LIBSCRIPT_ROOT_DIR}/src/classes/emit.jq" "${ast}" | awk -v out_dir="${out_dir}" '
	  /^# @class / {
          if (out_file != "") { close(out_file) }
          model_name = $3
          out_file = out_dir "/" model_name ".sh"
          print "#!/bin/sh" > out_file
      }
      {
          if (out_file != "") { print $0 >> out_file }
      }
      END {
          if (out_file != "") { close(out_file) }
      }
    '

	for f in "${out_dir}"/*.sh; do
		if [ -f "$f" ]; then chmod +x "$f"; fi
	done
}
