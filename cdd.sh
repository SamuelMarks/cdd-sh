#!/bin/sh
# shellcheck disable=SC1091

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

VERSION="0.0.2"

# usage prints the CLI help message.
print_help() {
	printf "cdd-sh CLI\n"
	printf "Usage:\n  cdd-sh [subcommand] [options]\n\n"
	printf "Subcommands:\n"
	printf "  from_openapi    Generate code from an OpenAPI specification.\n"
	printf "  to_openapi      Generate an OpenAPI specification from source code.\n"
	printf "  to_docs_json    Generate JSON documentation with code snippets for an OpenAPI specification.\n"
	printf "  serve_json_rpc  Expose CLI interface as a JSON-RPC server.\n"
	printf "  mcp             Run as an MCP server over stdio.\n\n"
	printf "Options:\n"
	printf "  --help, -h      Show this help message\n"
	printf "  --version, -v   Show version information\n\n"
	printf "Examples:\n"
	printf "  cdd-sh to_openapi -i <code_file_or_dir> -o <spec.json>\n"
	printf "  cdd-sh serve_json_rpc [-p|--port <port>] [-l|--listen <ip>]\n"
	printf "  cdd-sh to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> -o <docs.json>\n"
	printf "  cdd-sh from_openapi [subcmd] -i <spec.json> -o <target_dir> [--no-github-actions] [--no-installable-package] [--tests]\n"
	printf "  cdd-sh from_openapi [subcmd] --input-dir <specs_dir> -o <target_dir> [--no-github-actions] [--no-installable-package] [--tests]\n\n"
	printf "Note: All options can be passed via environment variables (e.g., CDD_PORT=8082 cdd-sh serve_json_rpc)\n"
	exit 1
}

if [ "$#" -eq 0 ]; then
	usage
fi

CMD="${1}"
shift

if [ "${CMD}" = "-help" ] || [ "${CMD}" = "--help" ]; then
	usage
fi

if [ "${CMD}" = "-version" ] || [ "${CMD}" = "--version" ]; then
	echo "$VERSION"
	exit 0
fi

export CDD_AST_PATH="${CDD_AST_PATH:-ast.json}"

# parse_global_args parses the global arguments passed to the CLI.
parse_global_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-i | --input)
			export CDD_INPUT="$2"
			shift 2
			;;
		-o | --output)
			export CDD_OUTPUT="$2"
			shift 2
			;;
		--input-dir)
			export CDD_INPUT_DIR="$2"
			shift 2
			;;
		--port)
			export CDD_PORT="$2"
			shift 2
			;;
		--listen)
			export CDD_LISTEN="$2"
			shift 2
			;;
		--no-imports)
			export CDD_NO_IMPORTS="1"
			shift 1
			;;
		--no-wrapping)
			export CDD_NO_WRAPPING="1"
			shift 1
			;;
		--no-github-actions)
			export CDD_NO_GITHUB_ACTIONS="1"
			shift 1
			;;
		--no-installable-package)
			export CDD_NO_INSTALLABLE="1"
			shift 1
			;;
		--tests)
			export CDD_TESTS="1"
			shift 1
			;;
		*)
			echo "Unknown arg $1"
			exit 1
			;;
		esac
	done
}

# ensure_output_dir creates the output directory if it does not exist.
ensure_output_dir() {
	if [ -z "${CDD_OUTPUT:-}" ]; then
		CDD_OUTPUT="$(pwd)"
	fi
}

