#!/bin/sh
# shellcheck disable=SC3054,SC3040,SC2059,SC2016

set -feu
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
case "${STACK+x}" in *':'"${THIS_FILE}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${THIS_FILE}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${THIS_FILE}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(
	d="${DIR}"
	while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done
	printf '%s' "${d}"
)}"

# handle_parse_docstrings parses docstrings into the AST.
handle_parse_docstrings() {
	file_path="${1:-docs.md}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then echo '{"openapi":"3.2.0"}' >"${ast}"; fi
	if [ ! -f "${file_path}" ]; then return 0; fi

	awk '
	BEGIN { op = ""; desc = ""; info_desc = ""; in_info = 0 }
	/^# / {
	title_ver = substr($0, 3)
	split(title_ver, a, "(")
	title = a[1]; gsub(/ *$/, "", title)
	if (length(a) > 1) { ver = a[2]; gsub(/\)$/, "", ver) }
	in_info = 1
	next
	}
	/^## / {
	if (op != "") { ops[op] = desc; desc = "" }
	if (in_info) { in_info = 0 }
	op = substr($0, 4)
	next
	}
	/^[\*#-]/ { next }
	/^[A-Za-z0-9]/ {
	if (in_info) { info_desc = info_desc $0 "\n" }
	else if (op != "") { desc = desc $0 "\n" }
	}
	END {
	if (op != "") { ops[op] = desc }
	gsub(/\n$/, "", info_desc)
	printf "INFO:{\"title\": \"%s\", \"version\": \"%s\", \"description\": \"%s\"}\n", title, ver, info_desc

	printf "OPS:{"
	first=1
	for (o in ops) {
	  gsub(/\n$/, "", ops[o])
	  if (!first) printf ", "
	  first=0
	  printf "\"%s\": \"%s\"", o, ops[o]
	}
	printf "}\n"
	}
	' <"${file_path}" >all_temp.txt

	awk '/^INFO:/ { print substr($0, 6) }' <all_temp.txt >docs_info.json || true
	awk '/^OPS:/ { print substr($0, 5) }' <all_temp.txt >docs_ops.json || true
	rm -f all_temp.txt
	if [ -f "docs_info.json" ]; then
		jq --slurpfile info docs_info.json --slurpfile ops docs_ops.json '
      .info = ((.info // {}) * $info[0]) |
      (
        if .paths then
          .paths |= with_entries(.value |= with_entries(
            if .value.operationId and $ops[0][.value.operationId] then
              .value.description = $ops[0][.value.operationId]
            else . end
          ))
        else . end
      )
    ' "${ast}" >"${ast}.tmp" && mv "${ast}.tmp" "${ast}"
		rm -f docs_info.json docs_ops.json
	fi
}
