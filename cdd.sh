#!/bin/sh
# @file cdd.sh
# @description Main CLI entrypoint and subcommand router for cdd-sh (Compiler-Driven Development for POSIX Shell).
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

VERSION="0.0.4"

# print_help prints the CLI help message and exits with status 1.
# @param none
print_help() {
	printf "cdd-sh CLI\n"
	printf "Usage:\n  cdd-sh [subcommand] [options]\n\n"
	printf "Subcommands:\n"
	printf "  from_openapi    Generate code from an OpenAPI specification.\n"
	printf "  to_openapi      Generate an OpenAPI specification from source code.\n"
	printf "  from_arazzo     Generate workflow SDK, CLI, or Server from an Arazzo 1.1.0 specification.\n"
	printf "  to_arazzo       Generate an Arazzo 1.1.0 specification from source code or tests.\n"
	printf "  sync            Synchronize source code, tests, docs, and specifications in-place.\n"
	printf "  to_docs_json    Generate JSON documentation with code snippets for an OpenAPI/Arazzo specification.\n"
	printf "  serve_json_rpc  Expose CLI interface as a JSON-RPC server.\n"
	printf "  mcp             Run as an MCP server over stdio.\n"
	printf "  parse           Parse a source file or specification into the unified AST (ast.json).\n"
	printf "  emit            Emit a target source file or specification from the unified AST (ast.json).\n\n"
	printf "Options:\n"
	printf "  --help, -h      Show this help message\n"
	printf "  --version, -v   Show version information\n\n"
	printf "Examples:\n"
	printf "  cdd-sh to_openapi -i <code_file_or_dir> -o <spec.json>\n"
	printf "  cdd-sh to_arazzo -i <code_file_or_dir> -o <arazzo.json>\n"
	printf "  cdd-sh sync [--truth <source>] -i <code_file_or_dir> -o <target_dir>\n"
	printf "  cdd-sh serve_json_rpc [-p|--port <port>] [-l|--listen <ip>]\n"
	printf "  cdd-sh to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> -o <docs.json>\n"
	printf "  cdd-sh from_openapi [subcmd] -i <spec.json> -o <target_dir> [--no-github-actions] [--no-installable-package] [--tests]\n"
	printf "  cdd-sh from_arazzo [subcmd] -i <arazzo.json> -o <target_dir> [--no-github-actions] [--no-installable-package] [--tests]\n\n"
	printf "Note: All options can be passed via environment variables (e.g., CDD_PORT=8082 cdd-sh serve_json_rpc)\n"
	exit 1
}

