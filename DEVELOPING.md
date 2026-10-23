# Developing cdd-sh

## Local Environment

Dependencies:
- `make`
- `sh`
- `jq`
- `awk`
- `curl`
- `go` (for building the self-contained cross-platform/WASM runner and running Go tests)

To install dependencies, build, and run tests:
```sh
make deps
make build
make test
```

To build the WebAssembly (`wasip1/wasm`) binary:
```sh
make build_wasm
```

## Directory Structure

`cdd-sh` expects:
- `src/` modular codebase for parse/emit logic.
- `tests/` tests and JSON specs.
- `lib/` helper libraries (`env.sh`, `arazzo_runtime.sh`, `mcp_handler.sh`, `_common/*`).
- `internal/` embedded `gojq` (`gojqcli`) and `goawk` (`goawkcli`) CLI runners.
- `bin/` CLI entry points (`bin/cdd-sh` and `bin/cdd-sh-runner`).

## Pre-commit

Ensure that `pre-commit` is installed and run `pre-commit install` to register the hooks that verify formatting, linting, tests, and auto-update coverage shields before committing.
