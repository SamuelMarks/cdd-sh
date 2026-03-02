# Developing cdd-sh

## Local Environment

Dependencies:
- `make`
- `sh`
- `jq`
- `awk`
- `curl`

To run tests:
```bash
make test
```

## Directory Structure

`cdd-sh` expects:
- `src/` modular codebase for parse/emit logic.
- `tests/` tests and JSON specs.
- `lib/` helper libraries.
- `bin/` CLI entry points.

## Pre-commit

Ensure that `pre-commit` is installed and run `pre-commit install` to register the hooks that auto-update coverage shields before committing.
