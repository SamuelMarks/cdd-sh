#!/bin/sh
set -feu
if [ "${SCRIPT_NAME-}" ]; then this_file="${SCRIPT_NAME}"; elif [ "${BASH_SOURCE-}" ]; then
	this_file="${BASH_SOURCE[0]}"
	set -o pipefail
else this_file="${0}"; fi
case "${STACK+x}" in *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;; esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd "$(dirname -- "${this_file}")" && pwd)
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
       printf "{\"title\": \"%s\", \"version\": \"%s\", \"description\": \"%s\"}\n", title, ver, info_desc > "docs_info.json"
       
       printf "{" > "docs_ops.json"
       first=1
       for (o in ops) {
          gsub(/\n$/, "", ops[o])
          if (!first) printf ", " > "docs_ops.json"
          first=0
          printf "\"%s\": \"%s\"", o, ops[o] > "docs_ops.json"
       }
       printf "}\n" > "docs_ops.json"
    }
  ' "${file_path}"

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
