# Swagger 2.0 Conformance Table: Client SDK CLI (CLI Tooling & Tests)

This table tracks the completeness of language integration with Swagger 2.0 for generating Command-Line Interfaces (CLIs) wrapper tools, and vice-versa.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the Swagger document from declarative CLI structures)
*   **From**: OpenAPI -> Language (Generating CLI routing, flag parsing, and formatting from Swagger)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| Swagger 2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Swagger Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root CLI definition via `swagger2openapi.jq` and `openapi2swagger.jq` |
| **Swagger Object (`swagger`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recognizes `"2.0"` on input and emits `"2.0"` with `--openapi-version 2.0` |
| **Swagger Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `--help` banner and `--version` metadata |
| **Swagger Object (`host`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Combined into default `BASE_URL` in `bin/sdk-cli` |
| **Swagger Object (`basePath`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Appended to default `BASE_URL` and extracted on `from_sdk_cli` |
| **Swagger Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Protocol scheme (`https` / `http`) in `BASE_URL` |
| **Swagger Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Request `Content-Type` header in CLI calls |
| **Swagger Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Request `Accept` header and output formatting |
| **Swagger Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand dispatcher in `bin/sdk-cli` |
| **Swagger Object (`definitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Payload validators in `classes.sh` |
| **Swagger Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable CLI flag definitions in `@components_parameters` |
| **Swagger Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable CLI response definitions in `@components_responses` |
| **Swagger Object (`securityDefinitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `AUTH_*` environment variables and `@security_scheme` |
| **Swagger Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global CLI authentication requirements |
| **Swagger Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand grouping in `usage()` |
| **Swagger Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global help footer link |
| **Swagger Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root `x-*` extensions preserved in `@root_extensions` |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `--help` and `--version` output |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI title in `usage()` |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI description in `usage()` |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@info_termsOfService` |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@contact` annotation |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@license` annotation |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Printed by `--version` |
| **Info Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Info `x-*` extensions preserved in `@info_extensions` |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer metadata in `@contact` |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer name in `@contact` |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer URL in `@contact` |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer email in `@contact` |
| **Contact Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact `x-*` extensions |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License metadata in `@license` |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name in `@license` |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL in `@license` |
| **License Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License `x-*` extensions |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to CLI subcommands |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand route path template |
| **Paths Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Paths `x-*` extensions in `@paths_extensions` |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand grouping per URI |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `$ref` resolution |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for GET operation |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for PUT operation |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for POST operation |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for DELETE operation |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for OPTIONS operation |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for HEAD operation |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand for PATCH operation |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level CLI flags |
| **Path Item Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `x-*` extensions in `@path_meta` |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand handler in `bin/sdk-cli` |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand category in `usage()` |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand one-line help text |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Detailed subcommand help text |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Subcommand external docs reference |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI subcommand identifier |
| **Operation Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Request `Content-Type` selection |
| **Operation Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response `Accept` header selection |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--<name>` and `--body` CLI flags |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI output and exit status handling |
| **Operation Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation-level URL scheme override |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `[DEPRECATED]` notice in CLI usage |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-command auth variable binding |
| **Operation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation `x-*` extensions in `@operation_extensions` |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rendered in CLI help output |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs description |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs URL |
| **External Documentation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs `x-*` extensions |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI option parsing via `while [ $# -gt 0 ]` |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `--<name>` CLI option name |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Dispatched to `path`, `query`, `header`, `formData`, or `body` |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI option description in `usage()` |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required CLI option check |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `--body` JSON payload via `classes.sh` |
| **Parameter Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates primitive/array CLI flag types |
| **Parameter Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates parameter format |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allows empty flag value |
| **Parameter Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array flag element schema |
| **Parameter Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array flag delimiter format (`csv`, `ssv`, `tsv`, `pipes`, `multi`) |
| **Parameter Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default flag value when omitted |
| **Parameter Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric flag upper bound |
| **Parameter Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Exclusive upper bound |
| **Parameter Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric flag lower bound |
| **Parameter Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Exclusive lower bound |
| **Parameter Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maximum string flag length |
| **Parameter Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Minimum string flag length |
| **Parameter Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex flag validation |
| **Parameter Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maximum array flag items |
| **Parameter Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Minimum array flag items |
| **Parameter Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Unique array flag items |
| **Parameter Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allowed enum flag values |
| **Parameter Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric flag multipleOf |
| **Parameter Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter `x-*` extensions |
| **Items Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array flag element schema |
| **Items Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item primitive type |
| **Items Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item format |
| **Items Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array item schema |
| **Items Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array delimiter format |
| **Items Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default item value |
| **Items Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric maximum |
| **Items Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive maximum |
| **Items Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric minimum |
| **Items Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive minimum |
| **Items Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item max string length |
| **Items Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item min string length |
| **Items Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item regex pattern |
| **Items Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array max items |
| **Items Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array min items |
| **Items Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array unique items |
| **Items Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item enum values |
| **Items Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric multipleOf |
| **Items Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item `x-*` extensions |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI output formatting and exit status mapping |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Fallback response definition |
| **Responses Object (`{HTTP Status Code}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Status-code specific response definition |
| **Responses Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Responses `x-*` extensions |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI stdout formatting (`json`, `yaml`, `table`) |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description in `@response` |
| **Response Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response payload schema |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response headers metadata |
| **Response Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response MIME examples |
| **Response Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response `x-*` extensions |
| **Headers Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response headers map |
| **Headers Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named response header |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | MIME-keyed examples map |
| **Example Object (`{mime type}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example per media type |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response header schema and constraints |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description |
| **Header Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header type |
| **Header Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header format |
| **Header Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array items |
| **Header Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array delimiter format |
| **Header Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header default value |
| **Header Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maximum |
| **Header Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusiveMaximum |
| **Header Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minimum |
| **Header Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusiveMinimum |
| **Header Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maxLength |
| **Header Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minLength |
| **Header Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header regex pattern |
| **Header Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maxItems |
| **Header Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minItems |
| **Header Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header uniqueItems |
| **Header Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header enum |
| **Header Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header multipleOf |
| **Header Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header `x-*` extensions |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI command group metadata |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag name |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external docs |
| **Tag Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag `x-*` extensions |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rewrites `#/definitions/...` <-> `#/components/schemas/...` |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional `$ref` pointer rewriting |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates CLI arguments and bodies via `classes.sh` |
| **Schema Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Invokes referenced schema validator |
| **Schema Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates string/numeric formats |
| **Schema Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema title in `@schema_meta` |
| **Schema Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema description in `classes.sh` |
| **Schema Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default value in `@schema_meta` / `@prop_meta` |
| **Schema Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric divisor validation |
| **Schema Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric maximum validation |
| **Schema Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Exclusive maximum validation |
| **Schema Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric minimum validation |
| **Schema Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Exclusive minimum validation |
| **Schema Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String maxLength validation |
| **Schema Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String minLength validation |
| **Schema Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex pattern validation |
| **Schema Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array maxItems validation |
| **Schema Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array minItems validation |
| **Schema Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array uniqueItems validation |
| **Schema Object (`maxProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Object maxProperties validation |
| **Schema Object (`minProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Object minProperties validation |
| **Schema Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required property presence validation |
| **Schema Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enum membership validation |
| **Schema Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | JSON type validation |
| **Schema Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array element validation |
| **Schema Object (`allOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | AllOf composition validation |
| **Schema Object (`properties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Object property validation |
| **Schema Object (`additionalProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Additional properties validation |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Polymorphic discriminator validation |
| **Schema Object (`readOnly`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | ReadOnly property metadata |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML metadata in `@xml` |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs in `@externalDocs` |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example in `@example` |
| **Schema Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema `x-*` extensions |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` annotation |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML name |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML prefix |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML attribute boolean |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML wrapped boolean |
| **XML Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML `x-*` extensions |
| **Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.schemas` |
| **Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named schema definition |
| **Parameters Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.parameters` |
| **Parameters Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named parameter definition |
| **Responses Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.responses` |
| **Responses Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named response definition |
| **Security Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.securitySchemes` |
| **Security Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named security definition |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | CLI `AUTH_*` environment and flag bindings |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `basic`, `apiKey`, `oauth2` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme description |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | API key header/query name |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | API key location (`header` / `query`) |
| **Security Scheme Object (`flow`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 flow (`implicit`, `password`, `application`, `accessCode`) |
| **Security Scheme Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 authorization URL |
| **Security Scheme Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 token URL |
| **Security Scheme Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Security Scheme Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme `x-*` extensions |
| **Scopes Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Scopes Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scope name and description |
| **Scopes Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scopes `x-*` extensions |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required auth scheme map |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme name and required scopes |
