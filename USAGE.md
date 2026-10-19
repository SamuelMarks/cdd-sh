# Usage Guide

`cdd-sh` provides a single CLI binary (`bin/cdd-sh` / `cdd.sh`), a self-contained cross-platform runner (`bin/cdd-sh-runner`), a WASI module (`wasm_build/cdd-sh.wasm`), and modular POSIX Shell libraries (`src/*`, `lib/*`).

## Subcommands

- `from_openapi`: Target code generation (SDK, CLI, Server, OpenAPI, Docs) from an OpenAPI 3.2.0 or Swagger 2.0 specification
  - Targets: `to_sdk`, `to_sdk_cli`, `to_server`, `to_openapi`, `to_docs_json`
  - Required: `-i, --input <spec.json>` or `-d, --input-dir <dir>`
  - Optional: `-o, --output <output_dir>`, `--no-github-actions`, `--no-installable-package`, `-t, --tests`, `--ephemeral`, `--seed`, `--strict-validation`, `--enforce-auth`, `--start-auth-server`
- `to_openapi`: Reverse-engineer POSIX Shell source code (`routes.sh`, `classes.sh`, `server.sh`, `bin/sdk-cli`, `mocks.json`, `docs.md`, or directory) to an OpenAPI 3.2.0 specification
  - Options: `-i, --input <code_file_or_dir>`, `-o, --output <out.json>`
- `from_arazzo`: Target workflow code generation (SDK, CLI, Server, Arazzo, Docs) from an Arazzo 1.1.0 specification
  - Targets: `to_sdk`, `to_sdk_cli`, `to_server`, `to_arazzo`, `to_docs_json`
  - Required: `-i, --input <arazzo.json>` or `-d, --input-dir <dir>`
  - Optional: `-o, --output <output_dir>`, `--no-github-actions`, `--no-installable-package`, `-t, --tests`
- `to_arazzo`: Reverse-engineer source code (`workflows.sh`, `bin/sdk-cli`, `server.sh`, `test_routes.sh`, or directory) to an Arazzo 1.1.0 specification
  - Options: `-i, --input <code_file_or_dir>`, `-o, --output <arazzo.json>`
- `sync`: Bidirectionally synchronize POSIX Shell source files, documentation, tests, mocks, and OpenAPI/Arazzo specifications from a designated source of truth
  - Options: `--truth <source>` (`server`, `routes`, `classes`, `workflows`, `cli`, `openapi`, `arazzo`, `docstrings`, `tests`, `mocks`), `-i, --input <file_or_dir>`, `-o, --output <target_dir_or_json>`
- `to_docs_json`: Emit documentation data structure with POSIX Shell code snippets for rendering API and workflow catalogs
  - Options: `-i, --input <spec.json>`, `-o, --output <docs.json>`, `--no-imports`, `--no-wrapping`
- `serve_json_rpc`: Starts the JSON-RPC 2.0 interface over HTTP
  - Options: `-p, --port <PORT>` (default: `8082`), `-l, --listen <IP>` (default: `0.0.0.0`)
- `mcp`: Runs `cdd-sh` as a Model Context Protocol (MCP) server over `stdio`
- `parse <type> <file>`: Parses a specification or source artifact directly into the unified AST (`ast.json`)
  - Types: `openapi`, `arazzo`, `routes`, `classes`, `workflows`, `server`, `cli`, `functions`, `docstrings`, `tests`, `mocks`
- `emit <type> <file>`: Emits a specification or source artifact directly from the unified AST (`ast.json`)
  - Types: `openapi`, `arazzo`, `routes`, `classes`, `workflows`, `sdk`, `server`, `cli`, `functions`, `docstrings`, `docsjson`, `tests`, `mocks`

## Environment Variables

All CLI options and generated server behaviors can be configured via environment variables:
- `CDD_AST_PATH`: Path to the intermediate AST JSON file (default: `ast.json`)
- `CDD_INPUT`: Input specification or source file/directory path (`-i`, `--input`)
- `CDD_INPUT_DIR`: Directory containing multiple specifications (`-d`, `--input-dir`)
- `CDD_OUTPUT`: Output file or directory path (`-o`, `--output`)
- `CDD_TRUTH`: Source of truth for `sync` (`--truth`)
- `CDD_PORT`: Port for `serve_json_rpc` (`-p`, `--port`)
- `CDD_LISTEN`: Listen address for `serve_json_rpc` (`-l`, `--listen`)
- `CDD_TESTS`: Generate contract tests and mocks (`-t`, `--tests`)
- `CDD_MCP`: Generate MCP adapters (`-m`, `--mcp`)
- `CDD_NO_GITHUB_ACTIONS`: Skip generating `.github/workflows/ci.yml` (`--no-github-actions`)
- `CDD_NO_INSTALLABLE_PACKAGE`: Skip generating package definitions (`--no-installable-package`)
- `CDD_NO_IMPORTS`: Omit import/source statements in `to_docs_json` (`--no-imports`)
- `CDD_NO_WRAPPING`: Omit wrapper object in `to_docs_json` (`--no-wrapping`)
- `CDD_EPHEMERAL`: Use ephemeral SQLite database in generated servers (`--ephemeral`)
- `CDD_SEED`: Seed SQLite database with Faker data on server startup (`--seed`)
- `CDD_STRICT_VALIDATION`: Enforce strict JSON Schema validation on server requests (`--strict-validation`)
- `CDD_ENFORCE_AUTH`: Enforce authentication headers on protected server routes (`--enforce-auth`)
- `CDD_START_AUTH_SERVER`: Enable embedded OAuth2 mock token endpoint (`--start-auth-server`)
- `CDD_EMIT_SWAGGER2`: Emit Swagger 2.0 JSON instead of OpenAPI 3.2.0 when running `emit openapi`
- `ACTIVE_DAO`: Select `stub` (mock responses) or `concrete` (SQLite persistence) in generated servers
- `DATABASE_URL`: Path to the SQLite database file used when `ACTIVE_DAO=concrete`