case "${CMD}" in
mcp)
	while read -r line || [ -n "$line" ]; do
		if echo "$line" | grep -qi "^Content-Length:"; then
			read -r _
			content_length=$(echo "$line" | awk '{print $2}' | tr -d '\r\n')
			line=$(dd bs=1 count="$content_length" 2>/dev/null)
		elif echo "$line" | grep -qi "^[A-Za-z-]\+: "; then
			continue
		elif [ -z "$(echo "$line" | tr -d '\r\n')" ]; then
			continue
		fi
		method=$(echo "$line" | jq -r '.method // empty')
		id=$(echo "$line" | jq -r '.id // null')

		if [ "$method" = "initialize" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{\"listChanged\":true},\"resources\":{\"listChanged\":true,\"subscribe\":true},\"logging\":{},\"prompts\":{\"listChanged\":true}},\"serverInfo\":{\"name\":\"cdd-sh\",\"version\":\"$VERSION\"}}}"
		elif [ "$method" = "notifications/initialized" ] || [ "$method" = "initialized" ]; then
			:
		elif [ "$method" = "notifications/tools/list_changed" ] || [ "$method" = "notifications/resources/list_changed" ] || [ "$method" = "notifications/prompts/list_changed" ] || [ "$method" = "notifications/roots/list_changed" ] || [ "$method" = "notifications/resources/updated" ]; then
			:
		elif [ "$method" = "notifications/cancelled" ] || [ "$method" = "notifications/progress" ]; then
			:
		elif [ "$method" = "notifications/message" ]; then
			level=$(echo "$line" | jq -r '.params.level // "info"')
			msg=$(echo "$line" | jq -r '.params.data // ""')
			echo "[$level] $msg" >&2

		elif [ "$method" = "roots/list" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"roots\":[{\"uri\":\"file://$(pwd)\",\"name\":\"Workspace\"}]}}"

		elif [ "$method" = "ping" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
		elif [ "$method" = "prompts/list" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"prompts\":[{\"name\":\"test_prompt\",\"description\":\"A test prompt\",\"arguments\":[{\"name\":\"arg1\",\"description\":\"An argument\",\"required\":true}]}]}}"
		elif [ "$method" = "prompts/get" ]; then
			prompt_name=$(echo "$line" | jq -r '.params.name // empty')
			if [ "$prompt_name" = "test_prompt" ]; then
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"description\":\"A test prompt\",\"messages\":[{\"role\":\"user\",\"content\":{\"type\":\"text\",\"text\":\"Please test this\"}}]}}"
			else
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32602,\"message\":\"Invalid prompt\"}}"
			fi
		elif [ "$method" = "completion/complete" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"completion\":{\"values\":[],\"total\":0,\"hasMore\":false}}}"
		elif [ "$method" = "sampling/createMessage" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"role\":\"assistant\",\"content\":{\"type\":\"text\",\"text\":\"Sampled message\"}\",\"model\":\"test-model\",\"stopReason\":\"endTurn\"}}"
		elif [ "$method" = "logging/setLevel" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
		elif [ "$method" = "resources/list" ]; then
			cursor=$(echo "$line" | jq -r '.params.cursor // empty')
			if [ "$cursor" = "next" ]; then
				res_json='[]'
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resources\":$res_json}}"
			else
				res_json='[{"uri":"cdd://ast","name":"AST","mimeType":"application/json"}]'
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resources\":$res_json,\"nextCursor\":\"next\"}}"
			fi
		elif [ "$method" = "resources/templates/list" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"resourceTemplates\":[]}}"
		elif [ "$method" = "resources/subscribe" ] || [ "$method" = "resources/unsubscribe" ]; then
			echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"

		elif [ "$method" = "resources/read" ]; then
			uri=$(echo "$line" | jq -r '.params.uri')
			if [ "$uri" = "cdd://ast" ]; then
				ast_content=$(cat "$CDD_AST_PATH" 2>/dev/null || echo "{}")
				ast_escaped=$(printf "%s" "$ast_content" | jq -R -s '.')
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"contents\":[{\"uri\":\"cdd://ast\",\"mimeType\":\"application/json\",\"text\":$ast_escaped}]}}"
			else
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32602,\"message\":\"Invalid URI\"}}"
			fi
		elif [ "$method" = "tools/list" ]; then
			tools_json='[
                                {"name":"to_openapi","description":"Generate OpenAPI spec from source","inputSchema":{"type":"object","properties":{"input":{"type":"string"},"output":{"type":"string"}},"required":["input","output"]}},
                                {"name":"from_openapi","description":"Generate code from OpenAPI spec","inputSchema":{"type":"object","properties":{"subcmd":{"type":"string"},"input":{"type":"string"},"output":{"type":"string"},"tests":{"type":"boolean"}},"required":["subcmd","input","output"]}}
                        ]'
			cursor=$(echo "$line" | jq -r '.params.cursor // empty')
			if [ "$cursor" = "next" ]; then echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"tools\":[]}}"; else echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"tools\":$tools_json,\"nextCursor\":\"next\"}}"; fi
		elif [ "$method" = "tools/call" ]; then
			tool_name=$(echo "$line" | jq -r '.params.name')
			args=$(echo "$line" | jq -c '.params.arguments // {}')

			set +e
			if [ "$tool_name" = "to_openapi" ]; then
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				res=$(./bin/cdd-sh to_openapi -i "$input" -o "$output" 2>&1)
			elif [ "$tool_name" = "from_openapi" ]; then
				subcmd=$(echo "$args" | jq -r '.subcmd')
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				if [ "$(echo "$args" | jq -r '.tests // false')" = "true" ]; then
					res=$(./bin/cdd-sh from_openapi "$subcmd" -i "$input" -o "$output" --tests 2>&1)
				else
					res=$(./bin/cdd-sh from_openapi "$subcmd" -i "$input" -o "$output" 2>&1)
				fi
			else
				res="Unknown tool: $tool_name"
				exit_code=1
			fi
			exit_code=$?
			set -e

			res_escaped=$(printf "%s" "$res" | jq -R -s '.')
			if [ "$exit_code" -ne 0 ]; then
				printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":true,"content":[{"type":"text","text":%s}]}}\n' "$id" "$res_escaped"
			else
				printf '{"jsonrpc":"2.0","id":%s,"result":{"isError":false,"content":[{"type":"text","text":%s}]}}\n' "$id" "$res_escaped"
			fi
		else
			if [ "$id" != "null" ]; then
				echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32601,\"message\":\"Method not found\"}}"
			fi
		fi
	done
	;;
serve_json_rpc)
	parse_global_args "$@"
	PORT="${CDD_PORT:-8082}"
	LISTEN="${CDD_LISTEN:-0.0.0.0}"
	echo "Starting JSON-RPC server on ${LISTEN}:${PORT}..."

	# Create a unique FIFO to avoid conflicts
	fifo="/tmp/cdd_rpc_$$"
	mkfifo "$fifo"
	# shellcheck disable=SC2064
	trap "rm -f \"$fifo\"" EXIT INT TERM

	while true; do
		# shellcheck disable=SC2094
		{
			read -r line || true
			line=$(echo "$line" | tr -d '\r\n')
			if [ -z "$line" ]; then exit 0; fi

			# Read headers
			content_length=0
			while read -r header; do
				header=$(echo "$header" | tr -d '\r\n')
				if [ -z "$header" ]; then break; fi
				if echo "$header" | grep -qi "^Content-Length:"; then
					content_length=$(echo "$header" | awk '{print $2}')
				fi
			done

			body=""
			if [ "$content_length" -gt 0 ]; then
				body=$(dd bs=1 count="$content_length" 2>/dev/null)
			fi

			json_method=$(echo "$body" | jq -r '.method // empty')
			json_params=$(echo "$body" | jq -r '.params // []')
			json_id=$(echo "$body" | jq -r '.id // null')

			if [ -n "$json_method" ]; then
				case "$json_method" in
				to_openapi)
					f_val=$(echo "$json_params" | jq -r '.file // ""')
					o_val=$(echo "$json_params" | jq -r '.out // ""')
					out=$(./bin/cdd-sh to_openapi -i "$f_val" -o "$o_val" 2>&1 || true)
					;;
				from_openapi)
					subcmd_val=$(echo "$json_params" | jq -r '.subcmd // "to_sdk"')
					i_val=$(echo "$json_params" | jq -r '.spec // ""')
					o_val=$(echo "$json_params" | jq -r '.out // ""')

					opts=""
					if [ "$(echo "$json_params" | jq -r '.no_github_actions // false')" = "true" ]; then
						opts="$opts --no-github-actions"
					fi
					if [ "$(echo "$json_params" | jq -r '.no_installable_package // false')" = "true" ]; then
						opts="$opts --no-installable-package"
					fi
					if [ "$(echo "$json_params" | jq -r '.tests // .create_composable_tests_mocks // false')" = "true" ]; then
						opts="$opts --tests"
					fi

					# shellcheck disable=SC2086
					out=$(./bin/cdd-sh from_openapi "$subcmd_val" -i "$i_val" -o "$o_val" $opts 2>&1 || true)
					;;
				to_docs_json)
					i_val=$(echo "$json_params" | jq -r '.spec // ""')
					o_val=$(echo "$json_params" | jq -r '.out // ""')
					out=$(./bin/cdd-sh to_docs_json -i "$i_val" -o "$o_val" 2>&1 || true)
					;;
				--version)
					out=$(./bin/cdd-sh --version 2>&1 || true)
					;;
				*)
					out="Unknown method"
					;;
				esac

				response_json=$(jq -n --arg id "$json_id" --arg out "$out" '{"jsonrpc": "2.0", "result": $out, "id": $id}')

				echo "HTTP/1.1 200 OK"
				echo "Content-Type: application/json"
				echo "Content-Length: ${#response_json}"
				echo ""
				echo "$response_json"
			else
				echo "HTTP/1.1 400 Bad Request"
				echo "Content-Type: text/plain"
				echo "Content-Length: 11"
				echo ""
				echo "Bad Request"
			fi
		} <"$fifo" | nc -l "$PORT" >"$fifo" 2>/dev/null || nc -l -p "$PORT" >"$fifo"
	done
	;;
to_openapi)
	parse_global_args "$@"
	FILE="${CDD_INPUT:-}"
	OUT="${CDD_OUTPUT:-spec.json}"
	if [ -z "$FILE" ]; then
		echo "Error: -i <file> required" >&2
		exit 1
	fi
	# if it's a directory, assume the file is routes.sh for now
	if [ -d "$FILE" ]; then
		FILE="$FILE/src/routes.sh"
	fi
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
	handle_parse_routes "$FILE"
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/emit.sh"
	handle_emit_openapi "$OUT"
	echo "Generated OpenAPI spec in $OUT"
	;;
to_docs_json)
	parse_global_args "$@"
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/docsjson/emit.sh"
	handle_to_docs_json "$@"
	;;
