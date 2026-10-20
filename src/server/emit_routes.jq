# @file src/server/emit_routes.jq
# @description Generates the HTTP route dispatcher (router.sh) from the OpenAPI AST using ###FILE### delimiters.
include "openapi";

if .paths then
  "###FILE###router.sh\n" +
  "# @file router.sh\n" +
  "# @description Generated HTTP route dispatcher.\n" +
  "# router_dispatch matches the incoming HTTP path and method and invokes the active DAO handler.\n" +
  "# @param $path: The HTTP request path\n" +
  "# @param $method: The HTTP request method\n" +
  "router_dispatch() {\n" +
  "  matched_req_model=\"\"\n" +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  get_op_id($method; $path) as $opId |
  ($path | gsub("\\{[^}]+\\}"; "*")) as $pathPattern |
  (
    if .requestBody and .requestBody.content then
      (.requestBody.content["application/json"].schema."$ref" // .requestBody.content[(.requestBody.content | keys[0])].schema."$ref" // "")
      | if . != "" then (split("/") | last) else "" end
    else "" end
  ) as $reqModel |
  "  case \"$method:$path\" in\n" +
  "    \"\($method | ascii_upcase):\($path)\"|\($method | ascii_upcase):\($pathPattern))\n" +
  "      found=\"true\"\n" +
  "      matched_req_model=\"\($reqModel)\"\n" +
  "      set +e\n" +
  "      res=$(dao_${ACTIVE_DAO}_\($opId))\n" +
  "      exit_code=$?\n" +
  "      set -e\n" +
  "      if [ \"$exit_code\" -ne 0 ]; then\n" +
  "        response_json=\"{\\\"error\\\": \\\"Not Implemented\\\"}\"\n" +
  "      else\n" +
  "        response_json=\"$res\"\n" +
  "      fi\n" +
  "      return 0\n" +
  "      ;;\n" +
  "  esac\n" ] | join("")) +
  "  return 1\n" +
  "}\n"
else
  empty
end