# print_help_from_openapi prints usage instructions for the from_openapi subcommand and exits.
# @param none
print_help_from_openapi() {
	printf "Usage:\n  cdd-sh from_openapi [subcmd] [options]\n\n"
	printf "Subcommands:\n"
	printf "  to_sdk          Generate a client SDK.\n"
	printf "  to_sdk_cli      Generate a client SDK and CLI.\n"
	printf "  to_server       Generate server boilerplate, models, and routes.\n"
	printf "  to_openapi      Extract OpenAPI spec from an existing codebase.\n"
	printf "  to_docs_json    Extract documentation data structure.\n\n"
	printf "Options:\n"
	printf "  -i, --input <spec>             Path to the OpenAPI specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions (e.g., package.json).\n"
	printf "  --tests                        Generate unit tests alongside the code.\n"
	printf "  --ephemeral                    (Server) Use ephemeral in-memory storage.\n"
	printf "  --seed                         (Server) Seed the database on startup.\n"
	printf "  --strict-validation            (Server) Enforce strict OpenAPI request validation.\n"
	printf "  --enforce-auth                 (Server) Enforce authentication for all endpoints.\n"
	printf "  --start-auth-server            (Server) Start an embedded authentication server.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_openapi_to_sdk prints usage instructions for the from_openapi to_sdk subcommand and exits.
# @param none
print_help_from_openapi_to_sdk() {
	printf "Usage:\n  cdd-sh from_openapi to_sdk [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell client SDK (src/routes.sh, src/classes.sh, src/sdk.sh) from an OpenAPI specification.\n\n"
	printf "Options:\n"
	printf "  -i, --input <spec>             Path to the OpenAPI specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate route unit tests and mocks alongside the SDK.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_openapi_to_sdk_cli prints usage instructions for the from_openapi to_sdk_cli subcommand and exits.
# @param none
print_help_from_openapi_to_sdk_cli() {
	printf "Usage:\n  cdd-sh from_openapi to_sdk_cli [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell CLI and MCP stdio client (bin/sdk-cli) from an OpenAPI specification.\n\n"
	printf "Options:\n"
	printf "  -i, --input <spec>             Path to the OpenAPI specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate CLI tests alongside the code.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_openapi_to_server prints usage instructions for the from_openapi to_server subcommand and exits.
# @param none
print_help_from_openapi_to_server() {
	printf "Usage:\n  cdd-sh from_openapi to_server [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell HTTP and MCP SSE server (src/server.sh, src/routes/router.sh, src/models/*.sh, src/mocks/*.sh) from an OpenAPI specification.\n\n"
	printf "Options:\n"
	printf "  -i, --input <spec>             Path to the OpenAPI specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate server integration tests.\n"
	printf "  --ephemeral                    Use ephemeral in-memory/temp SQLite storage.\n"
	printf "  --seed                         Seed the database with Faker data on startup.\n"
	printf "  --strict-validation            Enforce strict OpenAPI request validation.\n"
	printf "  --enforce-auth                 Enforce authentication for all endpoints.\n"
	printf "  --start-auth-server            Start an embedded authentication server.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_to_openapi prints usage instructions for the to_openapi subcommand and exits.
# @param none
print_help_to_openapi() {
	printf "Usage:\n  cdd-sh to_openapi [options]\n\n"
	printf "Options:\n"
	printf "  -i, --input <code_file_or_dir> Path to the source code directory or file to parse.\n"
	printf "  -o, --output <spec.json>       Destination path for the generated OpenAPI spec.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_arazzo prints usage instructions for the from_arazzo subcommand and exits.
# @param none
print_help_from_arazzo() {
	printf "Usage:\n  cdd-sh from_arazzo [subcmd] [options]\n\n"
	printf "Subcommands:\n"
	printf "  to_sdk          Generate a client workflow SDK (src/workflows.sh + linked routes/classes).\n"
	printf "  to_sdk_cli      Generate a client workflow SDK and CLI runner (bin/sdk-cli).\n"
	printf "  to_server       Generate server with stateful workflow mocks and E2E workflow tests.\n"
	printf "  to_arazzo       Extract Arazzo 1.1.0 spec from an existing codebase.\n"
	printf "  to_docs_json    Extract documentation data structure with workflow snippets.\n\n"
	printf "Options:\n"
	printf "  -i, --input <arazzo.json>      Path to the Arazzo 1.1.0 specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing Arazzo and OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate E2E workflow tests alongside the code.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_arazzo_to_sdk prints usage instructions for the from_arazzo to_sdk subcommand and exits.
# @param none
print_help_from_arazzo_to_sdk() {
	printf "Usage:\n  cdd-sh from_arazzo to_sdk [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell workflow SDK (src/workflows.sh and linked OpenAPI routes/classes) from an Arazzo 1.1.0 specification.\n\n"
	printf "Options:\n"
	printf "  -i, --input <arazzo.json>      Path to the Arazzo 1.1.0 specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing Arazzo and OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate E2E workflow tests alongside the SDK.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_arazzo_to_sdk_cli prints usage instructions for the from_arazzo to_sdk_cli subcommand and exits.
# @param none
print_help_from_arazzo_to_sdk_cli() {
	printf "Usage:\n  cdd-sh from_arazzo to_sdk_cli [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell workflow CLI runner and MCP workflow server (bin/sdk-cli) from an Arazzo 1.1.0 specification.\n\n"
	printf "Options:\n"
	printf "  -i, --input <arazzo.json>      Path to the Arazzo 1.1.0 specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing Arazzo and OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate CLI workflow tests alongside the code.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_from_arazzo_to_server prints usage instructions for the from_arazzo to_server subcommand and exits.
# @param none
print_help_from_arazzo_to_server() {
	printf "Usage:\n  cdd-sh from_arazzo to_server [options]\n\n"
	printf "Description:\n  Generate a POSIX Shell server with stateful Arazzo workflow mock endpoints (/_mock/workflows) and E2E workflow tests.\n\n"
	printf "Options:\n"
	printf "  -i, --input <arazzo.json>      Path to the Arazzo 1.1.0 specification file.\n"
	printf "  -d, --input-dir <dir>          Path to a directory containing Arazzo and OpenAPI specification files.\n"
	printf "  -o, --output <target_dir>      Destination path for generation.\n"
	printf "  --no-github-actions            Skip generating GitHub Actions CI workflow.\n"
	printf "  --no-installable-package       Skip generating package definitions.\n"
	printf "  --tests                        Generate E2E workflow tests alongside the server.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_to_arazzo prints usage instructions for the to_arazzo subcommand and exits.
# @param none
print_help_to_arazzo() {
	printf "Usage:\n  cdd-sh to_arazzo [options]\n\n"
	printf "Options:\n"
	printf "  -i, --input <code_file_or_dir> Path to the workflow script, CLI, server, or directory to parse.\n"
	printf "  -o, --output <arazzo.json>     Destination path for the generated Arazzo 1.1.0 spec.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_sync prints usage instructions for the sync subcommand and exits.
# @param none
print_help_sync() {
	printf "Usage:\n  cdd-sh sync [options]\n\n"
	printf "Description:\n  Synchronize POSIX Shell source artifacts, documentation, tests, mocks, and OpenAPI/Arazzo specifications from a designated source of truth.\n\n"
	printf "Options:\n"
	printf "  --truth <source>               Source of truth (server, routes, classes, workflows, cli, openapi, arazzo, docstrings, tests, mocks; default: server).\n"
	printf "  -i, --input <file>             Path to the input source of truth file.\n"
	printf "  -o, --output <target_dir>      Destination directory for synchronized artifacts.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_to_docs_json prints usage instructions for the to_docs_json subcommand and exits.
# @param none
print_help_to_docs_json() {
	printf "Usage:\n  cdd-sh to_docs_json [options]\n\n"
	printf "Options:\n"
	printf "  -i, --input <spec.json>        Path to the OpenAPI or Arazzo specification file.\n"
	printf "  -o, --output <docs.json>       Destination path for the documentation data.\n"
	printf "  --no-imports                   Do not include import statements in generated snippets.\n"
	printf "  --no-wrapping                  Do not wrap the output in a top-level documentation object.\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_serve_json_rpc prints usage instructions for the serve_json_rpc subcommand and exits.
# @param none
print_help_serve_json_rpc() {
	printf "Usage:\n  cdd-sh serve_json_rpc [options]\n\n"
	printf "Options:\n"
	printf "  -p, --port <port>              Port to listen on (default: 8082).\n"
	printf "  -l, --listen <ip>              IP to listen on (default: 0.0.0.0).\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_mcp prints usage instructions for the mcp stdio server subcommand and exits.
# @param none
print_help_mcp() {
	printf "Usage:\n  cdd-sh mcp [options]\n\n"
	printf "Description:\n"
	printf "  Run the cdd-sh CLI as a Model Context Protocol (MCP) server over standard I/O.\n\n"
	printf "Options:\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_parse prints usage instructions for the parse subcommand and exits.
# @param none
print_help_parse() {
	printf "Usage:\n  cdd-sh parse <type> <file>\n\n"
	printf "Description:\n  Parse a specification or POSIX Shell artifact into the unified AST (ast.json).\n\n"
	printf "Types:\n"
	printf "  openapi                        Parse an OpenAPI 3.x or Swagger 2.0 JSON specification.\n"
	printf "  arazzo                         Parse an Arazzo 1.0.1 / 1.1.0 JSON specification.\n"
	printf "  routes                         Parse a client routes script (routes.sh).\n"
	printf "  classes                        Parse a schema data models script (classes.sh).\n"
	printf "  workflows                      Parse an Arazzo workflow orchestrator script (workflows.sh).\n"
	printf "  server                         Parse a generated HTTP/MCP server script (server.sh).\n"
	printf "  cli                            Parse a generated SDK CLI script (bin/sdk-cli).\n"
	printf "  functions                      Parse standalone utility functions (functions.sh).\n"
	printf "  docstrings                     Parse Markdown API documentation (docs.md).\n"
	printf "  tests                          Parse route unit test scripts (test_routes.sh).\n"
	printf "  mocks                          Parse mock response JSON payloads (mocks.json).\n\n"
	printf "Options:\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

# print_help_emit prints usage instructions for the emit subcommand and exits.
# @param none
print_help_emit() {
	printf "Usage:\n  cdd-sh emit <type> <file>\n\n"
	printf "Description:\n  Emit a specification or POSIX Shell artifact from the unified AST (ast.json).\n\n"
	printf "Types:\n"
	printf "  openapi                        Emit an OpenAPI 3.2.0 (or Swagger 2.0 via CDD_EMIT_SWAGGER2=1) JSON specification.\n"
	printf "  arazzo                         Emit an Arazzo 1.1.0 JSON specification.\n"
	printf "  routes                         Emit a client HTTP routes script (routes.sh).\n"
	printf "  classes                        Emit a schema data models & validation script (classes.sh).\n"
	printf "  workflows                      Emit an Arazzo workflow orchestrator script (workflows.sh).\n"
	printf "  sdk                            Emit an MCP & Auth client SDK script (sdk.sh).\n"
	printf "  server                         Emit an HTTP & MCP SSE server entrypoint script (server.sh).\n"
	printf "  cli                            Emit a client CLI & workflow runner script (bin/sdk-cli).\n"
	printf "  functions                      Emit standalone utility functions (functions.sh).\n"
	printf "  docstrings                     Emit Markdown API documentation (docs.md).\n"
	printf "  docsjson                       Emit documentation code-snippet JSON (docs.json).\n"
	printf "  tests                          Emit route contract test scripts (test_routes.sh).\n"
	printf "  mocks                          Emit mock response JSON and curl override scripts (mocks.json, mocks.sh).\n\n"
	printf "Options:\n"
	printf "  --help, -h                     Show this help message.\n"
	exit 1
}

if [ "$#" -eq 0 ]; then
	print_help
fi

CMD="${1}"
shift

if [ "${CMD}" = "-help" ] || [ "${CMD}" = "--help" ] || [ "${CMD}" = "-h" ]; then
	print_help
fi

has_help=0
for arg in "$@"; do
	case "$arg" in
	--help | -help | -h)
		has_help=1
		break
		;;
	esac
done

if [ "$has_help" -eq 1 ]; then
	case "${CMD}" in
	from_openapi)
		case "${1:-}" in
		to_sdk) print_help_from_openapi_to_sdk ;;
		to_sdk_cli) print_help_from_openapi_to_sdk_cli ;;
		to_server) print_help_from_openapi_to_server ;;
		*) print_help_from_openapi ;;
		esac
		;;
	to_openapi) print_help_to_openapi ;;
	from_arazzo)
		case "${1:-}" in
		to_sdk) print_help_from_arazzo_to_sdk ;;
		to_sdk_cli) print_help_from_arazzo_to_sdk_cli ;;
		to_server) print_help_from_arazzo_to_server ;;
		*) print_help_from_arazzo ;;
		esac
		;;
	to_arazzo) print_help_to_arazzo ;;
	sync) print_help_sync ;;
	to_docs_json) print_help_to_docs_json ;;
	serve_json_rpc) print_help_serve_json_rpc ;;
	mcp) print_help_mcp ;;
	parse) print_help_parse ;;
	emit) print_help_emit ;;
	*) print_help ;;
	esac
