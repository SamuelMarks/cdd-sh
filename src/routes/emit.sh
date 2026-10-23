#!/bin/sh
# @file src/routes/emit.sh
# @description Emits client HTTP route functions, webhook stubs, and OAuth2 helpers from the OpenAPI AST.
# shellcheck disable=SC2016,SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# handle_emit_routes generates network routes from the AST.
# @param $1: file_path - The destination routes script path (default: routes.sh).
handle_emit_routes() {
	file_path="${1:-routes.sh}"
	ast="${CDD_AST_PATH:-${LIBSCRIPT_ROOT_DIR}/ast.json}"
	if [ ! -f "${ast}" ]; then return 1; fi

	{
		printf "#!/bin/sh\n# @file %s\n# @description Auto-generated API Client\nset -eu\n\n" "${file_path##*/}"
		BASE_URL=$(jq -r '.servers[0] | if .variables then reduce (.variables | to_entries[]) as $var (.url; gsub("\\{" + $var.key + "\\}"; $var.value.default)) else .url end // ""' "${ast}")
		printf "BASE_URL=\"\${BASE_URL:-%s}\"\nOAUTH_TOKEN=\"\${OAUTH_TOKEN:-}\"\nAPI_KEY=\"\${API_KEY:-}\"\n\n" "${BASE_URL}"
		printf "# _urlencode percent-encodes a string for URLs.\n# @param \$1: value - Raw string to URL-encode.\n_urlencode() {\n  printf '%%s' \"\$1\" | jq -s -R -r '@uri'\n}\n\n"
		printf "# _quote_sh safely escapes a string for shell evaluation.\n# @param \$1: value - Raw string to escape.\n_quote_sh() {\n  printf '%%s' \"\$1\" | jq -s -R -r '@sh'\n}\n\n"

		printf "# _serialize_matrix formats a parameter using OpenAPI matrix style.\n# @param \$1: name - Parameter name.\n# @param \$2: value - Parameter value.\n# @param \$3: explode - Whether to explode comma-separated items.\n_serialize_matrix() {\n  if [ \"\$3\" = \"true\" ]; then\n    printf \"%%s\" \"\$2\" | awk -F, -v n=\"\$1\" '{for(i=1;i<=NF;i++) printf \";\"n\"=\"\$i}'\n  else\n    printf \";%%s=%%s\" \"\$1\" \"\$2\"\n  fi\n}\n\n"

		printf "# _serialize_label formats a parameter using OpenAPI label style.\n# @param \$1: name - Parameter name.\n# @param \$2: value - Parameter value.\n# @param \$3: explode - Whether to explode comma-separated items.\n_serialize_label() {\n  if [ \"\$3\" = \"true\" ]; then\n    printf \"%%s\" \"\$2\" | awk -F, '{for(i=1;i<=NF;i++) printf \".\"\$i}'\n  else\n    printf \".%%s\" \"\$2\"\n  fi\n}\n\n"

		jq -r '
      if .webhooks then
        .webhooks | to_entries[] | .key as $name | .value | to_entries[] | .key as $method | .value |
        "# @webhook \($name)\n" +
        "# @method \($method | ascii_upcase)\n" +
        (if .summary then "# @description \(.summary)\n" else "# @description Webhook handler for \($name)\n" end) +
        "# @param none\n" +
        "handle_webhook_\($name | gsub("-";"_"))() {\n" +
        "  echo \"[WEBHOOK] \($name)\"\n" +
        "}\n\n"
      else empty end
    ' "${ast}"

		jq -r '
      if .components and .components.securitySchemes then
        .components.securitySchemes | to_entries[] |
        if .value.type == "oauth2" and .value.flows then
          (if .value.flows.clientCredentials then
            .value.flows.clientCredentials.tokenUrl as $tokenUrl |
            "# @function auth_login_\(.key)\n" +
            "# @description Fetch OAuth2 Token using clientCredentials\n" +
            "# @param $1: client_id\n" +
            "# @param $2: client_secret\n" +
            "auth_login_\(.key)() {\n" +
            "  client_id=\"${1:-}\"\n" +
            "  client_secret=\"${2:-}\"\n" +
            "  curl -s -X POST \"\($tokenUrl)\" -d \"grant_type=client_credentials&client_id=${client_id}&client_secret=${client_secret}\" | jq -r .access_token\n" +
            "}\n\n"
          else "" end) +
          (if .value.flows.password then
            .value.flows.password.tokenUrl as $tokenUrl |
            "# @function auth_password_\(.key)\n" +
            "# @description Fetch OAuth2 Token using Resource Owner Password flow\n" +
            "# @param $1: username\n" +
            "# @param $2: password\n" +
            "auth_password_\(.key)() {\n" +
            "  username=\"${1:-}\"\n" +
            "  password=\"${2:-}\"\n" +
            "  curl -s -X POST \"\($tokenUrl)\" -d \"grant_type=password&username=${username}&password=${password}\" | jq -r .access_token\n" +
            "}\n\n"
          else "" end) +
          (if .value.flows.deviceAuthorization then
            (.value.flows.deviceAuthorization.deviceAuthorizationUrl // .value.flows.deviceAuthorization.tokenUrl) as $devUrl |
            "# @function auth_device_\(.key)\n" +
            "# @description Initiate OAuth2 Device Authorization flow\n" +
            "# @param $1: client_id\n" +
            "auth_device_\(.key)() {\n" +
            "  client_id=\"${1:-}\"\n" +
            "  curl -s -X POST \"\($devUrl)\" -d \"client_id=${client_id}\" | jq -r .device_code\n" +
            "}\n\n"
          else "" end)
        else empty end
      else empty end
    ' "${ast}"

		jq -r -L "${LIBSCRIPT_ROOT_DIR}/lib/_common" '
      include "openapi";
      . as $root |
      if .paths then
        .paths | to_entries[] | .key as $path |
        (if .value."$ref" and $root.components and $root.components.pathItems then ($root.components.pathItems[.value."$ref" | sub("^#/components/pathItems/"; "")] // .value) else .value end) |
        (.parameters // []) as $pathParams |
        ((to_entries | map(select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers" and .key != "$ref" and .key != "additionalOperations"))) +
         (if .additionalOperations then (.additionalOperations | to_entries) else [] end))[] |
        .key as $method | .value |
        (if .requestBody and .requestBody."$ref" and $root.components and $root.components.requestBodies then
          .requestBody = ($root.components.requestBodies[.requestBody."$ref" | sub("^#/components/requestBodies/"; "")] // .requestBody)
        else . end) |
        (if .summary == null then "Call \($method | ascii_upcase) \($path)" else .summary end) as $desc |
        ((.parameters // []) + $pathParams | map(if ."$ref" then ($root.components.parameters[."$ref" | sub("^#/components/parameters/"; "")] // .) else . end)) as $params |
        (.security // $root.security // []) as $secReqs |
        get_raw_op_id($method; $path) as $opId |
        
        ([
          range(0; $params | length) as $i |
          (if $params[$i].description == null then "" else $params[$i].description end) as $pdesc |
          "# @param $\($i + 1): \($params[$i].name) (\($params[$i].in)) - \($pdesc)"
        ] | join("\n")) as $paramDocs |
        
        (if .requestBody then
          (if .requestBody.content and .requestBody.content["application/json"] then
            "# @param $\(($params | length) + 1): requestBody (application/json)"
          elif .requestBody.content and .requestBody.content["multipart/form-data"] then
            "# @param $\(($params | length) + 1): requestBody (multipart/form-data)"
          elif .requestBody.content and .requestBody.content["application/octet-stream"] then
            "# @param $\(($params | length) + 1): requestBody (application/octet-stream)"
          elif .requestBody.content and .requestBody.content["application/x-www-form-urlencoded"] then
            "# @param $\(($params | length) + 1): requestBody (application/x-www-form-urlencoded)"
          else
            "# @param $\(($params | length) + 1): requestBody (application/json)"
          end)
        else "" end) as $reqBodyDoc |
        
        ([
          range(0; $params | length) as $i |
          ($params[$i].name | gsub("-"; "_")) as $varname |
          "  \($varname)=\"${\($i + 1):-}\""
        ] | join("\n")) as $paramAssigns |
        
        (if .requestBody then "  requestBody=\"${\(($params | length) + 1):-}\"" else "" end) as $reqBodyAssign |
        
        ([
          $params[] | select(.in == "path") |
          (.name | gsub("-"; "_")) as $varname |
          (.style // "simple") as $style |
          (.explode // false) as $explode |
          
          if $style == "matrix" then
            "  \($varname)=\"$(_serialize_matrix \"\(.name)\" \"${\($varname)}\" \"\($explode)\")\""
          elif $style == "label" then
            "  \($varname)=\"$(_serialize_label \"\(.name)\" \"${\($varname)}\" \"\($explode)\")\""
          else
            "  \($varname)=\"$(_urlencode \"${\($varname)}\")\""
          end
        ] | join("\n")) as $pathEncodes |
        
        ($path | gsub("\\{(?<p>[a-zA-Z0-9_-]+)\\}"; "${\(.p | gsub("-"; "_"))}")) as $shellPath |
        
        ([
          $params[] | select(.in == "query") |
          (.name | gsub("-"; "_")) as $varname |
          (.style // "form") as $style |
          (.explode // true) as $explode |
          (.allowReserved // false) as $allowReserved |
          (.allowEmptyValue // false) as $allowEmpty |
          (if $allowEmpty == true then "  if [ -n \"${\($varname)+x}\" ]; then\n" else "  if [ -n \"${\($varname)}\" ]; then\n" end) +
          (
            if $allowReserved == true then
              "    qs=\"${qs}&\(.name)=${\($varname)}\""
            elif $style == "form" and $explode == true then
              "    qs=\"${qs}&\(.name)=$(_urlencode \"${\($varname)}\")\""
            elif $style == "form" and $explode == false then
              "    qs=\"${qs}&\(.name)=$(printf \"%s\" \"${\($varname)}\" | jq -s -R -r '\''split(\",\") | map(@uri) | join(\",\")'\'')\""
            elif $style == "spaceDelimited" then
              "    qs=\"${qs}&\(.name)=$(printf \"%s\" \"${\($varname)}\" | jq -s -R -r '\''gsub(\" \"; \"%20\")'\'')\""
            elif $style == "pipeDelimited" then
              "    qs=\"${qs}&\(.name)=$(printf \"%s\" \"${\($varname)}\" | jq -s -R -r '\''gsub(\"\\\\|\"; \"%7C\")'\'')\""
            else
              "    qs=\"${qs}&\(.name)=$(_urlencode \"${\($varname)}\")\""
            end
          ) + "\n  fi"
        ] | join("\n")) as $queryBuild |
        
        ([
          $params[] | select(.in == "header") |
          (.name | gsub("-"; "_")) as $varname |
          "  [ -n \"${\($varname)}\" ] && set -- \"$@\" -H \"\(.name): ${\($varname)}\""
        ] | join("\n")) as $headerBuild |
        
        ([
          $params[] | select(.in == "cookie") |
          (.name | gsub("-"; "_")) as $varname |
          "  [ -n \"${\($varname)}\" ] && set -- \"$@\" -b \"\(.name)=${\($varname)}\""
        ] | join("\n")) as $cookieBuild |
        
        (if ($secReqs | length > 0) and $root.components and $root.components.securitySchemes then
          ($secReqs | map(keys) | flatten | unique) as $schemes |
          ([
            $schemes[] | $root.components.securitySchemes[.] | select(. != null) |
            if .type == "oauth2" or (.type == "http" and (.scheme | ascii_downcase) == "bearer") then
              "  if [ -n \"${OAUTH_TOKEN:-}\" ]; then\n    set -- \"$@\" -H \"Authorization: Bearer ${OAUTH_TOKEN}\"\n  fi"
            elif .type == "http" and (.scheme | ascii_downcase) == "basic" then
              "  if [ -n \"${BASIC_AUTH:-}\" ]; then\n    set -- \"$@\" -u \"${BASIC_AUTH}\"\n  fi"
            elif .type == "apiKey" and .in == "header" then
              "  if [ -n \"${API_KEY:-}\" ]; then\n    set -- \"$@\" -H \"\(.name): ${API_KEY}\"\n  fi"
            elif .type == "apiKey" and .in == "query" then
              "  if [ -n \"${API_KEY:-}\" ]; then\n    qs=\"${qs}&\(.name)=$(_urlencode \"${API_KEY}\")\"\n  fi"
            else empty end
          ] | unique | join("\n"))
        else "" end) as $securityBuild |
        
        (if .requestBody then 
          (if .requestBody.content and .requestBody.content["application/json"] then
            "  [ -n \"${requestBody}\" ] && set -- \"$@\" -H \"Content-Type: application/json\" -d \"${requestBody}\""
          elif .requestBody.content and .requestBody.content["application/x-www-form-urlencoded"] then
            "  if [ -n \"${requestBody}\" ]; then\n    set -- \"$@\" -H \"Content-Type: application/x-www-form-urlencoded\" -d \"${requestBody}\"\n  fi"
          elif .requestBody.content and .requestBody.content["multipart/form-data"] then
            "  if [ -n \"${requestBody}\" ]; then\n    set -- \"$@\" -F \"file=@${requestBody}\"\n  fi"
          elif .requestBody.content and .requestBody.content["application/octet-stream"] then
            "  if [ -n \"${requestBody}\" ]; then\n    set -- \"$@\" -H \"Content-Type: application/octet-stream\" --data-binary \"@${requestBody}\"\n  fi"
          else
            "  [ -n \"${requestBody}\" ] && set -- \"$@\" -H \"Content-Type: application/json\" -d \"${requestBody}\""
          end)
        else "" end) as $bodyBuild |
        
        "# @function \($opId)\n# @description \($desc)" +
        (if .deprecated == true then "\n# @deprecated true" else "" end) +
        (if $paramDocs != "" then "\n" + $paramDocs else "" end) +
        (if $reqBodyDoc != "" then "\n" + $reqBodyDoc else "" end) +
        "\n\($opId)() {\n" +
        (if $paramAssigns != "" then $paramAssigns + "\n" else "" end) +
        (if $reqBodyAssign != "" then $reqBodyAssign + "\n" else "" end) +
        (if $pathEncodes != "" then $pathEncodes + "\n" else "" end) +
        "  url=\"${BASE_URL}\($shellPath)\"\n" +
        "  qs=\"\"\n" +
        "  set -- -s -X \($method | ascii_upcase)\n" +
        (if $securityBuild != "" then $securityBuild + "\n" else "" end) +
        (if $queryBuild != "" then $queryBuild + "\n" else "" end) +
        "  [ -n \"${qs}\" ] && url=\"${url}?${qs#&}\"\n" +
        (if $headerBuild != "" then $headerBuild + "\n" else "" end) +
        (if $cookieBuild != "" then $cookieBuild + "\n" else "" end) +
        (if $bodyBuild != "" then $bodyBuild + "\n" else "" end) +
        "  curl \"$@\" \"${url}\"\n}\n\n"
      else empty end
    ' "${ast}"

	} >"${file_path}.tmp"

	merge_or_move_emitted_file "${file_path}" "0"
}
