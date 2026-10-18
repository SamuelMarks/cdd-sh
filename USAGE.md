# Usage Guide

`cdd-sh` provides a single CLI binary: `bin/cdd-sh`.

## Subcommands

- `serve_json_rpc`: Starts the JSON-RPC interface on HTTP
  - Options: `--port <PORT>`, `--listen <IP>`
- `from_openapi`: Target code generation (SDK, Server)
  - Targets: `to_sdk`, `to_sdk_cli`, `to_server`
  - Required: `-i <spec.json>` or `--input-dir <dir>`
  - Optional: `-o <output_dir>`, `--no-github-actions`, `--no-installable-package`, `--tests`
- `to_openapi`: Reverse-engineer source code to OpenAPI
  - Options: `-i <code_file_or_dir>`, `-o <out.json>`
- `from_arazzo`: Target workflow code generation (SDK, CLI, Server, Docs) from Arazzo 1.1.0
  - Targets: `to_sdk`, `to_sdk_cli`, `to_server`, `to_arazzo`, `to_docs_json`
  - Required: `-i <arazzo.json>` or `--input-dir <dir>`
  - Optional: `-o <output_dir>`, `--no-github-actions`, `--no-installable-package`, `--tests`
- `to_arazzo`: Reverse-engineer source code (`workflows.sh`, `sdk-cli`, `server.sh`, `test_routes.sh`) to Arazzo 1.1.0
  - Options: `-i <code_file_or_dir>`, `-o <arazzo.json>`
- `to_docs_json`: Emit documentation data structure for rendering API and workflow catalogs.
  - Options: `-i <spec.json>`, `-o <docs.json>`, `--no-imports`, `--no-wrapping`

## Env Vars

All CLI options can be configured via Environment variables.
- `CDD_PORT`
- `CDD_LISTEN`
- `CDD_INPUT`
- `CDD_INPUT_DIR`
- `CDD_OUTPUT`
