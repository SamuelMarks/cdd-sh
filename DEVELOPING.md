# Developing `cdd-sh`

This document details how to extend and hack on the `cdd-sh` compiler.

## Prerequisites
- A strict POSIX `/bin/sh` (like `dash`, `ash`, or `sh` on Alpine/Ubuntu/macOS).
- `jq` (1.6+)
- `curl`
- `awk` & `sed`
- `shellcheck` (for validation)

## Creating a New Module

If you want to add a new code-generation feature (e.g., `src/metrics`), follow these steps:

1. **Create the directories:**
   ```sh
   mkdir -p src/metrics
   ```

2. **Create the parser/emitter shells:**
   ```sh
   touch src/metrics/parse.sh
   touch src/metrics/emit.sh
   chmod +x src/metrics/*.sh
   ```

3. **Include the Prelude:**
   Every file must start with the standard `cdd-sh` prelude to establish `LIBSCRIPT_ROOT_DIR`. Look at any file in `src/routes` for the template.

4. **Define Handlers:**
   The `cdd.sh` router expects two functions:
   - `handle_parse_metrics() { file_path="${1}"; ... }`
   - `handle_emit_metrics() { file_path="${1}"; ... }`

## The AST Rule
Never hold state in bash variables between files.
1. `parse.sh` must **only** read its target file and update `ast.json` (using `jq --slurpfile`).
2. `emit.sh` must **only** read `ast.json` and output its target file.

## Testing Your Changes

We have a comprehensive end-to-end regression script (`test.sh`) at the root of the project. It validates the full bidirectional round-trip, creates test instances of classes/routes, mocks curl requests, and runs `shellcheck` over all generated artifacts.

Run it before any commit:
```sh
./test.sh
```

**What it tests:**
1. Parses a mock OpenAPI spec into `ast.json`.
2. Emits all modules (`routes.sh`, `classes.sh`, `tests.sh`, etc.).
3. Uses `sed` to inject fake functions into the emitted artifacts to simulate a user editing the code.
4. Re-parses the artifacts back into `ast.json` to verify the state merges correctly.
5. Executes `test_routes.sh` to confirm the emitted `curl` commands syntax perfectly.
6. Shellchecks everything.