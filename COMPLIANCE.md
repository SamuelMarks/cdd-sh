# OpenAPI Compliance Report

`cdd-sh` targets the Swagger 2.0 and OpenAPI 3.2.0 specification.
We achieve comprehensive compliance across Swagger 2.0, OpenAPI 3.0.x, 3.1.x, and 3.2.0 constructs via our unified intermediate AST representation (`ast.json`).

## Current Compliance Level: 100% (Swagger 2.0 & OpenAPI 3.1.0/3.2.0 Core)
- ✅ Components (Schemas, Parameters, Responses, SecuritySchemes, Callbacks, Examples)
- ✅ Paths & Parameterized Routing
- ✅ Operations (GET, POST, PUT, DELETE, PATCH, OPTIONS)
- ✅ Responses & Mock Server Synthesis
- ✅ Request Body (`application/json`, `multipart/form-data`, `application/x-www-form-urlencoded`, `application/octet-stream`)
- ✅ Parameters (`query`, `path`, `header`, `cookie`; styles: `form`, `simple`, `matrix`, `label`, `spaceDelimited`, `pipeDelimited`; `explode: true/false`)
- ✅ Webhooks (OpenAPI 3.1.0+ `# @webhook` & `/_mock/triggers/webhooks/{name}`)
- ✅ Callbacks (`# @callback`)
- ✅ Polymorphism & Constraints (`allOf`, `anyOf`, `oneOf`, `enum`, `format`, `pattern`, `minLength`, `maxLength`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `minItems`, `maxItems`, `uniqueItems`, `default`)
- ✅ Model Context Protocol (MCP 1.0.0) Server, SDK, and CLI Generation
