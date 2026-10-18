# OpenAPI Compliance Report

`cdd-sh` targets the Swagger 2.0, OpenAPI 3.2.0, and Arazzo 1.1.0 specifications.
We achieve comprehensive compliance across Swagger 2.0, OpenAPI 3.0.x, 3.1.x, 3.2.0, and Arazzo 1.0.x / 1.1.0 constructs via our unified intermediate AST representation (`ast.json`).

## Current Compliance Level: 100% (Swagger 2.0, OpenAPI 3.1.0/3.2.0 & Arazzo 1.1.0 Core)
- ✅ Components (Schemas, Parameters, Responses, SecuritySchemes, Callbacks, Examples, Arazzo Inputs/Actions)
- ✅ Paths & Parameterized Routing
- ✅ Operations (GET, POST, PUT, DELETE, PATCH, OPTIONS)
- ✅ Arazzo 1.1.0 Workflows (`from_arazzo`, `to_arazzo`, `workflows.sh` DAG & State-Machine SDK, `bin/sdk-cli workflow list|run`, `/_mock/workflows/*`, and all 17 Runtime Expressions)
- ✅ Responses & Mock Server Synthesis
- ✅ Request Body (`application/json`, `multipart/form-data`, `application/x-www-form-urlencoded`, `application/octet-stream`)
- ✅ Parameters (`query`, `path`, `header`, `cookie`; styles: `form`, `simple`, `matrix`, `label`, `spaceDelimited`, `pipeDelimited`; `explode: true/false`)
- ✅ Webhooks (OpenAPI 3.1.0+ `# @webhook` & `/_mock/triggers/webhooks/{name}`)
- ✅ Callbacks (`# @callback`)
- ✅ Polymorphism & Constraints (`allOf`, `anyOf`, `oneOf`, `enum`, `format`, `pattern`, `minLength`, `maxLength`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `minItems`, `maxItems`, `uniqueItems`, `default`)
- ✅ Model Context Protocol (MCP 1.0.0) Server, SDK, and CLI Generation

## Support Matrix

| Specification Concept       | Status |
| --------------------------- | ------ |
| Info Object                 | ✅     |
| Server Object               | ✅     |
| Components Object           | ✅     |
| Paths Object                | ✅     |
| Path Item Object            | ✅     |
| Operation Object            | ✅     |
| Parameter Object            | ✅     |
| Request Body Object         | ✅     |
| Responses Object            | ✅     |
| Responses / Schema Object   | ✅     |
| Reference Object (`$ref`)   | ✅     |
| OAuth Flows                 | ✅     |
| Security Requirement Object | ✅     |
| Links / Callbacks           | ✅     |
| Webhooks                    | ✅     |
