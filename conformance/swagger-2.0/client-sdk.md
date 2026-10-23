# Swagger 2.0 Conformance Table: Client SDK (HTTP Client + Mocks + Tests)

This table tracks the completeness of language integration with Swagger 2.0 for Client SDK generation and extraction.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the Swagger document from strongly typed client SDKs)
*   **From**: OpenAPI -> Language (Generating HTTP Client code, interfaces, and methods from the Swagger document)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| Swagger 2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Swagger Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root Swagger 2.0 <-> OpenAPI 3.2.0 AST bridge (`swagger2openapi.jq` / `openapi2swagger.jq`) |
| **Swagger Object (`swagger`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recognizes `"2.0"` on input and emits `"2.0"` with `--openapi-version 2.0` |
| **Swagger Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional `@info_*` annotations and SDK header docstrings |
| **Swagger Object (`host`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Combined with `schemes` and `basePath` into `BASE_URL` / `@server` |
| **Swagger Object (`basePath`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Extracted from and reconstructed into `servers[0].url` |
| **Swagger Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from server URL protocols (`https`, `http`) |
| **Swagger Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `requestBody.content` media types |
| **Swagger Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `responses.{status}.content` media types |
| **Swagger Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POSIX `/bin/sh` route functions in `routes.sh` |
| **Swagger Object (`definitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.schemas` and `classes.sh` validators |
| **Swagger Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.parameters` (`@components_parameters`) |
| **Swagger Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.responses` (`@components_responses`) |
| **Swagger Object (`securityDefinitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.securitySchemes` (`@security_scheme`) |
| **Swagger Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global `@security` annotation and auth header injection |
| **Swagger Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tag_meta` annotations and SDK namespace grouping |
| **Swagger Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@externalDocs` root annotation and README link |
| **Swagger Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root specification extensions preserved via `@root_extensions` |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SDK header metadata and `@info_*` annotations |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_title` annotation |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_description` annotation |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_termsOfService` annotation |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@contact` JSON annotation |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@license` JSON annotation |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_version` annotation |
| **Info Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Info extensions preserved via `@info_extensions` |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer metadata in `@contact` |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer name in `@contact` |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer URL in `@contact` |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer email in `@contact` |
| **Contact Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact `x-*` extensions preserved in `@contact` JSON |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License metadata in `@license` |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name in `@license` |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL in `@license` |
| **License Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License `x-*` extensions preserved in `@license` JSON |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to POSIX `/bin/sh` functions in `routes.sh` |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@path` annotation and URL path parameter substitution |
| **Paths Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Paths `x-*` extensions preserved in `@paths_extensions` |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Route group per URI template |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `$ref` resolution and `@path_meta` preservation |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X GET` POSIX `/bin/sh` function |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X PUT` POSIX `/bin/sh` function |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X POST` POSIX `/bin/sh` function |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X DELETE` POSIX `/bin/sh` function |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X OPTIONS` POSIX `/bin/sh` function |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X HEAD` POSIX `/bin/sh` function |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X PATCH` POSIX `/bin/sh` function |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level parameters merged into operations |
| **Path Item Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `x-*` extensions preserved in `@path_meta` |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Individual SDK client function in `routes.sh` |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tags` annotation on shell function |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@summary` annotation and function docstring |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@description` annotation and function docstring |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_externalDocs` annotation |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@function <operationId>` POSIX `/bin/sh` function name |
| **Operation Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from operation `requestBody.content` keys |
| **Operation Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from operation `responses.{status}.content` keys |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Positional shell arguments and `in: body` / `in: formData` conversion |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@response` annotations per status code |
| **Operation Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from operation `servers` override |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@deprecated true` annotation |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_security` annotation and auth header injection |
| **Operation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation `x-*` extensions preserved via `@operation_extensions` |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` and `@operation_externalDocs` |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Description in `@externalDocs` |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | URL in `@externalDocs` |
| **External Documentation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Extensions preserved in `@externalDocs` JSON |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to positional arguments and `@param` / `@param_meta` |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter name in `@param` |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Supports `query`, `header`, `path`, `formData`, and `body` |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter docstring in `@param` |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `[required]` marker and runtime non-empty validation |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Body parameter schema mapped to/from `requestBody` |
| **Parameter Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Non-body parameter primitive/array/file type |
| **Parameter Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter format (`int64`, `date-time`, `uuid`, etc.) |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` |
| **Parameter Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array parameter item schema |
| **Parameter Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from OpenAPI `style` and `explode` (`csv`, `ssv`, `tsv`, `pipes`, `multi`) |
| **Parameter Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default parameter fallback value |
| **Parameter Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric upper bound constraint |
| **Parameter Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Boolean/numeric exclusive upper bound conversion |
| **Parameter Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric lower bound constraint |
| **Parameter Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Boolean/numeric exclusive lower bound conversion |
| **Parameter Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String maximum length constraint |
| **Parameter Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String minimum length constraint |
| **Parameter Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex pattern constraint |
| **Parameter Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array maximum items constraint |
| **Parameter Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array minimum items constraint |
| **Parameter Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array unique items constraint |
| **Parameter Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allowed enum values array |
| **Parameter Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric divisor constraint |
| **Parameter Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter `x-*` extensions preserved in `@param_meta` |
| **Items Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array element schema in parameters and headers |
| **Items Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array item primitive type |
| **Items Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array item data format |
| **Items Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested multi-dimensional array item definition |
| **Items Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array delimiter format |
| **Items Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default array item value |
| **Items Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric maximum |
| **Items Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive maximum |
| **Items Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric minimum |
| **Items Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive minimum |
| **Items Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item maximum string length |
| **Items Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item minimum string length |
| **Items Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item regex validation pattern |
| **Items Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array maximum length |
| **Items Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array minimum length |
| **Items Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array uniqueness flag |
| **Items Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item enum values |
| **Items Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric multipleOf |
| **Items Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item `x-*` extensions |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation responses map in `@response` annotations |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default fallback response |
| **Responses Object (`{HTTP Status Code}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Status-code keyed response definition |
| **Responses Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Responses `x-*` extensions |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Converted to/from OpenAPI 3.2 response `content` and `headers` |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description string |
| **Response Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `content[mime].schema` |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from response `headers` |
| **Response Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `content[mime].example` |
| **Response Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response `x-*` extensions preserved in `@response` |
| **Headers Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Map of response header definitions |
| **Headers Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named response header entry |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | MIME-keyed response examples map |
| **Example Object (`{mime type}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example payload per MIME type |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response header schema and constraints |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description |
| **Header Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header primitive/array type |
| **Header Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header format |
| **Header Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array item schema |
| **Header Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array delimiter format |
| **Header Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default header value |
| **Header Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header numeric maximum |
| **Header Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusive maximum |
| **Header Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header numeric minimum |
| **Header Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusive minimum |
| **Header Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header max string length |
| **Header Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header min string length |
| **Header Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header regex pattern |
| **Header Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header max array items |
| **Header Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header min array items |
| **Header Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header unique array items |
| **Header Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header enum values |
| **Header Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header numeric multipleOf |
| **Header Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header `x-*` extensions |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@tag_meta` |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag name in `@tag_meta` |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description in `@tag_meta` |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external docs in `@tag_meta` |
| **Tag Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag `x-*` extensions in `@tag_meta` |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rewrites `#/definitions/...` <-> `#/components/schemas/...` |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional `$ref` pointer rewriting |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `validate_<Name>()` in `classes.sh` |
| **Schema Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Calls `validate_<RefTarget>()` |
| **Schema Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `email`, `uuid`, `date`, `date-time`, `uri`, `ipv4`, `ipv6` |
| **Schema Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@schema_meta` |
| **Schema Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted in `@description` and `@property` docstrings |
| **Schema Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@schema_meta` and `@prop_meta` |
| **Schema Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` numeric validator |
| **Schema Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` numeric validator |
| **Schema Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Boolean Swagger 2.0 <-> numeric OAS 3.2 conversion |
| **Schema Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` numeric validator |
| **Schema Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Boolean Swagger 2.0 <-> numeric OAS 3.2 conversion |
| **Schema Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` string length validator |
| **Schema Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` string length validator |
| **Schema Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` regex validator |
| **Schema Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` array length validator |
| **Schema Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` array length validator |
| **Schema Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` array uniqueness validator |
| **Schema Object (`maxProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` object property count validator |
| **Schema Object (`minProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` object property count validator |
| **Schema Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `[required]` marker in `@property` and presence check in `classes.sh` |
| **Schema Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` enum validator |
| **Schema Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `classes.sh` type check (`string`, `integer`, `number`, `boolean`, `array`, `object`) |
| **Schema Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recursive array element validation in `classes.sh` |
| **Schema Object (`allOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Composition validator invoking all member schemas |
| **Schema Object (`properties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-property `@property` annotations and field checks |
| **Schema Object (`additionalProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Map/dictionary value validation and unknown-key rejection |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String Swagger 2.0 `discriminator` <-> OAS 3.2 `{propertyName}` object |
| **Schema Object (`readOnly`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@prop_meta` |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` annotation |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` annotation |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@example` annotation |
| **Schema Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@schema_meta` / `@prop_meta` |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional Swagger 2.0 `attribute`/`wrapped` <-> OAS 3.2 `nodeType` |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML tag/attribute name in `@xml` |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace URI in `@xml` |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace prefix in `@xml` |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Converted to/from `nodeType: "attribute"` |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Converted to/from `nodeType: "element"` |
| **XML Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML `x-*` extensions preserved in `@xml` |
| **Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.schemas` |
| **Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `validate_<name>()` in `classes.sh` |
| **Parameters Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.parameters` |
| **Parameters Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named reusable parameter in `@components_parameters` |
| **Responses Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.responses` |
| **Responses Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named reusable response in `@components_responses` |
| **Security Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.securitySchemes` |
| **Security Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named security scheme in `@security_scheme` |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Converted between Swagger 2.0 `basic`/`apiKey`/`oauth2` and OAS 3.2 |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `basic` <-> `http/basic`, `apiKey`, `oauth2` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme description in `@security_scheme` |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header or query parameter name for `apiKey` |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `header` or `query` location for `apiKey` |
| **Security Scheme Object (`flow`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `implicit`, `password`, `application` (`clientCredentials`), `accessCode` (`authorizationCode`) |
| **Security Scheme Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 authorization URL |
| **Security Scheme Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 token URL |
| **Security Scheme Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Security Scheme Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme `x-*` extensions |
| **Scopes Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Map of OAuth2 scope names to descriptions |
| **Scopes Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Individual scope entry |
| **Scopes Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scope `x-*` extensions |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global `@security` and per-operation `@operation_security` |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme name mapped to required scopes array |