fi

if [ "${CMD}" = "-version" ] || [ "${CMD}" = "--version" ] || [ "${CMD}" = "-v" ] || [ "${CMD}" = "-V" ]; then
	echo "$VERSION"
	exit 0
fi

export CDD_AST_PATH="${CDD_AST_PATH:-ast.json}"

# parse_global_args parses the global arguments passed to the CLI.
# @param $@: Command-line arguments.
parse_global_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		--truth)
			export CDD_TRUTH="$2"
			shift 2
			;;
		-i | -f | --input)
			export CDD_INPUT="$2"
			shift 2
			;;
		-o | --output)
			export CDD_OUTPUT="$2"
			shift 2
			;;
		-d | --input-dir)
			export CDD_INPUT_DIR="$2"
			shift 2
			;;
		-p | --port)
			export CDD_PORT="$2"
			shift 2
			;;
		-l | --listen)
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
		--ephemeral)
			export CDD_EPHEMERAL="1"
			shift 1
			;;
		--seed)
			export CDD_SEED="1"
			shift 1
			;;
		--strict-validation)
			export CDD_STRICT_VALIDATION="1"
			shift 1
			;;
		--enforce-auth)
			export CDD_ENFORCE_AUTH="1"
			shift 1
			;;
		--start-auth-server)
			export CDD_START_AUTH_SERVER="1"
			shift 1
			;;
		--no-github-actions)
			export CDD_NO_GITHUB_ACTIONS="1"
			shift 1
			;;
		--no-installable-package)
			export CDD_NO_INSTALLABLE="1"
			export CDD_NO_INSTALLABLE_PACKAGE="1"
			shift 1
			;;
		-t | --tests)
			export CDD_TESTS="1"
			shift 1
			;;
		-m | --mcp)
			export CDD_MCP="1"
			shift 1
			;;
		*)
			echo "Unknown arg $1"
			exit 1
			;;
		esac
	done
}