from_openapi)
	if [ "$#" -eq 0 ]; then usage; fi
	SUBCMD="to_sdk"
	if [ "$1" != "-i" ] && [ "$1" != "--input-dir" ] && [ "$1" != "-o" ] && [ "$1" != "--no-github-actions" ] && [ "$1" != "--no-installable-package" ] && [ "$1" != "--tests" ]; then
		SUBCMD="$1"
		shift
	fi
	parse_global_args "$@"
	ensure_output_dir
	IN="${CDD_INPUT:-}"
	IN_DIR="${CDD_INPUT_DIR:-}"
	OUT="${CDD_OUTPUT}"

	if [ -z "$IN" ] && [ -z "$IN_DIR" ]; then
		echo "Error: -i or --input-dir required" >&2
		exit 1
	fi

	mkdir -p "$OUT"

	if [ "$SUBCMD" != "to_docs_json" ] && [ "$SUBCMD" != "to_openapi" ]; then
		if [ "${CDD_NO_GITHUB_ACTIONS:-0}" != "1" ]; then
			mkdir -p "$OUT/.github/workflows"
			printf 'name: CI\non: [push, pull_request]\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: echo "Tests..."\n' >"$OUT/.github/workflows/ci.yml"
		fi
	fi

	case "$SUBCMD" in
	to_sdk_cli)
		mkdir -p "$OUT/bin"
		if [ -n "$IN" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			handle_parse_openapi "$IN"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/emit.sh"
			handle_emit_cli "$OUT/bin/sdk-cli" "$OUT"
		fi
		echo "Generated SDK CLI in $OUT"
		;;
	to_sdk)
		mkdir -p "$OUT/src"
		if [ -n "$IN" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			handle_parse_openapi "$IN"

			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/emit.sh"
			handle_emit_routes "$OUT/src/routes.sh" "sdk"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/classes/emit.sh"
			handle_emit_classes "$OUT/src/classes.sh"

			if [ -f "${LIBSCRIPT_ROOT_DIR:-.}/src/sdk/emit.sh" ]; then
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/sdk/emit.sh"
				handle_emit_sdk "$OUT/src/sdk.sh"
			fi

			if [ "${CDD_TESTS:-0}" = "1" ]; then
				mkdir -p "$OUT/tests" "$OUT/mocks"
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/tests/emit.sh"
				handle_emit_tests "$OUT/tests/test_routes.sh" "../src/routes.sh"
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/mocks/emit.sh"
				handle_emit_mocks "$OUT/mocks/mocks.json"
			fi
		fi
		echo "Generated SDK in $OUT"
		;;
	to_server)
		mkdir -p "$OUT/src"
		if [ -n "$IN" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			handle_parse_openapi "$IN"

			# shellcheck disable=SC1091
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit.sh"
			handle_emit_server "$OUT/src/server.sh" "server"
		fi
		echo "Generated Server in $OUT"
		;;
	to_docs_json)
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/docsjson/emit.sh"
		# The WASM SDK will read from OUT. If it prints to stdout, we need to capture it to a file if OUT is provided.
		# But wait, CddWasmSdk expects the files to be in `/out`.
		handle_to_docs_json "$@" >"$OUT/docs.json"
		;;
	to_openapi)
		if [ -d "$IN" ]; then
			IN="$IN/src/routes.sh"
		fi
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
		handle_parse_routes "${IN:-}"
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/emit.sh"
		handle_emit_openapi "$OUT/spec.json"
		;;
	*)
		echo "Unknown from_openapi subcmd: $SUBCMD" >&2
		exit 1
		;;
	esac
	;;
