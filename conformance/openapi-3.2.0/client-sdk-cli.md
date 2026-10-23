# OpenAPI 3.2.0 Conformance Table: Client SDK CLI (CLI Tooling & Tests)

This table tracks the completeness of language integration with OpenAPI 3.2.0 for generating Command-Line Interfaces (CLIs) wrapper tools, and vice-versa.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the OpenAPI document from declarative CLI structures)
*   **From**: OpenAPI -> Language (Generating CLI routing, flag parsing, and formatting from OpenAPI)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the CLI environment.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| OpenAPI 3.2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **OpenAPI Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root CLI definition |
| **OpenAPI Object (`openapi`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserves and emits `openapi: "3.2.0"` in embedded CLI AST |
| **OpenAPI Object (`$self`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Base URI resolution for internal and external references |
| **OpenAPI Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `--help` banner and `--version` output |
| **OpenAPI Object (`jsonSchemaDialect`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Skipped or used for advanced flag validation |
| **OpenAPI Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--server` / `BASE_URL` CLI environment selection |
| **OpenAPI Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand dispatcher in `bin/sdk-cli` |
| **OpenAPI Object (`webhooks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in CLI AST and exposed as `webhook_*` subcommands |
| **OpenAPI Object (`components`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared schema validators and reusable CLI flag definitions |
| **OpenAPI Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global auth flags (`--bearer-token`, `--api-key`, `AUTH_*`) |
| **OpenAPI Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand group categorization in `--help` |
| **OpenAPI Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rendered in CLI global `--help` footer |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `--help` text, `--version` command |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Displayed in `usage()` header |
| **Info Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Short summary for CLI global help text |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Detailed CLI description in `usage()` |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in CLI metadata annotations |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in CLI metadata annotations |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in CLI metadata annotations |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Printed by `--version` / `-V` |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Appended to global help or preserved in `@contact` |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer name in `@contact` annotation |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer URL in `@contact` annotation |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer email in `@contact` annotation |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Appended to global help or preserved in `@license` |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name in `@license` annotation |
| **License Object (`identifier`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SPDX license identifier extraction |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL in `@license` annotation |
| **Server Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global `--server` or `--host` flag mapping |
| **Server Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default `BASE_URL` in generated CLI |
| **Server Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server description in `@server` metadata |
| **Server Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Unique name used as CLI alias for a host environment |
| **Server Object (`variables`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `SERVER_VAR_*` environment and flag overrides |
| **Server Variable Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Individual host template CLI flags |
| **Server Variable Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enum validation on server variable values |
| **Server Variable Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default server variable value in URL template |
| **Server Variable Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server variable description in `@server` metadata |
| **Components Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable flag groups or interactive prompt states |
| **Components Object (`schemas`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema validation functions sourced by CLI |
| **Components Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_responses` |
| **Components Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved into subcommand CLI flags |
| **Components Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_examples` |
| **Components Object (`requestBodies`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved into `--body` CLI payload flags |
| **Components Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_headers` |
| **Components Object (`securitySchemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@security_scheme` annotations |
| **Components Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_links` |
| **Components Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_callbacks` |
| **Components Object (`pathItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable subcommand groupings |
| **Components Object (`mediaTypes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable payload flag definitions |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Structural mapping to CLI namespaces |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to CLI subcommands and `@path` metadata |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand grouping |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved from `components.pathItems` |
| **Path Item Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@path_meta` |
| **Path Item Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@path_meta` |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking GET route function |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking PUT route function |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking POST route function |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking DELETE route function |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking OPTIONS route function |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking HEAD route function |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking PATCH route function |
| **Path Item Object (`trace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand invoking TRACE route function |
| **Path Item Object (`query`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | QUERY HTTP method subcommand |
| **Path Item Object (`additionalOperations`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Map of custom HTTP methods to subcommands |
| **Path Item Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path-level server override in `@path_meta` |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level CLI flags |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | The execution targets of subcommands (e.g., `cli users get`) |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Groups subcommands in `usage()` |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | One-line subcommand summary in `usage()` |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Detailed subcommand `--help` text |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@operation_externalDocs` |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand name in `bin/sdk-cli` |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--<param>` CLI options parsed via `while [ $# -gt 0 ]` |
| **Operation Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--body <json>` CLI option |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Output formatting and non-zero exit code mapping |
| **Operation Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@callbacks` annotation |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Marked `[DEPRECATED]` in usage output |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-command auth environment/flag binding |
| **Operation Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-command `BASE_URL` override |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Added to `See also:` in subcommand help |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs description in help output |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs URL in help output |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `--<name>` flag generation and parsing |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI flag name (`--<name>`) |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Passed to underlying route function in positional order |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Flag description in `usage()` |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced before invoking route function |
| **Parameter Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allows empty string value on flag |
| **Parameter Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shown in CLI help and used in CLI tests |
| **Parameter Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` |
| **Parameter Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Serialization style for array/object flags |
| **Parameter Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Explode serialization control for flags |
| **Parameter Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bypasses URL percent-encoding when true |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates CLI flag value against schema type |
| **Parameter Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Complex JSON flag serialization |
| **Request Body Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Handled via `--body` flag or `--input-file` / `--data-file` |
| **Request Body Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--body` description in `usage()` |
| **Request Body Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Sets request `Content-Type` header |
| **Request Body Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `--body` is provided when required |
| **Media Type Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Inferred based on payload flag logic |
| **Media Type Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `--body` JSON payload via `validate_<Schema>()` |
| **Media Type Object (`itemSchema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validation for individual items in a CLI array flag |
| **Media Type Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example payload in CLI help and tests |
| **Media Type Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named payload examples in `@requestBody_meta` |
| **Media Type Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Multipart/form-data encoding rules |
| **Media Type Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Positional tuple item encoding rules |
| **Media Type Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Stream/array item encoding rules |
| **Encoding Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Internal CLI form-data builder logic |
| **Encoding Object (`contentType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Part `Content-Type` header in form-data |
| **Encoding Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Part custom headers in form-data |
| **Encoding Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested property encoding rules |
| **Encoding Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested positional prefix encoding rules |
| **Encoding Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array item encoding rules |
| **Encoding Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field serialization style |
| **Encoding Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field explode flag |
| **Encoding Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field reserved character handling |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Determines Exit Codes (`0` vs `1`, etc.) |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default error response formatting |
| **Responses Object (`HTTP Status Code`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Status-code specific output handling |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Stdout formatting (Table format, JSON, YAML, `--raw`) |
| **Response Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand exit status short description |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description in `@response` metadata |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response header metadata in `@response` |
| **Response Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response payload formatting (`json`, `yaml`, `table`) |
| **Response Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Follow-up CLI command suggestions in `@response` |
| **Callback Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@callbacks` metadata |
| **Callback Object (`{expression}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Callback runtime expression key in `@callbacks` |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Injected into subcommand `--help` 'Examples' block |
| **Example Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example summary caption |
| **Example Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example extended description |
| **Example Object (`dataValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Structured data example value |
| **Example Object (`serializedValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Wire-format serialized example value |
| **Example Object (`externalValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External example URL reference |
| **Example Object (`value`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Inline example value |
| **Link Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@response` / `@components_links` |
| **Link Object (`operationRef`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked operation URI reference |
| **Link Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked CLI subcommand name |
| **Link Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked subcommand parameter mapping |
| **Link Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked subcommand request body expression |
| **Link Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Link description in `@response` |
| **Link Object (`server`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked server override |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Can optionally be printed with `-v` (verbose) flags |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description in `@response` |
| **Header Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required header flag |
| **Header Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated header flag |
| **Header Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header example value |
| **Header Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header named examples map |
| **Header Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header style (`simple`) |
| **Header Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header explode flag |
| **Header Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header value schema |
| **Header Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header media type map |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | High-level CLI command groups (e.g. `cli [tag] [operation]`) |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag name in `usage()` and `@tag_meta` |
| **Tag Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag summary in `@tag_meta` |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description in `@tag_meta` |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external documentation in `@tag_meta` |
| **Tag Object (`parent`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested subcommand groups |
| **Tag Object (`kind`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand grouping logic (e.g. `nav` vs `hidden`) |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved across CLI flags and schemas |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Internal resolution to flatten flags/commands |
| **Reference Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference summary override |
| **Reference Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference description override |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates CLI arguments via `classes.sh` |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Polymorphic payload validation in CLI |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` annotations |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` annotations |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@example` annotations |
| **Discriminator Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mutually exclusive flag groups based on type |
| **Discriminator Object (`propertyName`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Discriminator property selector |
| **Discriminator Object (`mapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Explicit discriminator value-to-schema mapping |
| **Discriminator Object (`defaultMapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Fallback CLI flag group when type is omitted |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` annotations |
| **XML Object (`nodeType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` (`element`, `attribute`, `text`, `cdata`, `none`) |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML tag/attribute name in `@xml` |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace URI in `@xml` |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML prefix in `@xml` |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `nodeType: "attribute"` |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `nodeType: "element"` |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `AUTH_*` environment variables and CLI flags |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `apiKey`, `http`, `mutualTLS`, `oauth2`, `openIdConnect` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Auth description in CLI `--help` |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header/query/cookie name for `apiKey` |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `header`, `query`, or `cookie` location |
| **Security Scheme Object (`scheme`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HTTP auth scheme (`bearer`, `basic`) |
| **Security Scheme Object (`bearerFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bearer token format hint |
| **Security Scheme Object (`flows`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 flows in `@security_scheme` |
| **Security Scheme Object (`openIdConnectUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OIDC discovery URL in `@security_scheme` |
| **Security Scheme Object (`oauth2MetadataUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 metadata discovery |
| **Security Scheme Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated auth scheme flag |
| **OAuth Flows Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI token manager / local environment integration |
| **OAuth Flows Object (`implicit`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Implicit flow configuration |
| **OAuth Flows Object (`password`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Password grant flow configuration |
| **OAuth Flows Object (`clientCredentials`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Client credentials grant flow configuration |
| **OAuth Flows Object (`authorizationCode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Authorization code grant flow configuration |
| **OAuth Flows Object (`deviceAuthorization`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Support for the Device Authorization grant flow |
| **OAuth Flow Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Flow routing logic for CLI login |
| **OAuth Flow Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Authorization endpoint URL |
| **OAuth Flow Object (`deviceAuthorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Triggers CLI device auth prompt |
| **OAuth Flow Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Token exchange endpoint URL |
| **OAuth Flow Object (`refreshUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Token refresh endpoint URL |
| **OAuth Flow Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Asserting required auth exists before command execution |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme requirement and scope list |
