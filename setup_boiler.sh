#!/bin/sh
# @file setup_boiler.sh
# @description Scaffolds parser and emitter boilerplate scripts in src/.
# shellcheck disable=SC2016,SC2129

set -eu

PRELUDE='#!/bin/sh
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"'

for type in classes docstrings functions mocks openapi routes tests; do
	for cmd in parse emit; do
		f="src/${type}/${cmd}.sh"
		echo "$PRELUDE" >"$f"
		echo "" >>"$f"
		if [ "$cmd" = "parse" ]; then
			echo "# handle_${cmd}_${type} parses ${type} definitions into the AST." >>"$f"
			echo "handle_${cmd}_${type}() {" >>"$f"
			echo '  file_path="${1}"' >>"$f"
			echo "  # Implement parse for ${type}" >>"$f"
			echo "}" >>"$f"
		else
			echo "# handle_${cmd}_${type} emits ${type} artifacts from the AST." >>"$f"
			echo "handle_${cmd}_${type}() {" >>"$f"
			echo '  file_path="${1}"' >>"$f"
			echo "  # Implement emit for ${type}" >>"$f"
			echo "}" >>"$f"
		fi
		chmod +x "$f"
	done
done