parse | emit | sync)
	TYPE="${1:-}"
	FILE="${2:-}"

	if [ "${CMD}" = "sync" ]; then
		HANDLER="${LIBSCRIPT_ROOT_DIR:-.}/src/${TYPE}/parse.sh"
	else
		HANDLER="${LIBSCRIPT_ROOT_DIR:-.}/src/${TYPE}/${CMD}.sh"
	fi
	if [ ! -f "${HANDLER}" ]; then
		printf "Error: Unsupported type '%s' or handler missing (%s)\n" "${TYPE}" "${HANDLER}" >&2
		exit 1
	fi

	SCRIPT_NAME="${HANDLER}"
	export SCRIPT_NAME
	# shellcheck disable=SC1090
	. "${HANDLER}"

	if [ "${CMD}" = "sync" ]; then
		"handle_parse_${TYPE}" "${FILE}"
		for t in openapi routes classes docstrings tests mocks docsjson; do
			h="${LIBSCRIPT_ROOT_DIR:-.}/src/${t}/emit.sh"
			if [ -f "$h" ]; then
				# shellcheck disable=SC1090
				. "$h"
				ext="sh"
				if [ "$t" = "openapi" ] || [ "$t" = "mocks" ] || [ "$t" = "docsjson" ]; then ext="json"; fi
				if [ "$t" = "docstrings" ]; then ext="md"; fi
				"handle_emit_${t}" "emitted_${t}.${ext}"
			fi
		done
	else
		"handle_${CMD}_${TYPE}" "${FILE}"
	fi
	;;
*)
	echo "Unknown command: $CMD" >&2
	usage
	;;
esac
