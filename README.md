cdd-sh
============

[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![CI/CD](https://github.com/offscale/cdd-sh/workflows/CI/badge.svg)](https://github.com/offscale/cdd-sh/actions)
<!-- REPLACE WITH separate test and doc coverage badges that you generate in pre-commit hook -->

OpenAPI ↔ POSIX Shell. This is one compiler in a suite, all focussed on the same task: Compiler Driven Development (CDD).

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

This is a pure POSIX shell compiler. It only requires a POSIX compatible shell (`/bin/sh`, `dash`, `ash`, `bash`, `zsh`), `jq` (1.6+), `curl`, `awk`, and `sed` installed on the host.

1. Clone the repository:
   ```sh
   git clone https://github.com/offscale/cdd-sh.git
   cd cdd-sh
   ```
2. Ensure `cdd.sh` is executable:
   ```sh
   chmod +x cdd.sh
   ```
3. (Optional) Link it to your `PATH` or invoke it directly.

## 🛠 Usage

### Command Line Interface

You can generate code from an OpenAPI specification:

```sh
# Generate the AST first
./cdd.sh parse openapi my_api_spec.json

# Emit the generated shell routes
./cdd.sh emit routes emitted_routes.sh

# Emit to OpenAPI Docs JSON
./cdd.sh to_docs_json --no-imports -i my_api_spec.json
```

Or you can extract OpenAPI specs from existing compliant shell scripts:

```sh
# Parse your shell code
./cdd.sh parse routes src/my_routes.sh

# Emit the resulting OpenAPI representation
./cdd.sh emit openapi my_api_spec.json
```

Synchronize the whole project instantly when you edit one piece of it:

```sh
./cdd.sh sync routes src/my_routes.sh
```

### Programmatic SDK / Library

You can easily source components inside your other shell scripts if needed.

```sh
#!/bin/sh

# Setup root context
LIBSCRIPT_ROOT_DIR="$(pwd)"
export LIBSCRIPT_ROOT_DIR

# Load parser
. "${LIBSCRIPT_ROOT_DIR}/src/routes/parse.sh"

# Extract metadata
handle_parse_routes "my_routes.sh"
```

## Design choices

This project goes extreme in portability by being written strictly in POSIX Shell script (`#!/bin/sh`) combined with common GNU/POSIX utilities like `jq`, `awk`, and `sed`. 

It achieves *zero-tolerance* for non-POSIX behavior (`0 Shellcheck errors`).

Rather than relying on heavy parsing libraries in Node.js or Python, `cdd-sh` parses highly structured shell script comments (like `# @function`, `# @property`) utilizing `awk`, building a universal AST serialized with `jq`. It implements RFC6570 parameter formatting entirely using shell primitives, making this a fully self-bootstrapping, cross-platform code generator that requires zero compilation or massive runtimes.

## 🏗 Supported Conversions for Shell

*(The boxes below reflect the features supported by this specific `cdd-sh` implementation)*

| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | [x] | [x] |
| `Shell` Models / Structs / Types | [x] | [x] |
| `Shell` Server Routes / Endpoints | [x] | [x] |
| `Shell` API Clients / SDKs | [x] | [x] |
| `Shell` ORM / DB Schemas | [ ] | [ ] |
| `Shell` CLI Argument Parsers | [ ] | [ ] |
| `Shell` Docstrings / Comments | [ ] | [x] |

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