# ensure_output_dir sets CDD_OUTPUT to the current working directory if not already defined.
# @param none
ensure_output_dir() {
	if [ -z "${CDD_OUTPUT:-}" ]; then
		CDD_OUTPUT="$(pwd)"
	fi
}

case "${CMD}" in
mcp)
	. "${LIBSCRIPT_ROOT_DIR:-.}/lib/mcp_handler.sh"
	tools_json='[{"name":"to_openapi","description":"Generate OpenAPI spec from source","inputSchema":{"type":"object","properties":{"input":{"type":"string"},"output":{"type":"string"}},"required":["input","output"]}},{"name":"from_openapi","description":"Generate code from OpenAPI spec","inputSchema":{"type":"object","properties":{"subcmd":{"type":"string"},"input":{"type":"string"},"output":{"type":"string"},"tests":{"type":"boolean"}},"required":["subcmd","input","output"]}},{"name":"to_arazzo","description":"Generate Arazzo 1.1.0 spec from source","inputSchema":{"type":"object","properties":{"input":{"type":"string"},"output":{"type":"string"}},"required":["input","output"]}},{"name":"from_arazzo","description":"Generate code from Arazzo 1.1.0 spec","inputSchema":{"type":"object","properties":{"subcmd":{"type":"string"},"input":{"type":"string"},"output":{"type":"string"},"tests":{"type":"boolean"}},"required":["subcmd","input","output"]}}]'
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
		ast_content=$(cat "$CDD_AST_PATH" 2>/dev/null || echo "{}")

		if mcp_out=$(mcp_handle_common "$line" "cdd-sh" "$VERSION" "cdd://ast" "AST" "$ast_content" "$tools_json" "file://$(pwd)"); then
			if [ -n "$mcp_out" ]; then
				printf '%s\n' "$mcp_out"
			fi
		elif [ "$method" = "tools/call" ]; then
			tool_name=$(echo "$line" | jq -r '.params.name')
			args=$(echo "$line" | jq -c '.params.arguments // {}')

			set +e
			if [ "$tool_name" = "to_openapi" ]; then
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" to_openapi -i "$input" -o "$output" 2>&1)
				exit_code=$?
			elif [ "$tool_name" = "from_openapi" ]; then
				subcmd=$(echo "$args" | jq -r '.subcmd')
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				if [ "$(echo "$args" | jq -r '.tests // false')" = "true" ]; then
					res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_openapi "$subcmd" -i "$input" -o "$output" --tests 2>&1)
				else
					res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_openapi "$subcmd" -i "$input" -o "$output" 2>&1)
				fi
				exit_code=$?
			elif [ "$tool_name" = "to_arazzo" ]; then
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" to_arazzo -i "$input" -o "$output" 2>&1)
				exit_code=$?
			elif [ "$tool_name" = "from_arazzo" ]; then
				subcmd=$(echo "$args" | jq -r '.subcmd')
				input=$(echo "$args" | jq -r '.input')
				output=$(echo "$args" | jq -r '.output')
				if [ "$(echo "$args" | jq -r '.tests // false')" = "true" ]; then
					res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_arazzo "$subcmd" -i "$input" -o "$output" --tests 2>&1)
				else
					res=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_arazzo "$subcmd" -i "$input" -o "$output" 2>&1)
				fi
				exit_code=$?
			else
				res="Unknown tool: $tool_name"
				exit_code=1
			fi
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
					case "$f_val" in
					*.json)
						out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" parse openapi "$f_val" 2>&1 && sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" emit openapi "$o_val" 2>&1 || true)
						;;
					*)
						out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" to_openapi -i "$f_val" -o "$o_val" 2>&1 || true)
						;;
					esac
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
					out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_openapi "$subcmd_val" -i "$i_val" -o "$o_val" $opts 2>&1 || true)
					;;
				to_arazzo)
					f_val=$(echo "$json_params" | jq -r '.file // .input // ""')
					o_val=$(echo "$json_params" | jq -r '.out // .output // ""')
					out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" to_arazzo -i "$f_val" -o "$o_val" 2>&1 || true)
					;;
				from_arazzo)
					subcmd_val=$(echo "$json_params" | jq -r '.subcmd // "to_sdk"')
					i_val=$(echo "$json_params" | jq -r '.spec // .input // ""')
					o_val=$(echo "$json_params" | jq -r '.out // .output // ""')
					opts=""
					if [ "$(echo "$json_params" | jq -r '.tests // false')" = "true" ]; then
						opts="$opts --tests"
					fi
					# shellcheck disable=SC2086
					out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" from_arazzo "$subcmd_val" -i "$i_val" -o "$o_val" $opts 2>&1 || true)
					;;
				to_docs_json)
					i_val=$(echo "$json_params" | jq -r '.spec // ""')
					o_val=$(echo "$json_params" | jq -r '.out // ""')
					out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" to_docs_json -i "$i_val" -o "$o_val" 2>&1 || true)
					;;
				--version)
					out=$(sh "${LIBSCRIPT_ROOT_DIR:-.}/cdd.sh" --version 2>&1 || true)
					;;
				*)
					out="Unknown method"
					;;
				esac

				if [ "$out" = "Unknown method" ]; then
					response_json=$(jq -n --arg id "$json_id" '{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": $id}')
				else
					response_json=$(jq -n --arg id "$json_id" --arg out "$out" '{"jsonrpc": "2.0", "result": $out, "id": $id}')
				fi

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
	if [ -d "$FILE" ]; then
		if [ -f "$FILE/src/routes.sh" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
			handle_parse_routes "$FILE/src/routes.sh"
		fi
		if [ -f "$FILE/src/classes.sh" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/classes/parse.sh"
			handle_parse_classes "$FILE/src/classes.sh"
		fi
		if [ -f "$FILE/src/server.sh" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/parse.sh"
			handle_parse_server "$FILE/src/server.sh"
		fi
		if [ -f "$FILE/bin/sdk-cli" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/parse.sh"
			handle_parse_cli "$FILE/bin/sdk-cli"
		fi
		if [ -f "$FILE/mocks/mocks.json" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/mocks/parse.sh"
			handle_parse_mocks "$FILE/mocks/mocks.json"
		fi
		if [ -f "$FILE/docs.md" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/docstrings/parse.sh"
			handle_parse_docstrings "$FILE/docs.md"
		fi
	else
		case "$FILE" in
		*server.sh)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/parse.sh"
			handle_parse_server "$FILE"
			;;
		*classes.sh)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/classes/parse.sh"
			handle_parse_classes "$FILE"
			;;
		*sdk-cli*)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/parse.sh"
			handle_parse_cli "$FILE"
			;;
		*mocks.json)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/mocks/parse.sh"
			handle_parse_mocks "$FILE"
			;;
		*.md)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/docstrings/parse.sh"
			handle_parse_docstrings "$FILE"
			;;
		*.json)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			handle_parse_openapi "$FILE"
			;;
		*)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
			handle_parse_routes "$FILE"
			;;
		esac
	fi
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/emit.sh"
	handle_emit_openapi "$OUT"
	echo "Generated OpenAPI spec in $OUT"
	;;
