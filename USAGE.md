# Usage Guide

`cdd-sh` provides a single CLI binary: `bin/cdd-sh`.

## Subcommands

- `serve_json_rpc`: Starts the JSON-RPC interface on HTTP
  - Options: `--port <PORT>`, `--listen <IP>`
- `from_openapi`: Target code generation (SDK, Server)
  - Targets: `to_sdk`, `to_sdk_cli`, `to_server`
  - Required: `-i <spec.json>` or `--input-dir <dir>`
  - Optional: `-o <output_dir>`, `--no-github-actions`, `--no-installable-package`, `--create-composable-tests-mocks`
- `to_openapi`: Reverse-engineer source code to OpenAPI
  - Options: `-f <code_file.sh>`, `-o <out.json>`
- `to_docs_json`: Emit documentation data structure for rendering API catalogs.
  - Options: `-i <spec.json>`, `-o <docs.json>`, `--no-imports`, `--no-wrapping`

## Env Vars

All CLI options can be configured via Environment variables.
- `CDD_PORT`
- `CDD_LISTEN`
- `CDD_INPUT_FILE`
- `CDD_INPUT_DIR`
- `CDD_OUT_DIR`
- `CDD_CODE_FILE`
- `CDD_OUT_FILE`
