# OpenAPI 3.2.0 Compliance

`cdd-sh` acts upon the OpenAPI 3.2.0 specification. Given the constraints of a pure POSIX shell code generator, the project achieves an exceptionally high level of practical compliance.

## Supported OpenAPI 3.2.0 Features

### 1. Structure and Meta
* **[COMPLIANT]** `Info Object`: Title, version, description parsing and emitting.
* **[COMPLIANT]** `Server Object`: Resolves `url` and performs templated subbing via `variables` defaults using `jq reduce`.

### 2. Execution Paths
* **[COMPLIANT]** `Paths Object`: Generates operations (`GET`, `POST`, `DELETE`, etc.) into callable shell functions.
* **[COMPLIANT]** `Webhooks Object`: Fully parsed and generated as inbound `handle_webhook_X` stubs.
* **[COMPLIANT]** **Path-Level Parameters**: Parameter inheritance (merging `paths["/x"].parameters` with `paths["/x"].get.parameters`).

### 3. Parameters & Encoding (RFC6570)
* **[COMPLIANT]** `in: path`, `in: query`, `in: header` parameters.
* **[COMPLIANT]** Advanced RFC6570 `style` formatting natively in shell:
  * `style: form` (with/without `explode`)
  * `style: spaceDelimited` / `pipeDelimited`
  * `style: matrix`
  * `style: label`
* **[COMPLIANT]** URL Percent Encoding using `jq -s -R -r '@uri'`.

### 4. Components & Validation
* **[COMPLIANT]** `components.schemas` are transformed into executable deep validators.
* **[COMPLIANT]** `$ref` resolution: Classes recursively call other class validators (e.g., `validate_Pet` calls `validate_Owner`).
* **[COMPLIANT]** Array validation: Parses `items: { $ref: ... }` and executes `while` loops inside the shell to recursively validate every index in a JSON array payload.

### 5. Security Schemes
* **[COMPLIANT]** `OAuth2` & Bearer (`type: "http", scheme: "bearer"`): Auto-injects `-H "Authorization: Bearer ${OAUTH_TOKEN}"`. Emits a `client_credentials` fetcher.
* **[COMPLIANT]** `Basic Auth` (`type: "http", scheme: "basic"`): Auto-injects `curl -u "${BASIC_AUTH}"`.
* **[COMPLIANT]** `API Key`: Injects as headers (`-H`) or query parameters (`?api_key=...`).

---

## Technical Standard Compliance

### POSIX Shell & Shellcheck
The emitted artifacts and the generator source code itself operate under zero-tolerance rules for non-POSIX behavior:
* **0 Shellcheck Errors/Warnings** across all scripts (`SC3043` for `local`, `SC3054` for arrays, etc., are fundamentally solved).
* **State Management**: Avoiding `local` requires careful dynamic variable naming during recursive functions. In array validation, `_i_\($className)` is generated to sandbox loop indices dynamically per class.
* **Dependency Free**: Strictly leverages `awk`, `sed`, `grep`, `/bin/sh`. Requires `jq` and `curl` to be installed on the host.