to_arazzo)
	parse_global_args "$@"
	FILE="${CDD_INPUT:-}"
	OUT="${CDD_OUTPUT:-arazzo.json}"
	if [ -z "$FILE" ]; then
		echo "Error: -i <file> required" >&2
		exit 1
	fi
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/workflows/parse.sh"
	if [ -d "$FILE" ]; then
		if [ -f "$FILE/src/workflows.sh" ]; then
			handle_parse_workflows "$FILE/src/workflows.sh"
		fi
		if [ -f "$FILE/bin/sdk-cli" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/parse.sh"
			handle_parse_cli "$FILE/bin/sdk-cli"
		fi
		if [ -f "$FILE/src/server.sh" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/parse.sh"
			handle_parse_server "$FILE/src/server.sh"
		fi
		if [ -f "$FILE/tests/test_routes.sh" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/tests/parse.sh"
			handle_parse_tests "$FILE/tests/test_routes.sh"
		fi
	else
		case "$FILE" in
		*workflows.sh)
			handle_parse_workflows "$FILE"
			;;
		*sdk-cli*)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/parse.sh"
			handle_parse_cli "$FILE"
			;;
		*server.sh)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/parse.sh"
			handle_parse_server "$FILE"
			;;
		test_*.sh | */test_*.sh)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/tests/parse.sh"
			handle_parse_tests "$FILE"
			;;
		*.json)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/arazzo/parse.sh"
			handle_parse_arazzo "$FILE"
			;;
		*)
			handle_parse_workflows "$FILE"
			;;
		esac
	fi
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/arazzo/emit.sh"
	handle_emit_arazzo "$OUT"
	echo "Generated Arazzo spec in $OUT"
	;;
