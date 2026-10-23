# Swagger 2.0 Conformance Table: Servers (ORM + REST API + Mocks + Tests)

This table tracks the completeness of language integration with Swagger 2.0 for server-side generation and extraction.

### Legend & Tracking Guide
*   **To**: Language -> OpenAPI (Generating the Swagger document from code/types/decorators)
*   **From**: OpenAPI -> Language (Generating server stubs/types/ORM models from the Swagger document)
*   **Presence `[To, From]`**: The object is successfully parsed, validated, utilized, or generated.
*   **Absence `[To, From]`**: The object is currently unsupported, dropped, or falls back to generic/`any` types.
*   **Skipped `[To, From]`**: Intentionally ignored because it is irrelevant or unsupported by the architecture.
*   **Checkboxes**: Mark `[x]` as conformance is achieved.

| Swagger 2.0 Object / Feature | Presence `[To, From]` | Absence `[To, From]` | Skipped `[To, From]` | Notes / Implementation Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Swagger Object (Root)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root server generation and extraction via `swagger2openapi.jq` / `openapi2swagger.jq` |
| **Swagger Object (`swagger`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recognizes `"2.0"` on input and emits `"2.0"` with `--openapi-version 2.0` |
| **Swagger Object (`info`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server metadata, MCP serverInfo, and `@info_*` annotations |
| **Swagger Object (`host`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Host and port binding in `@server` |
| **Swagger Object (`basePath`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Stripped from incoming request paths in `routes.sh` and preserved in `@server` |
| **Swagger Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server URL schemes preserved in `@server` |
| **Swagger Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Incoming request `Content-Type` validation |
| **Swagger Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Outgoing response `Content-Type` header |
| **Swagger Object (`paths`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POSIX `/bin/sh` HTTP request router in `routes.sh` |
| **Swagger Object (`definitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `models.sh`, `daos/*.sh`, and `faker.awk` seeder |
| **Swagger Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable route parameter definitions in `@components_parameters` |
| **Swagger Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Reusable server response templates in `@components_responses` |
| **Swagger Object (`securityDefinitions`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server auth enforcement middleware and `@security_scheme` |
| **Swagger Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Global server authentication check in `routes.sh` |
| **Swagger Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Route grouping, DAO entity resolution, and `@tag_meta` |
| **Swagger Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` |
| **Swagger Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Root `x-*` extensions preserved in `@root_extensions` |
| **Info Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server metadata and `@info_*` annotations |
| **Info Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_title` annotation |
| **Info Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_description` annotation |
| **Info Object (`termsOfService`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_termsOfService` annotation |
| **Info Object (`contact`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@contact` JSON annotation |
| **Info Object (`license`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@license` JSON annotation |
| **Info Object (`version`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@info_version` annotation |
| **Info Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Info `x-*` extensions in `@info_extensions` |
| **Contact Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact metadata in `@contact` |
| **Contact Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact name |
| **Contact Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact URL |
| **Contact Object (`email`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact email |
| **Contact Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Contact `x-*` extensions |
| **License Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License metadata in `@license` |
| **License Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License name |
| **License Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License URL |
| **License Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | License `x-*` extensions |
| **Paths Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server route dispatcher in `routes.sh` |
| **Paths Object (`/{path}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex path matching and path parameter extraction |
| **Paths Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Paths `x-*` extensions in `@paths_extensions` |
| **Path Item Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Route handlers grouped by path |
| **Path Item Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `$ref` resolution |
| **Path Item Object (`get`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | GET route handler and DAO query dispatch |
| **Path Item Object (`put`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | PUT route handler and DAO update dispatch |
| **Path Item Object (`post`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | POST route handler and DAO create dispatch |
| **Path Item Object (`delete`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | DELETE route handler and DAO delete dispatch |
| **Path Item Object (`options`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OPTIONS route handler and CORS preflight |
| **Path Item Object (`head`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | HEAD route handler |
| **Path Item Object (`patch`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | PATCH route handler and DAO partial update dispatch |
| **Path Item Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Shared path-level parameter extraction and validation |
| **Path Item Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path item `x-*` extensions in `@path_meta` |
| **Operation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `handle_<operationId>()` POSIX `/bin/sh` function |
| **Operation Object (`tags`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@tags` annotation and DAO entity mapping |
| **Operation Object (`summary`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@summary` annotation on handler |
| **Operation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@description` annotation on handler |
| **Operation Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@operation_externalDocs` annotation |
| **Operation Object (`operationId`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Handler function name `handle_<operationId>` |
| **Operation Object (`consumes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation request `Content-Type` validation |
| **Operation Object (`produces`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation response `Content-Type` header |
| **Operation Object (`parameters`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Path, query, header, formData, and body validation (HTTP 400) |
| **Operation Object (`responses`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response status code, headers, and payload serialization |
| **Operation Object (`schemes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation server scheme metadata |
| **Operation Object (`deprecated`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `@deprecated true` annotation |
| **Operation Object (`security`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-route auth check returning HTTP 401 |
| **Operation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Operation `x-*` extensions in `@operation_extensions` |
| **External Documentation Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` |
| **External Documentation Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs description |
| **External Documentation Object (`url`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs URL |
| **External Documentation Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | External docs `x-*` extensions |
| **Parameter Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server parameter extraction and HTTP 400 validation |
| **Parameter Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter name in `routes.sh` |
| **Parameter Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `path`, `query`, `header`, `formData`, and `body` extraction |
| **Parameter Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter docstring in `@param` |
| **Parameter Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforces non-empty value (HTTP 400 on missing) |
| **Parameter Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `in: body` payload via `validate_<Schema>()` |
| **Parameter Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `integer`, `number`, `boolean`, `array`, `string` |
| **Parameter Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates `uuid`, `email`, `date`, `date-time`, `uri`, `ipv4`, `ipv6` |
| **Parameter Object (`allowEmptyValue`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Permits empty query value |
| **Parameter Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validates array parameter elements |
| **Parameter Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Splits `csv`, `ssv`, `tsv`, `pipes`, and `multi` parameters |
| **Parameter Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default parameter value when omitted |
| **Parameter Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric upper bound check |
| **Parameter Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Strict upper bound check |
| **Parameter Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric lower bound check |
| **Parameter Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Strict lower bound check |
| **Parameter Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String maxLength check |
| **Parameter Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | String minLength check |
| **Parameter Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Regex pattern check |
| **Parameter Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array maxItems check |
| **Parameter Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array minItems check |
| **Parameter Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array uniqueItems check |
| **Parameter Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enum membership check |
| **Parameter Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Numeric multipleOf check |
| **Parameter Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Parameter `x-*` extensions |
| **Items Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Array item validation in `routes.sh` |
| **Items Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item primitive type check |
| **Items Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item format check |
| **Items Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array item validation |
| **Items Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array delimiter parsing |
| **Items Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default item value |
| **Items Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric maximum |
| **Items Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive maximum |
| **Items Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item numeric minimum |
| **Items Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item exclusive minimum |
| **Items Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item max string length |
| **Items Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item min string length |
| **Items Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item regex pattern |
| **Items Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array maxItems |
| **Items Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array minItems |
| **Items Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Nested array uniqueItems |
| **Items Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item enum values |
| **Items Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item multipleOf |
| **Items Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Item `x-*` extensions |
| **Responses Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Server HTTP status and payload emission |
| **Responses Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default response fallback |
| **Responses Object (`{HTTP Status Code}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Status-code keyed response |
| **Responses Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Responses `x-*` extensions |
| **Response Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Serializes DAO/mock payload and headers |
| **Response Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response description in `@response` |
| **Response Object (`schema`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Links response to DAO entity and mock generator |
| **Response Object (`headers`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits HTTP response headers |
| **Response Object (`examples`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Static fallback fixture in mock server mode |
| **Response Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response `x-*` extensions |
| **Headers Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response headers map |
| **Headers Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named response header |
| **Example Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | MIME-keyed response examples |
| **Example Object (`{mime type}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mock response payload per media type |
| **Header Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Response header schema |
| **Header Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header description |
| **Header Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header type |
| **Header Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header format |
| **Header Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array items |
| **Header Object (`collectionFormat`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header array delimiter format |
| **Header Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default header value emitted in response |
| **Header Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maximum |
| **Header Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusiveMaximum |
| **Header Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minimum |
| **Header Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header exclusiveMinimum |
| **Header Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maxLength |
| **Header Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minLength |
| **Header Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header pattern |
| **Header Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header maxItems |
| **Header Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header minItems |
| **Header Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header uniqueItems |
| **Header Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header enum |
| **Header Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header multipleOf |
| **Header Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header `x-*` extensions |
| **Tag Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Route grouping and DAO entity resolution |
| **Tag Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag name |
| **Tag Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag description |
| **Tag Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag external docs |
| **Tag Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Tag `x-*` extensions |
| **Reference Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Rewrites `#/definitions/...` <-> `#/components/schemas/...` |
| **Reference Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Bidirectional `$ref` resolution & topological FK graph sorting |
| **Schema Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `models.sh`, `daos/<entity>.sh`, and `faker.awk` |
| **Schema Object (`$ref`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Validator delegation and relational FK linking |
| **Schema Object (`format`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Format validation and format-aware `faker.awk` synthesis |
| **Schema Object (`title`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema title in `@schema_meta` |
| **Schema Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Model and property docstrings |
| **Schema Object (`default`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Default field value in mock synthesis |
| **Schema Object (`multipleOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and respected in `faker.awk` |
| **Schema Object (`maximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and bounded in `faker.awk` |
| **Schema Object (`exclusiveMaximum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and bounded in `faker.awk` |
| **Schema Object (`minimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and bounded in `faker.awk` |
| **Schema Object (`exclusiveMinimum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and bounded in `faker.awk` |
| **Schema Object (`maxLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and bounded in `faker.awk` |
| **Schema Object (`minLength`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and padded in `faker.awk` |
| **Schema Object (`pattern`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` regex validator |
| **Schema Object (`maxItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` array validator |
| **Schema Object (`minItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and synthesized in `faker.awk` |
| **Schema Object (`uniqueItems`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` array uniqueness validator |
| **Schema Object (`maxProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` object validator |
| **Schema Object (`minProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` object validator |
| **Schema Object (`required`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and always populated by `faker.awk` |
| **Schema Object (`enum`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and sampled by `faker.awk` |
| **Schema Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `models.sh` and dispatched in `faker.awk` |
| **Schema Object (`items`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Recursive array element validation and synthesis |
| **Schema Object (`allOf`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Merged composition validation and synthesis |
| **Schema Object (`properties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Per-field validation and heuristic faker synthesis |
| **Schema Object (`additionalProperties`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Map value validation and unknown-key rejection |
| **Schema Object (`discriminator`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Polymorphic model validation and discriminator synthesis |
| **Schema Object (`readOnly`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@prop_meta` |
| **Schema Object (`xml`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` |
| **Schema Object (`externalDocs`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@externalDocs` |
| **Schema Object (`example`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Used as fallback fixture in mock server |
| **Schema Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Schema `x-*` extensions |
| **XML Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Preserved in `@xml` annotation |
| **XML Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML name |
| **XML Object (`namespace`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML namespace |
| **XML Object (`prefix`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML prefix |
| **XML Object (`attribute`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML attribute flag |
| **XML Object (`wrapped`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML wrapped flag |
| **XML Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | XML `x-*` extensions |
| **Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.schemas` |
| **Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Emits `validate_<name>()` and `daos/<name>.sh` |
| **Parameters Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.parameters` |
| **Parameters Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named reusable parameter |
| **Responses Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.responses` |
| **Responses Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named reusable response |
| **Security Definitions Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Mapped to/from `components.securitySchemes` |
| **Security Definitions Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Named security definition |
| **Security Scheme Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced in `routes.sh` auth middleware |
| **Security Scheme Object (`type`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `basic`, `apiKey`, `oauth2` |
| **Security Scheme Object (`description`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme description |
| **Security Scheme Object (`name`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Header or query parameter name checked by server |
| **Security Scheme Object (`in`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | `header` or `query` extraction location |
| **Security Scheme Object (`flow`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 flow (`implicit`, `password`, `application`, `accessCode`) |
| **Security Scheme Object (`authorizationUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 authorization URL |
| **Security Scheme Object (`tokenUrl`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 token URL |
| **Security Scheme Object (`scopes`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Security Scheme Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Security scheme `x-*` extensions |
| **Scopes Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | OAuth2 scopes map |
| **Scopes Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scope name and description |
| **Scopes Object (`^x-`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scopes `x-*` extensions |
| **Security Requirement Object** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Enforced per route or globally in `routes.sh` |
| **Security Requirement Object (`{name}`)** | `[x]` , `[x]` | `[-]` , `[-]` | `[-]` , `[-]` | Scheme name and required scopes |
