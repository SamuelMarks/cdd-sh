# @file src/openapi/openapi2swagger.jq
# @description Converts an OpenAPI 3.x specification AST back into a Swagger 2.0 JSON specification.

# rewrite_refs_to_swagger2 recursively rewrites OpenAPI 3.x #/components/... $ref pointers back to Swagger 2.0 #/definitions/, #/parameters/, #/responses/.
# @param none
# @return The transformed JSON value with Swagger 2.0 $ref strings.
def rewrite_refs_to_swagger2:
  walk(
    if type == "object" and (."$ref" | type) == "string" then
      ."$ref" |= (
        sub("^#/components/schemas/"; "#/definitions/") |
        sub("^#/components/parameters/"; "#/parameters/") |
        sub("^#/components/responses/"; "#/responses/")
      )
    else . end
  );

# denormalize_oas_operation converts an OpenAPI 3.x Operation Object (requestBody and response content) back into Swagger 2.0 format.
# @param none
# @return The Swagger 2.0 Operation Object.
def denormalize_oas_operation:
  (if (.parameters | type) == "array" then
    .parameters |= map(
      if (.schema | type) == "object" and .in != "body" and (."$ref" == null) and (.schema."$ref" == null) then
        . + (.schema | with_entries(select(.key | IN("type", "format", "items", "enum", "default", "minimum", "maximum")))) | del(.schema)
      else . end
    )
  else . end) |
  (if (.requestBody | type) == "object" and (.requestBody.content | type) == "object" then
    (.requestBody.content["application/json"].schema // .requestBody.content[(.requestBody.content | keys[0])].schema // null) as $bschema |
    if $bschema != null then
      .parameters = ((.parameters // []) + [{
        name: "body",
        in: "body",
        required: (.requestBody.required // false),
        schema: $bschema
      }])
    else . end |
    del(.requestBody)
  else . end) |
  (if (.responses | type) == "object" then
    .responses |= with_entries(
      if (.value | type) == "object" and (.value.content | type) == "object" then
        (.value.content["application/json"].schema // .value.content[(.value.content | keys[0])].schema // null) as $rschema |
        (if $rschema != null then .value.schema = $rschema else . end) |
        del(.value.content)
      else . end
    )
  else . end);

if .swagger == "2.0" then
  .
else
  ((if .servers and (.servers | length > 0) then (.servers[0].url // "") else "" end)) as $srv_url |
  .swagger = "2.0" |
  .host = (
    if ($srv_url | contains("://")) then
      ($srv_url | split("://")[1] | split("/")[0])
    else
      "localhost"
    end
  ) |
  .basePath = (
    if ($srv_url | contains("://")) then
      ( "/" + ($srv_url | split("://")[1] | split("/")[1:] | join("/")) ) | sub("/$";"")
    elif ($srv_url | startswith("/")) then
      ($srv_url | sub("/$";""))
    else
      ""
    end
  ) |
  .schemes = (
    if ($srv_url | contains("://")) then
      [($srv_url | split("://")[0])]
    else
      ["https"]
    end
  ) |
  (if (.paths | type) == "object" then
    .paths |= with_entries(
      if (.value | type) == "object" then
        .value |= with_entries(
          if (.key | IN("get", "put", "post", "delete", "options", "head", "patch", "trace")) and (.value | type) == "object" then
            .value |= denormalize_oas_operation
          else . end
        )
      else . end
    )
  else . end) |
  (if .components.schemas then .definitions = .components.schemas else . end) |
  (if .components.securitySchemes then .securityDefinitions = .components.securitySchemes else . end) |
  (if .components.parameters then .parameters = .components.parameters else . end) |
  (if .components.responses then .responses = .components.responses else . end) |
  del(.openapi, .servers, .components) |
  rewrite_refs_to_swagger2
end