to_docs_json)
	parse_global_args "$@"
	. "${LIBSCRIPT_ROOT_DIR:-.}/src/docsjson/emit.sh"
	handle_to_docs_json "$@"
	;;
from_openapi)
	if [ "$#" -eq 0 ]; then print_help; fi
	SUBCMD="to_sdk"
	case "${1:-}" in
	-*) ;;
	*)
		SUBCMD="$1"
		shift
		;;
	esac
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
		if [ -n "$IN" ] || [ -n "$IN_DIR" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			if [ -n "$IN" ]; then
				handle_parse_openapi "$IN"
			else
				handle_parse_openapi_dir "$IN_DIR"
			fi
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/emit.sh"
			handle_emit_cli "$OUT/bin/sdk-cli" "$OUT"
		fi
		echo "Generated SDK CLI in $OUT"
		;;
	to_sdk)
		mkdir -p "$OUT/src"
		if [ -n "$IN" ] || [ -n "$IN_DIR" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			if [ -n "$IN" ]; then
				handle_parse_openapi "$IN"
			else
				handle_parse_openapi_dir "$IN_DIR"
			fi

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
		if [ -n "$IN" ] || [ -n "$IN_DIR" ]; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/parse.sh"
			if [ -n "$IN" ]; then
				handle_parse_openapi "$IN"
			else
				handle_parse_openapi_dir "$IN_DIR"
			fi

			# Emit Server Models
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_models.sh"
			handle_emit_server_models "$OUT/src/models"

			# Emit Server DAOs (Mocks)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_daos.sh"
			handle_emit_server_daos "$OUT/src/mocks"

			# Emit Server Routes
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_routes.sh"
			handle_emit_server_routes "$OUT/src/routes"

			# Emit Server Entrypoint
			# shellcheck disable=SC1091
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit.sh"
			handle_emit_server "$OUT/src/server.sh" "server"

			# Emit Server Tests
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_tests.sh"
			handle_emit_server_tests "$OUT/tests"
		fi
		echo "Generated Server in $OUT"
		;;
	to_docs_json)
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/docsjson/emit.sh"
		handle_to_docs_json -i "$IN" -o "$OUT/docs.json"
		;;
	to_openapi)
		if [ -d "$IN" ]; then
			if [ -f "$IN/src/routes.sh" ]; then
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
				handle_parse_routes "$IN/src/routes.sh"
			fi
			if [ -f "$IN/src/classes.sh" ]; then
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/classes/parse.sh"
				handle_parse_classes "$IN/src/classes.sh"
			fi
			if [ -f "$IN/src/server.sh" ]; then
				. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/parse.sh"
				handle_parse_server "$IN/src/server.sh"
			fi
		else
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/parse.sh"
			handle_parse_routes "${IN:-}"
		fi
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/emit.sh"
		handle_emit_openapi "$OUT/spec.json"
		;;
	*)
		echo "Unknown from_openapi subcmd: $SUBCMD" >&2
		exit 1
		;;
	esac
	;;
