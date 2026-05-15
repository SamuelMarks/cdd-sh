if .swagger == "2.0" then
  .
else
  # Convert OpenAPI 3 back to Swagger 2 if requested
  .swagger = "2.0" |
  .host = (if .servers and (.servers | length > 0) then (.servers[0].url | split("://")[1] | split("/")[0]) else "localhost" end) |
  .basePath = (if .servers and (.servers | length > 0) then ( "/" + (.servers[0].url | split("://")[1] | split("/")[1:] | join("/")) ) | sub("/$";"") else "" end) |
  .schemes = (if .servers and (.servers | length > 0) then [(.servers[0].url | split("://")[0])] else ["https"] end) |
  (if .components.schemas then .definitions = .components.schemas else . end) |
  (if .components.securitySchemes then .securityDefinitions = .components.securitySchemes else . end) |
  (if .components.parameters then .parameters = .components.parameters else . end) |
  (if .components.responses then .responses = .components.responses else . end) |
  del(.openapi, .servers, .components)
end
