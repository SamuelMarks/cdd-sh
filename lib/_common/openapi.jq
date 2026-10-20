# @file lib/_common/openapi.jq
# @description Shared JQ helper functions for OpenAPI AST traversal, operationId normalization, and MCP tool schema extraction.

# to_snake_case converts a camelCase or PascalCase string to snake_case.
# @param none
# @return The snake_case string.
def to_snake_case:
  split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("") | sub("^_"; "");

# get_op_id($method; $path) derives a normalized snake_case operation identifier from .operationId or HTTP method and path.
# @param $method - The HTTP method string.
# @param $path - The URL path template string.
# @return The snake_case operation identifier.
def get_op_id($method; $path):
  if .operationId then
    (.operationId | to_snake_case)
  else
    "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))"
  end;

# get_raw_op_id($method; $path) derives an operation identifier preserving .operationId casing if present.
# @param $method - The HTTP method string.
# @param $path - The URL path template string.
# @return The operation identifier string.
def get_raw_op_id($method; $path):
  if .operationId then
    .operationId
  else
    "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))"
  end;

# get_docs_op_id($method; $path) derives an operation identifier for documentation snippets.
# @param $method - The HTTP method string.
# @param $path - The URL path template string.
# @return The documentation operation identifier string.
def get_docs_op_id($method; $path):
  if .operationId then
    .operationId
  else
    "\($method)_\($path | gsub("/"; "_") | gsub("[{}]"; "") | sub("^_"; ""))"
  end;

# emit_mcp_tools builds the JSON array of MCP tool definitions from the OpenAPI paths object.
# @param none
# @return JSON array of MCP Tool Objects.
def emit_mcp_tools:
  if .paths then
    [
      .paths | to_entries[] | .key as $path | .value | to_entries[] |
      select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") |
      .key as $method | .value |
      get_op_id($method; $path) as $opId |
      {
        name: $opId,
        description: (.summary // "Call \($method) \($path)"),
        inputSchema: {
          type: "object",
          properties: (
            ((.parameters // []) | map({(.name): {type: (.schema.type // "string")}})) | add // {}
          ),
          required: (
            ((.parameters // []) | map(select(.required == true) | .name)) // []
          )
        }
      }
    ]
  else
    []
  end;
