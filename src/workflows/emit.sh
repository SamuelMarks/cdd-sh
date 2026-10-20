#!/bin/sh
# @file src/workflows/emit.sh
# @description Emits POSIX shell workflow orchestrators and input validators from the Arazzo AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/arazzo_runtime.sh"

# handle_emit_workflows generates the workflows.sh SDK script from the unified AST.
# @param $1: file_path - The destination path for the generated workflows script (default: workflows.sh).
handle_emit_workflows() {
	file_path="${1:-workflows.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then
		printf "Error: AST file not found at %s\n" "${ast}" >&2
		return 1
	fi

	{
		printf "#!/bin/sh\n"
		printf "# @file %s\n" "${file_path##*/}"
		printf "# @description Auto-generated Arazzo 1.1.0 workflow orchestrators for POSIX shell.\n"
		printf "# shellcheck disable=SC2016,SC1091\n"
		printf "# @arazzo_workflows_start\n"
		cat <<'INNER_EOF'
_WF_DIR="$(cd "$(dirname -- "$0")" && pwd)"
if [ -f "${_WF_DIR}/routes.sh" ]; then
  # shellcheck disable=SC1091
  . "${_WF_DIR}/routes.sh"
fi
if [ -f "${_WF_DIR}/classes.sh" ]; then
  # shellcheck disable=SC1091
  . "${_WF_DIR}/classes.sh"
fi
if [ -f "${_WF_DIR}/sdk.sh" ]; then
  # shellcheck disable=SC1091
  . "${_WF_DIR}/sdk.sh"
fi
INNER_EOF
		printf "\n"
		emit_arazzo_runtime_func
		printf "\n"
		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" -f "${LIBSCRIPT_ROOT_DIR}/src/workflows/emit.jq" "${ast}"
		printf "# @arazzo_workflows_end\n"
	} >"${file_path}.tmp"

	merge_or_move_emitted_file "${file_path}" "1"
}