from_arazzo)
	if [ "$#" -eq 0 ]; then print_help_from_arazzo; fi
	SUBCMD="to_sdk"
	case "${1:-}" in
	-*) ;;
	*)
		SUBCMD="$1"
		shift
		;;
	esac
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

	if [ "$SUBCMD" != "to_docs_json" ] && [ "$SUBCMD" != "to_arazzo" ]; then
		if [ "${CDD_NO_GITHUB_ACTIONS:-0}" != "1" ]; then
			mkdir -p "$OUT/.github/workflows"
			printf 'name: CI\non: [push, pull_request]\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: echo "Tests..."\n' >"$OUT/.github/workflows/ci.yml"
		fi
	fi

	. "${LIBSCRIPT_ROOT_DIR:-.}/src/arazzo/parse.sh"
	if [ -n "$IN" ]; then
		handle_parse_arazzo "$IN"
	else
		handle_parse_arazzo_dir "$IN_DIR"
	fi

	case "$SUBCMD" in
	to_sdk)
		mkdir -p "$OUT/src"
		if jq -e '.paths != null' "$CDD_AST_PATH" >/dev/null 2>&1; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/emit.sh"
			handle_emit_routes "$OUT/src/routes.sh" "sdk"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/classes/emit.sh"
			handle_emit_classes "$OUT/src/classes.sh"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/sdk/emit.sh"
			handle_emit_sdk "$OUT/src/sdk.sh"
		fi
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/workflows/emit.sh"
		handle_emit_workflows "$OUT/src/workflows.sh"
		if [ "${CDD_TESTS:-0}" = "1" ]; then
			mkdir -p "$OUT/tests"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_workflows.sh"
			handle_emit_server_workflows "$OUT/tests"
		fi
		echo "Generated Arazzo SDK in $OUT"
		;;
	to_sdk_cli)
		mkdir -p "$OUT/src" "$OUT/bin"
		if jq -e '.paths != null' "$CDD_AST_PATH" >/dev/null 2>&1; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/routes/emit.sh"
			handle_emit_routes "$OUT/src/routes.sh" "sdk"
		fi
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/workflows/emit.sh"
		handle_emit_workflows "$OUT/src/workflows.sh"
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/cli/emit.sh"
		handle_emit_cli "$OUT/bin/sdk-cli" "$OUT"
		echo "Generated Arazzo SDK CLI in $OUT"
		;;
	to_server)
		mkdir -p "$OUT/src" "$OUT/tests"
		if jq -e '.paths != null' "$CDD_AST_PATH" >/dev/null 2>&1; then
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_models.sh"
			handle_emit_server_models "$OUT/src/models"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_daos.sh"
			handle_emit_server_daos "$OUT/src/mocks"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_routes.sh"
			handle_emit_server_routes "$OUT/src/routes"
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_tests.sh"
			handle_emit_server_tests "$OUT/tests"
		fi
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/workflows/emit.sh"
		handle_emit_workflows "$OUT/src/workflows.sh"
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit.sh"
		handle_emit_server "$OUT/src/server.sh" "server"
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/server/emit_workflows.sh"
		handle_emit_server_workflows "$OUT/tests"
		echo "Generated Arazzo Server in $OUT"
		;;
	to_arazzo)
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/arazzo/emit.sh"
		handle_emit_arazzo "$OUT/arazzo.json"
		;;
	to_docs_json)
		. "${LIBSCRIPT_ROOT_DIR:-.}/src/docsjson/emit.sh"
		handle_emit_docsjson "$OUT/docs.json"
		;;
	*)
		echo "Unknown from_arazzo subcmd: $SUBCMD" >&2
		exit 1
		;;
	esac
	;;
