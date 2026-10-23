# OpenAPI 3.2.0 Conformance Table: Client SDK (HTTP Client + Mocks + Tests)

This table tracks the completeness of language integration with OpenAPI 3.2.0 for Client SDK generation and extraction.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the OpenAPI document from strongly typed client SDKs)
*   **From**: OpenAPI -> Language (Generating HTTP Client code, interfaces, and methods from the OpenAPI document)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the Client architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| OpenAPI 3.2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **OpenAPI Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root generation / parsing |
| **OpenAPI Object (`openapi`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits and parses `@openapi 3.2.0` header annotation |
| **OpenAPI Object (`$self`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Base URI resolution for internal and external references |
| **OpenAPI Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional `@info_*` annotations and SDK docstring headers |
| **OpenAPI Object (`jsonSchemaDialect`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recognizing custom dialect validation rules locally |
| **OpenAPI Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default `BASE_URL` and `@server` JSON annotations |
| **OpenAPI Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POSIX `/bin/sh` route client functions in `routes.sh` |
| **OpenAPI Object (`webhooks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Generating local event/webhook parsing utilities (`webhook_*`) |
| **OpenAPI Object (`components`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema validators in `classes.sh` and `@components_*` annotations |
| **OpenAPI Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global `@security` annotation and auth header injection |
| **OpenAPI Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tag_meta` annotations and SDK namespace grouping |
| **OpenAPI Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@externalDocs` root annotation and README link emission |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SDK Header metadata, docstrings, package descriptions |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_title` annotation and SDK header title |
| **Info Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Short package description in `@info_summary` and `README.md` |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_description` annotation and SDK documentation |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_termsOfService` annotation round-tripping |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@contact` JSON annotation and header metadata |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@license` JSON annotation and header metadata |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_version` annotation and SDK version constant |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Package maintainer info in manifest |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer name inside `@contact` metadata |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer URL inside `@contact` metadata |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Maintainer email inside `@contact` metadata |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Package license generation |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name inside `@license` metadata |
| **License Object (`identifier`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Package license SPDX field |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL inside `@license` metadata |
| **Server Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default Base URL configuration in Client builder |
| **Server Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default `BASE_URL` and `SERVER_URL_*` shell variables |
| **Server Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server description in `@server` annotation and docstrings |
| **Server Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Generated as enum/constants for environment selection |
| **Server Object (`variables`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | URL template variable substitution (`SERVER_VAR_*`) |
| **Server Variable Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SDK builder/constructor parameters (e.g. `region`, `env`) |
| **Server Variable Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allowed values validated for `SERVER_VAR_*` |
| **Server Variable Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default fallback value `${SERVER_VAR_name:-default}` |
| **Server Variable Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Variable description preserved in `@server` metadata |
| **Components Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Container for reusable types, interfaces, classes |
| **Components Object (`schemas`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `validate_<Name>()` functions in `classes.sh` |
| **Components Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_responses` and resolved on `$ref` |
| **Components Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_parameters` and resolved on `$ref` |
| **Components Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_examples` and used in mock fixtures |
| **Components Object (`requestBodies`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_requestBodies` and resolved on `$ref` |
| **Components Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_headers` and resolved on `$ref` |
| **Components Object (`securitySchemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `@security_scheme` annotations and auth helpers |
| **Components Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_links` and resolved on `$ref` |
| **Components Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@components_callbacks` and resolved on `$ref` |
| **Components Object (`pathItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable SDK resource group resolution |
| **Components Object (`mediaTypes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable payload serialization definitions |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to top-level client namespaces or groups |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@path` annotation and URL interpolation in `routes.sh` |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Grouping related operations under a single resource |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved against `components.pathItems` and `@path_meta` |
| **Path Item Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path-level summary preserved in `@path_meta` |
| **Path Item Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path-level description preserved in `@path_meta` |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X GET` POSIX `/bin/sh` function |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X PUT` POSIX `/bin/sh` function |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X POST` POSIX `/bin/sh` function |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X DELETE` POSIX `/bin/sh` function |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X OPTIONS` POSIX `/bin/sh` function |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X HEAD` POSIX `/bin/sh` function |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X PATCH` POSIX `/bin/sh` function |
| **Path Item Object (`trace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `curl -s -X TRACE` POSIX `/bin/sh` function |
| **Path Item Object (`query`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | QUERY HTTP method generation |
| **Path Item Object (`additionalOperations`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Custom HTTP method generation |
| **Path Item Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path-scoped server override in `@path_meta` |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level parameters merged into operations |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Specific Client methods (e.g., `client.users.get(id)`) |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tags` annotation on generated shell function |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@summary` annotation and function header docstring |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@description` annotation and function docstring |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_externalDocs` annotation on function |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@function <operationId>` POSIX `/bin/sh` function name |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Positional shell parameters `$1`, `$2`, ... and `@param` tags |
| **Operation Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `body` parameter, `-d "${body}"`, and `@requestBody_meta` |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@response` annotations and response validation helpers |
| **Operation Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@callbacks` JSON annotation on operation |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@deprecated true` annotation on operation |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_security` annotation and per-call auth headers |
| **Operation Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_servers` override URL support |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rendered into method/class Javadoc or IDE docstrings |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Description preserved in `@externalDocs` JSON annotation |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Target URL preserved in `@externalDocs` JSON annotation |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to positional arguments and `@param` metadata |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Sanitized shell variable name and `@param` identifier |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Dispatches to `path`, `query`, `header`, or `cookie` curl flags |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Docstring description in `@param` comment |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `[required]` marker in `@param` and non-empty check |
| **Parameter Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` JSON annotation |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` and query string builder |
| **Parameter Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` and used in generated tests |
| **Parameter Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` and used in generated tests |
| **Parameter Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Serialization style (`form`, `simple`, `matrix`, `label`, `pipeDelimited`, `spaceDelimited`, `deepObject`) |
| **Parameter Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Explode serialization control in `@param_meta` |
| **Parameter Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Skips percent-encoding of reserved characters when true |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter type and constraints in `@param` and `@param_meta` |
| **Parameter Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Media-type map for complex serialized parameters |
| **Request Body Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Typed request payload object/class argument |
| **Request Body Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param $N: body` and `@requestBody_meta` |
| **Request Body Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Media-type map (`application/json`, `multipart/form-data`, etc.) |
| **Request Body Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `[required]` marker on `body` parameter |
| **Media Type Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Automatically setting `Content-Type` / `Accept` headers |
| **Media Type Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Links request/response payload to `validate_<Schema>()` |
| **Media Type Object (`itemSchema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Strong typing for array items in sequential media types |
| **Media Type Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@requestBody_meta` / `@response` and mock fixtures |
| **Media Type Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@requestBody_meta` / `@response` and mock fixtures |
| **Media Type Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Property encoding map in `@requestBody_meta` |
| **Media Type Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Positional tuple item encoding in `@requestBody_meta` |
| **Media Type Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array/stream item encoding in `@requestBody_meta` |
| **Encoding Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | URL-encoding logic for complex queries, multipart builders |
| **Encoding Object (`contentType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-part `Content-Type` in multipart/form-data |
| **Encoding Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-part headers in `@requestBody_meta` |
| **Encoding Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested property encoding map |
| **Encoding Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested positional prefix encoding array |
| **Encoding Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array item encoding definition |
| **Encoding Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form property serialization style |
| **Encoding Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form property explode flag |
| **Encoding Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form property unescaped reserved character flag |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Return type branching (Success types vs. Error throwing) |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@response default` fallback response annotation |
| **Responses Object (`HTTP Status Code`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@response <status>` annotation per HTTP status code |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Strongly typed response payload class wrapper |
| **Response Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Javadoc/Docstring for specific response branches |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description in `@response` annotation |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response header definitions in `@response` annotation |
| **Response Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response media types and schemas in `@response` annotation |
| **Response Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HATEOAS response links in `@response` annotation |
| **Callback Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Often skipped in synchronous SDKs |
| **Callback Object (`{expression}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Runtime expression key in `@callbacks` annotation |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mock HTTP client generation & unit test fixtures |
| **Example Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example summary preserved in AST and docs |
| **Example Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example description preserved in AST and docs |
| **Example Object (`dataValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenAPI 3.2 structured `dataValue` example fixture |
| **Example Object (`serializedValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenAPI 3.2 raw `serializedValue` wire fixture |
| **Example Object (`externalValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External example URI reference |
| **Example Object (`value`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Inline example payload value |
| **Link Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Fluent method chaining helpers (e.g., `resp.getAuthor()`) |
| **Link Object (`operationRef`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Target operation URI reference in `@response` links |
| **Link Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Target operation function identifier in `@response` links |
| **Link Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter expression map for linked operation |
| **Link Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Request body expression for linked operation |
| **Link Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Link description in `@response` metadata |
| **Link Object (`server`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Target server override for linked operation |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Exposing typed headers on the Return/Response object |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description in `@response` / `@components_headers` |
| **Header Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required header constraint |
| **Header Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated header flag |
| **Header Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Inline header example |
| **Header Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named header examples map |
| **Header Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header serialization style (`simple`) |
| **Header Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header explode serialization flag |
| **Header Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header value JSON Schema |
| **Header Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header media type map |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SDK Namespace grouping (e.g., `client.billing.*`) |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag identifier in `@tag_meta` and `@tags` |
| **Tag Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenAPI 3.2 short tag summary in `@tag_meta` |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description in `@tag_meta` |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external documentation in `@tag_meta` |
| **Tag Object (`parent`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested client namespaces (e.g., `client.billing.invoices`) |
| **Tag Object (`kind`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Organizing generated classes by kind |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved and resolved across schemas and components |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Internal/External type resolution |
| **Reference Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference summary override preserved in AST |
| **Reference Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference description override preserved in AST |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `validate_<Name>()` in `classes.sh` with `@schema_meta` |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@discriminator` annotation and polymorphic validator dispatch |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@xml` annotation on class and properties |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@externalDocs` annotation on class |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@example` annotation on class and properties |
| **Discriminator Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Client-side deserialization factories (Polymorphic JSON decoding) |
| **Discriminator Object (`propertyName`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Discriminator key extracted via `jq -r ".<propertyName>"` |
| **Discriminator Object (`mapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Explicit discriminator value-to-schema dispatch table |
| **Discriminator Object (`defaultMapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default fallback for polymorphic deserialization |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML DOM mapping / Often skipped if JSON-only |
| **XML Object (`nodeType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Precise XML DOM mapping controls (`element`, `attribute`, `text`, `cdata`, `none`) |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML element/attribute name override in `@xml` |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace URI in `@xml` |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace prefix in `@xml` |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Legacy XML attribute boolean mapped to `nodeType: "attribute"` |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Legacy XML array wrapper boolean mapped to `nodeType: "element"` |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emitted as `@security_scheme` and `AUTH_*` shell variables |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `apiKey`, `http`, `mutualTLS`, `oauth2`, `openIdConnect` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme description in `@security_scheme` |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header, query, or cookie parameter name for `apiKey` |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `header`, `query`, or `cookie` injection target |
| **Security Scheme Object (`scheme`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HTTP auth scheme (`bearer`, `basic`, etc.) |
| **Security Scheme Object (`bearerFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bearer token format hint (`JWT`, etc.) |
| **Security Scheme Object (`flows`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 flows configuration in `@security_scheme` |
| **Security Scheme Object (`openIdConnectUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenID Connect discovery URL |
| **Security Scheme Object (`oauth2MetadataUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 metadata discovery |
| **Security Scheme Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated security scheme flag |
| **OAuth Flows Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Helpers for token exchange requests |
| **OAuth Flows Object (`implicit`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Implicit OAuth2 flow metadata and auth URL helper |
| **OAuth Flows Object (`password`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resource Owner Password flow token helper |
| **OAuth Flows Object (`clientCredentials`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Client Credentials flow token helper |
| **OAuth Flows Object (`authorizationCode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Authorization Code flow URL and token exchange helper |
| **OAuth Flows Object (`deviceAuthorization`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Support for the Device Authorization grant flow |
| **OAuth Flow Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | URL discovery for token exchange |
| **OAuth Flow Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 authorization endpoint URL |
| **OAuth Flow Object (`deviceAuthorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | SDK method for initiating device flow authentication |
| **OAuth Flow Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 token endpoint URL |
| **OAuth Flow Object (`refreshUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 refresh token endpoint URL |
| **OAuth Flow Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Available OAuth2 scopes map |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Automatic attachment of required auth headers per method |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme name mapped to required scope list |
