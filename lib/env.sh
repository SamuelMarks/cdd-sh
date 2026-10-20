#!/bin/sh
# @file lib/env.sh
# @description Shared POSIX shell initialization, stack tracking, LIBSCRIPT_ROOT_DIR resolution, and emitter file helpers.
set -eu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	THIS_FILE="${BASH_SOURCE[0]}"
	set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
	eval 'THIS_FILE="${(%):-%x}"'
	set -o pipefail
else
	THIS_FILE="${0}"
fi
export STACK="${STACK:-}${THIS_FILE:-env.sh}:"
if [ -z "${LIBSCRIPT_ROOT_DIR:-}" ]; then
	if [ -f "./ROOT" ]; then
		LIBSCRIPT_ROOT_DIR="."
	else
		DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
		LIBSCRIPT_ROOT_DIR=$(
			d="${DIR}"
			while [ ! -f "${d}/ROOT" ] && [ "${d}" != "/" ]; do d="$(dirname -- "${d}")"; done
			printf '%s' "${d}"
		)
	fi
fi
export LIBSCRIPT_ROOT_DIR

# merge_or_move_emitted_file merges `${file_path}.tmp` into an existing `${file_path}` via `merge.awk` or moves it into place.
# @param $1: file_path - Destination file path.
# @param $2: make_exec - Optional "1" to mark the output file executable.
# @return Returns 0 on success.
merge_or_move_emitted_file() {
	_m_path="$1"
	_m_exec="${2:-0}"
	if [ -f "${_m_path}" ]; then
		awk -v new_file="${_m_path}.tmp" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/merge.awk" <"${_m_path}" >"${_m_path}.merged"
		mv "${_m_path}.merged" "${_m_path}"
		rm -f "${_m_path}.tmp"
	else
		mv "${_m_path}.tmp" "${_m_path}"
	fi
	if [ "${_m_exec}" = "1" ]; then
		chmod +x "${_m_path}"
	fi
}

# emit_split_files reads a `###FILE###<filename>` stream from stdin, splits it into `out_dir`, and marks `.sh` files executable.
# @param $1: out_dir - Target directory for the split files.
# @return Returns 0 on success.
emit_split_files() {
	_split_dir="$1"
	mkdir -p "${_split_dir}"
	awk -v dir="${_split_dir}" -f "${LIBSCRIPT_ROOT_DIR}/lib/_common/split_files.awk"
	set +f
	for _split_f in "${_split_dir}"/*.sh; do
		if [ -f "${_split_f}" ]; then
			chmod +x "${_split_f}"
		fi
	done
	set -f
}
