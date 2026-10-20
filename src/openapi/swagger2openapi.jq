# @file src/openapi/swagger2openapi.jq
# @description Normalizes a Swagger 2.0 specification into an OpenAPI 3.2.0 AST representation.

# rewrite_refs_to_oas3 recursively rewrites Swagger 2.0 $ref pointers (#/definitions/, #/parameters/, #/responses/) to OpenAPI 3.x #/components/...
# @param none
# @return The transformed JSON value with updated $ref strings.
def rewrite_refs_to_oas3:
  walk(
    if type == "object" and (."$ref" | type) == "string" then
      ."$ref" |= (
        sub("^#/definitions/"; "#/components/schemas/") |
        sub("^#/parameters/"; "#/components/parameters/") |
        sub("^#/responses/"; "#/components/responses/")
      )
    else . end
  );

# normalize_swagger_param converts a Swagger 2.0 non-body Parameter Object into an OpenAPI 3.x Parameter Object.
# @param none
# @return The normalized OpenAPI 3.x Parameter Object.
def normalize_swagger_param:
  if .schema or ."$ref" then .
  elif .type then
    .schema = (
      {
        type: .type,
        format: .format,
        items: .items,
        enum: .enum,
        default: .default,
        minimum: .minimum,
        maximum: .maximum
      } | with_entries(select(.value != null))
    ) | del(.type, .format, .items, .enum, .default, .minimum, .maximum, .collectionFormat)
  else . end;

# normalize_swagger_operation converts a Swagger 2.0 Operation Object (body/formData parameters and response schemas) into OpenAPI 3.x.
# @param $global_consumes - Root-level consumes array fallback.
# @param $global_produces - Root-level produces array fallback.
# @return The normalized OpenAPI 3.x Operation Object.
def normalize_swagger_operation($global_consumes; $global_produces):
  ((.consumes // $global_consumes // ["application/json"])[0] // "application/json") as $req_mime |
  ((.produces // $global_produces // ["application/json"])[0] // "application/json") as $res_mime |
  if (.parameters | type) == "array" then
    ([.parameters[] | select(.in == "body")]) as $body_params |
    ([.parameters[] | select(.in == "formData")]) as $form_params |
    ([.parameters[] | select(.in != "body" and .in != "formData") | normalize_swagger_param]) as $other_params |
    .parameters = $other_params |
    (if ($body_params | length) > 0 and (.requestBody == null) then
      .requestBody = {
        required: ($body_params[0].required // false),
        content: {
          ($req_mime): {
            schema: ($body_params[0].schema // {"type": "object"})
          }
        }
      }
    elif ($form_params | length) > 0 and (.requestBody == null) then
      .requestBody = {
        content: {
          (if $req_mime == "multipart/form-data" then "multipart/form-data" else "application/x-www-form-urlencoded" end): {
            schema: {
              type: "object",
              properties: (reduce $form_params[] as $fp ({}; .[$fp.name] = ({type: ($fp.type // "string"), format: $fp.format} | with_entries(select(.value != null)))))
            }
          }
        }
      }
    else . end) |
    (if (.parameters | length) == 0 then del(.parameters) else . end)
  else . end |
  if (.responses | type) == "object" then
    .responses |= with_entries(
      if (.value | type) == "object" and .value.schema != null and .value.content == null then
        .value.content = {
          ($res_mime): {
            schema: .value.schema
          }
        } | del(.value.schema)
      else . end
    )
  else . end |
  del(.consumes, .produces);

if .swagger == "2.0" then
  (.consumes // ["application/json"]) as $g_consumes |
  (.produces // ["application/json"]) as $g_produces |
  .openapi = "3.2.0" |
  .servers = [
    {
      "url": (
        (if .schemes and (.schemes | length > 0) then .schemes[0] else "https" end) + "://" +
        (.host // "localhost") +
        (.basePath // "")
      )
    }
  ] |
  (if (.paths | type) == "object" then
    .paths |= with_entries(
      if (.value | type) == "object" then
        .value |= with_entries(
          if (.key | IN("get", "put", "post", "delete", "options", "head", "patch", "trace")) and (.value | type) == "object" then
            .value |= normalize_swagger_operation($g_consumes; $g_produces)
          elif .key == "parameters" and (.value | type) == "array" then
            .value |= map(normalize_swagger_param)
          else . end
        )
      else . end
    )
  else . end) |
  (if .definitions then .components.schemas = .definitions | del(.definitions) else . end) |
  (if .securityDefinitions then .components.securitySchemes = .securityDefinitions | del(.securityDefinitions) else . end) |
  (if .parameters then .components.parameters = (.parameters | with_entries(.value |= normalize_swagger_param)) | del(.parameters) else . end) |
  (if .responses then .components.responses = .responses | del(.responses) else . end) |
  del(.swagger, .host, .basePath, .schemes, .consumes, .produces) |
  rewrite_refs_to_oas3
else
  .
end