parse | emit | sync)
	if [ "$CMD" = "sync" ]; then
		parse_global_args "$@"
		TYPE="${CDD_TRUTH:-server}"
		FILE="${CDD_INPUT:-}"
		if [ -d "${FILE}" ]; then
			if [ -f "${FILE}/server.sh" ]; then
				FILE="${FILE}/server.sh"
			elif [ -f "${FILE}/src/server.sh" ]; then
				FILE="${FILE}/src/server.sh"
			elif [ -f "${FILE}/routes.sh" ]; then
				TYPE="${CDD_TRUTH:-routes}"
				FILE="${FILE}/routes.sh"
			elif [ -f "${FILE}/src/routes.sh" ]; then
				TYPE="${CDD_TRUTH:-routes}"
				FILE="${FILE}/src/routes.sh"
			fi
		fi
	else
		TYPE="${1:-}"
		FILE="${2:-}"
	fi

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
		case "${CDD_OUTPUT:-}" in
		*.json)
			. "${LIBSCRIPT_ROOT_DIR:-.}/src/openapi/emit.sh"
			handle_emit_openapi "${CDD_OUTPUT}"
			;;
		*)
			out_prefix=""
			if [ -n "${CDD_OUTPUT:-}" ]; then
				mkdir -p "${CDD_OUTPUT}"
				out_prefix="${CDD_OUTPUT}/"
			fi
			for t in openapi arazzo routes classes workflows docstrings tests mocks docsjson; do
				h="${LIBSCRIPT_ROOT_DIR:-.}/src/${t}/emit.sh"
				if [ -f "$h" ]; then
					# shellcheck disable=SC1090
					. "$h"
					ext="sh"
					if [ "$t" = "openapi" ] || [ "$t" = "arazzo" ] || [ "$t" = "mocks" ] || [ "$t" = "docsjson" ]; then ext="json"; fi
					if [ "$t" = "docstrings" ]; then ext="md"; fi
					if type "handle_emit_${t}" >/dev/null 2>&1; then
						"handle_emit_${t}" "${out_prefix}emitted_${t}.${ext}"
					fi
				fi
			done
			;;
		esac
	else
		"handle_${CMD}_${TYPE}" "${FILE}"
	fi
	;;
*)
	echo "Unknown command: $CMD" >&2
	print_help
	;;
esac
