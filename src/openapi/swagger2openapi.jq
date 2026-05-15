if .swagger == "2.0" then
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
  (if .definitions then .components.schemas = .definitions | del(.definitions) else . end) |
  (if .securityDefinitions then .components.securitySchemes = .securityDefinitions | del(.securityDefinitions) else . end) |
  (if .parameters then .components.parameters = .parameters | del(.parameters) else . end) |
  (if .responses then .components.responses = .responses | del(.responses) else . end) |
  del(.swagger, .host, .basePath, .schemes)
else
  .
end
