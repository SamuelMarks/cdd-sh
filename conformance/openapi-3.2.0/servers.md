# OpenAPI 3.2.0 Conformance Table: Servers (ORM + REST API + Mocks + Tests)

This table tracks the completeness of language integration with OpenAPI 3.2.0 for server-side generation and extraction.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the OpenAPI document from code/types/decorators)
*   **From**: OpenAPI -> Language (Generating server stubs/types/ORM models from the OpenAPI document)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the server architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| OpenAPI 3.2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **OpenAPI Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root document initialization |
| **OpenAPI Object (`openapi`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits and parses `@openapi 3.2.0` on server artifacts |
| **OpenAPI Object (`$self`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Base URI resolution for internal and external references |
| **OpenAPI Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server banner, `/_docs` metadata, and `@info_*` annotations |
| **OpenAPI Object (`jsonSchemaDialect`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validating schemas against explicit JSON Schema drafts |
| **OpenAPI Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Port/basePath binding and `@server` annotations |
| **OpenAPI Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POSIX `/bin/sh` HTTP request router in `routes.sh` |
| **OpenAPI Object (`webhooks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Independent webhook routing & `/_mock/webhooks/<name>` trigger |
| **OpenAPI Object (`components`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Models (`models.sh`), DAOs (`daos/`), and `@components_*` |
| **OpenAPI Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global auth enforcement middleware in `routes.sh` |
| **OpenAPI Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Route grouping and `@tag_meta` annotations |
| **OpenAPI Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` and server README |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global API Metadata (Title, Version, Description) |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server title in `@info_title` and MCP serverInfo |
| **Info Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global API short summary docstring |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server description in `@info_description` |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@info_termsOfService` |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@contact` JSON annotation |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@license` JSON annotation |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server version in `@info_version` and MCP serverInfo |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Included in generated docs/metadata |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact name in `@contact` |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact URL in `@contact` |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact email in `@contact` |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Included in generated docs/metadata |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name in `@license` |
| **License Object (`identifier`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server metadata / openapi.json generation |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL in `@license` |
| **Server Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Base URL generation, Router namespace/prefix mounting |
| **Server Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Base path prefix stripping and default listen port |
| **Server Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server description in `@server` |
| **Server Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server/Router instance naming |
| **Server Object (`variables`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Dynamic route prefix variables in `@server` |
| **Server Variable Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Dynamic route prefix validation / Enum injection |
| **Server Variable Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Allowed values for server variable |
| **Server Variable Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default server variable value |
| **Server Variable Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server variable description |
| **Components Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Container for reusable ORM models, DTOs, Handlers |
| **Components Object (`schemas`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `models.sh`, `daos/*.sh`, and seeder factories |
| **Components Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable response templates in `@components_responses` |
| **Components Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable route parameter validators in `@components_parameters` |
| **Components Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable mock response fixtures in `@components_examples` |
| **Components Object (`requestBodies`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable request body validators in `@components_requestBodies` |
| **Components Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable response headers in `@components_headers` |
| **Components Object (`securitySchemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server auth verification middleware in `routes.sh` |
| **Components Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable HATEOAS links in `@components_links` |
| **Components Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable webhook callbacks in `@components_callbacks` |
| **Components Object (`pathItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable router mounting blocks |
| **Components Object (`mediaTypes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable content negotiation blocks |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Core router mounting and path mapping |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex path matching and path parameter capture in `routes.sh` |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Grouping endpoints by URI / Route-level parameters |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved against `components.pathItems` |
| **Path Item Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path summary in `@path_meta` |
| **Path Item Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path description in `@path_meta` |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | GET route handler and DAO `find_all` / `find_by_id` dispatch |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | PUT route handler and DAO `update` dispatch |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POST route handler and DAO `create` dispatch |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | DELETE route handler and DAO `delete` dispatch |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OPTIONS route handler and CORS preflight responder |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HEAD route handler |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | PATCH route handler and partial DAO `update` dispatch |
| **Path Item Object (`trace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | TRACE route handler |
| **Path Item Object (`query`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | QUERY HTTP method handler binding |
| **Path Item Object (`additionalOperations`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Custom HTTP method handler bindings |
| **Path Item Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path-scoped server metadata |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level parameter extraction and validation |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Individual Controller/Handler method bindings |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tags` annotation and DAO entity resolution |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@summary` annotation on handler |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@description` annotation on handler |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_externalDocs` annotation on handler |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Handler function name `handle_<operationId>()` |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path, query, header, and cookie extraction & 400 validation |
| **Operation Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Request JSON body validation (`validate_<Schema>`) & DAO input |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HTTP status code, headers, and response body serialization |
| **Operation Object (`callbacks`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Outbound callback dispatcher & `@callbacks` annotation |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@deprecated true` annotation on handler |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-route `Authorization` / API key check returning 401 |
| **Operation Object (`servers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_servers` annotation on handler |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Javadoc/Docstring generation or extraction |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Description in `@externalDocs` |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Documentation URL in `@externalDocs` |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server-side parameter extraction and validation |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Extracted parameter name in `routes.sh` |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `path`, `query`, `header`, or `cookie` extractor |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter docstring in `@param` |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Returns HTTP 400 when required parameter is missing |
| **Parameter Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@param_meta` |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Permits empty query parameter value |
| **Parameter Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Used in generated server contract tests (`emit_tests.jq`) |
| **Parameter Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Used in generated server contract tests |
| **Parameter Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Delimiter parsing for query/path/header arrays |
| **Parameter Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Repeated vs delimiter-joined parameter parsing |
| **Parameter Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserves reserved characters during decoding |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Type, enum, numeric range, and regex validation (HTTP 400) |
| **Parameter Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | JSON-encoded parameter parsing |
| **Request Body Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Payload parsing, ORM hydration, and validation limits |
| **Request Body Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@requestBody_meta` |
| **Request Body Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Content-Type routing and schema validation |
| **Request Body Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Returns HTTP 400 when required body is empty |
| **Media Type Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Content negotiation & Content-Type specific routing |
| **Media Type Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Invokes `validate_<Schema>()` on incoming request body |
| **Media Type Object (`itemSchema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validation middleware for sequential payload elements |
| **Media Type Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mock server static fallback response payload |
| **Media Type Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named mock server response fixtures |
| **Media Type Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Multipart/form-data property encoding |
| **Media Type Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tuple item encoding in `@requestBody_meta` |
| **Media Type Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array item encoding in `@requestBody_meta` |
| **Encoding Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Handling multipart/form-data boundary & URL-encoded arrays |
| **Encoding Object (`contentType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Multipart part Content-Type validation |
| **Encoding Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Multipart part header extraction |
| **Encoding Object (`encoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested multipart encoding rules |
| **Encoding Object (`prefixEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested positional encoding rules |
| **Encoding Object (`itemEncoding`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested item encoding rules |
| **Encoding Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field style parsing |
| **Encoding Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field explode parsing |
| **Encoding Object (`allowReserved`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Form field reserved character allowance |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Status code mapping (`200`, `4xx`) & `default` fallback handlers |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default error response status and payload |
| **Responses Object (`HTTP Status Code`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Primary 2xx/4xx/5xx status code emission in `routes.sh` |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Outgoing DTO serialization & header formatting |
| **Response Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Docstring generation for handler responses |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description in `@response` |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits HTTP response headers in `routes.sh` |
| **Response Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `Content-Type` and serialized JSON/XML response body |
| **Response Object (`links`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@response` metadata |
| **Callback Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Async out-of-band webhook dispatchers |
| **Callback Object (`{expression}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Callback URL runtime expression in `@callbacks` |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Generating mock server endpoints / Test fixtures |
| **Example Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example summary in AST |
| **Example Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Example description in AST |
| **Example Object (`dataValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenAPI 3.2 structured `dataValue` mock response |
| **Example Object (`serializedValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OpenAPI 3.2 raw `serializedValue` mock response |
| **Example Object (`externalValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External example reference in AST |
| **Example Object (`value`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Inline example used by mock server and tests |
| **Link Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HATEOAS / Relation mapping generation for APIs |
| **Link Object (`operationRef`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked operation URI in `@response` |
| **Link Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked operation ID in `@response` |
| **Link Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked operation parameters map |
| **Link Object (`requestBody`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Linked operation requestBody expression |
| **Link Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Link description in `@response` |
| **Link Object (`server`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Link server override in `@response` |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Setting strongly-typed response headers (e.g. `X-RateLimit`) |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description in `@response` |
| **Header Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required response header check |
| **Header Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated response header flag |
| **Header Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default mock response header value |
| **Header Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named mock response header examples |
| **Header Object (`style`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header serialization style |
| **Header Object (`explode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header explode flag |
| **Header Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header value type and format |
| **Header Object (`content`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header content media type map |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Controller grouping, DAO entity resolution |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag name in `@tag_meta` and `@tags` |
| **Tag Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag summary in `@tag_meta` |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description in `@tag_meta` |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external docs in `@tag_meta` |
| **Tag Object (`parent`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Controller inheritance / nested routers |
| **Tag Object (`kind`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Controller categorization metadata |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Resolved for request/response validation and DAO foreign keys |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Internal component resolution & topological FK graph sorting |
| **Reference Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference summary override |
| **Reference Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reference description override |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `models.sh` validators, `daos/<entity>.sh`, and `faker.awk` |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Polymorphic validator and mock payload synthesis |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@xml` annotation on models |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@externalDocs` annotation on models |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@example` annotation and mock response fallback |
| **Discriminator Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Polymorphism / Single Table Inheritance ORM parsing |
| **Discriminator Object (`propertyName`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Discriminator field extracted during request validation |
| **Discriminator Object (`mapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Explicit discriminator value-to-schema dispatch |
| **Discriminator Object (`defaultMapping`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Fallback STI mapping in ORM when missing type |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML DOM serialization/deserialization |
| **XML Object (`nodeType`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML deserialization binding rules (`attribute`/`element`) |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML element/attribute name in `@xml` |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace URI in `@xml` |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML prefix in `@xml` |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `nodeType: "attribute"` |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to `nodeType: "element"` |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `routes.sh` and preserved in `@security_scheme` |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `apiKey`, `http`, `mutualTLS`, `oauth2`, `openIdConnect` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme description in `@security_scheme` |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header, query, or cookie name checked by server |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `header`, `query`, or `cookie` extraction in `routes.sh` |
| **Security Scheme Object (`scheme`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `Bearer` / `Basic` header validation in `routes.sh` |
| **Security Scheme Object (`bearerFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bearer format metadata (`JWT`) |
| **Security Scheme Object (`flows`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 flows preserved in `@security_scheme` |
| **Security Scheme Object (`openIdConnectUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OIDC discovery URL preserved in `@security_scheme` |
| **Security Scheme Object (`oauth2MetadataUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 metadata discovery |
| **Security Scheme Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Deprecated security scheme flag |
| **OAuth Flows Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Registering endpoints for supported grant types |
| **OAuth Flows Object (`implicit`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Implicit flow metadata in `@security_scheme` |
| **OAuth Flows Object (`password`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Password flow metadata in `@security_scheme` |
| **OAuth Flows Object (`clientCredentials`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Client credentials flow metadata in `@security_scheme` |
| **OAuth Flows Object (`authorizationCode`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Authorization code flow metadata in `@security_scheme` |
| **OAuth Flows Object (`deviceAuthorization`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Support for the Device Authorization grant flow |
| **OAuth Flow Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Extracting flow metadata (auth URL, token URL, scopes) |
| **OAuth Flow Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 authorization URL |
| **OAuth Flow Object (`deviceAuthorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Routing for issuing device codes |
| **OAuth Flow Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 token URL |
| **OAuth Flow Object (`refreshUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 refresh URL |
| **OAuth Flow Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforcing endpoint-level combinations (AND/OR auth logic) |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Required scheme and scope check in `routes.sh` |
