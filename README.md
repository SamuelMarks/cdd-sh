cdd-sh
============

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI/CD](https://github.com/offscale/cdd-sh/workflows/CI/badge.svg)](https://github.com/offscale/cdd-sh/actions)
[![Doc Coverage](https://img.shields.io/badge/doc_coverage-100%25-brightgreen.svg)]()
[![Test Coverage](https://img.shields.io/badge/test_coverage-100%25-brightgreen.svg)]()

OpenAPI ↔ Shell. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

Each compiler is written in its target language, is whitespace and comment sensitive, and has both an SDK and CLI.

The CLI—at a minimum—has:
- `cdd-sh --help`
- `cdd-sh --version`
- `cdd-sh from_openapi -i spec.json`
- `cdd-sh to_openapi -f path/to/code`
- `cdd-sh to_docs_json --no-imports --no-wrapping -i spec.json`

The goal of this project is to enable rapid application development without tradeoffs. Tradeoffs of Protocol Buffers / Thrift etc. are an untouchable "generated" directory and package, compile-time and/or runtime overhead. Tradeoffs of Java or JavaScript for everything are: overhead in hardware access, offline mode, ML inefficiency, and more. And neither of these alterantive approaches are truly integrated into your target system, test frameworks, and bigger abstractions you build in your app. Tradeoffs in CDD are code duplication (but CDD handles the synchronisation for you).

## 🚀 Capabilities

The `cdd-sh` compiler leverages a unified architecture to support various facets of API and code lifecycle management.

* **Compilation**:
  * **OpenAPI → `Shell`**: Generate idiomatic native models, network routes, client SDKs, database schemas, and boilerplate directly from OpenAPI (`.json` / `.yaml`) specifications.
  * **`Shell` → OpenAPI**: Statically parse existing `Shell` source code and emit compliant OpenAPI specifications.
* **AST-Driven & Safe**: Employs static analysis (Abstract Syntax Trees) instead of unsafe dynamic execution or reflection, allowing it to safely parse and emit code even for incomplete or un-compilable project states.
* **Seamless Sync**: Keep your docs, tests, database, clients, and routing in perfect harmony. Update your code, and generate the docs; or update the docs, and generate the code.

## 📦 Installation

Requires `sh`, `jq`, `curl` and `awk`.
Clone the repository, then:

```bash
make install_base
make build
./bin/cdd-sh --version
```

## 🛠 Usage

### Command Line Interface

```bash
# Generate SDK CLI
./bin/cdd-sh from_openapi to_sdk_cli -i spec.json -o ./cli-out
./cli-out/cli.sh --help

# Emit OpenAPI from existing shell script
./bin/cdd-sh to_openapi -f src/routes/emit.sh -o output_spec.json

# Start JSON-RPC Server
./bin/cdd-sh serve_json_rpc --port 8080 --listen 127.0.0.1
```

### Programmatic SDK / Library

```bash
. ./src/routes/emit.sh
handle_emit_routes "routes.sh" "sdk"
```

## Design choices

The parser uses `jq` for JSON manipulations to read/write the CDD Intermediate Representation (`ast.json`). Shell scripts use simple `awk` and `sed` logic to seamlessly patch files inline without rewriting unaffected code, preserving user modifications.

## 🏗 Supported Conversions for Shell

*(The boxes below reflect the features supported by this specific `cdd-sh` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | ✅ | ✅ |
| `Shell` Models / Structs / Types | [ ] | [ ] |
| `Shell` Server Routes / Endpoints | [ ] | [ ] |
| `Shell` API Clients / SDKs | [ ] | [ ] |
| `Shell` ORM / DB Schemas | [ ] | [ ] |
| `Shell` CLI Argument Parsers | [ ] | [ ] |
| `Shell` Docstrings / Comments | [ ] | [ ] |



---

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall be
dual licensed as above, without any additional terms or conditions.
## WASM Support

| Concept | Supported | Implemented |
|---------|-----------|-------------|
| WebAssembly | ✅ | ✅ |

## CLI Help

```
$ ./cdd.sh --help
Usage: cdd-sh <command> [args]

Commands:
  to_openapi -i <code_file_or_dir> -o <spec.json>
  serve_json_rpc --port <port> --listen <ip>
  to_docs_json [--no-imports] [--no-wrapping] -i <spec.json> -o <docs.json>
  from_openapi [subcmd] -i <spec.json> -o <target_dir>
  from_openapi [subcmd] --input-dir <specs_dir> -o <target_dir>
  --help
  --version

Note: All options can be passed via environment variables (e.g., CDD_PORT=8082 cdd-sh serve_json_rpc)
```

### `from_openapi`

```
$ ./cdd.sh from_openapi --help
Error: -i or --input-dir required
```

### `to_openapi`

```
$ ./cdd.sh to_openapi --help
Unknown arg --help
```

### `to_docs_json`

```
$ ./cdd.sh to_docs_json --help
Unknown arg --help
```
