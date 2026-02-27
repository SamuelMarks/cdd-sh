![Test Coverage](https://img.shields.io/badge/test_coverage-100%25-brightgreen.svg)
![Doc Coverage](https://img.shields.io/badge/doc_coverage-100%25-brightgreen.svg)
# cdd-sh: Contract-Driven Development in POSIX Shell

`cdd-sh` is an extreme, bidirectional OpenAPI 3.2.0 toolchain written entirely in pure POSIX shell (`/bin/sh`). 

It is designed to completely close the gap between **Specification** and **Code** by allowing you to generate an installable API client from an OpenAPI spec, and—crucially—**regenerate the OpenAPI spec by directly editing the generated shell code.**

## Features

- **100% POSIX Compliant**: Zero bashisms. Strictly relies on standard tools (`sh`, `awk`, `sed`) and ubiquitous utilities (`jq`, `curl`).
- **100% Shellcheck Clean**: Rigorously structured to pass all shellcheck rules (e.g., no `local` variables, secure expansions).
- **Bidirectional Sync**: Hub-and-spoke architecture built around a central `ast.json`. Parse an OpenAPI spec to AST, emit shell routes. Edit the shell routes, parse them back to AST, emit a new OpenAPI spec.
- **Robust Feature Set**:
  - `routes`: Emits executable `curl` wrappers with full RFC6570 parameter formatting (`matrix`, `label`, `form`).
  - `classes`: Emits strict JSON payload validators capable of deeply nested recursive `$ref` validation.
  - `webhooks`: Generates listener stubs for inbound requests.
  - `tests` & `mocks`: Auto-generates mock payloads and execution test suites out-of-the-box.
  - `docstrings`: Auto-generates Markdown documentation matching the current codebase state.

## Quick Start

```sh
# 1. Parse an existing OpenAPI 3.2.0 spec into the internal AST
./cdd.sh parse openapi my-spec.json

# 2. Emit an executable POSIX shell client
./cdd.sh emit routes my_client.sh

# 3. Emit data class validators
./cdd.sh emit classes my_classes.sh

# 4. Edit `my_client.sh` directly (add a new function with # @ annotations)

# 5. Parse the edited client back into the AST
./cdd.sh parse routes my_client.sh

# 6. Emit the updated OpenAPI spec!
./cdd.sh emit openapi updated-spec.json
```

See [USAGE.md](USAGE.md) for detailed workflows.
