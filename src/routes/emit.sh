#!/bin/sh
set -feu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054,SC3043,SC2129
if [ "${SCRIPT_NAME-}" ]; then
  this_file="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
  this_file="${BASH_SOURCE[0]}"
  set -o pipefail
else
  this_file="${0}"
fi
case "${STACK+x}" in
  *':'"${this_file}"':'*) if (return 0 2>/dev/null); then return; else exit 0; fi ;;
esac
export STACK="${STACK:-}${this_file}"':'
DIR=$(CDPATH='' cd -- "$(dirname -- "${this_file}")" && pwd)
LIBSCRIPT_ROOT_DIR="${LIBSCRIPT_ROOT_DIR:-$(d="${DIR}"; while [ ! -f "${d}"'/ROOT' ]; do d="$(dirname -- "${d}")"; done; printf '%s' "${d}")}"

handle_emit_routes() {
  file_path="${1:-routes.sh}"
  ast="${LIBSCRIPT_ROOT_DIR}/ast.json"
  if [ ! -f "${ast}" ]; then
    printf "Error: AST file not found at %s\n" "${ast}" >&2
    return 1
  fi
  {
    printf "#!/bin/sh\n# Auto-generated API Client\nset -eu\n\n"
    BASE_URL=$(jq -r ".servers[0] | if .variables then reduce (.variables | to_entries[]) as \$var (.url; gsub(\"\\\\{\" + \$var.key + \"\\\\}\"; \$var.value.default)) else .url end // \"\"" "${ast}")
    printf "BASE_URL=\"\${BASE_URL:-%s}\"\nOAUTH_TOKEN=\"\${OAUTH_TOKEN:-}\"\nAPI_KEY=\"\${API_KEY:-}\"\n\n" "${BASE_URL}"
    printf "_urlencode() {\n  printf '%%s' \"\$1\" | jq -s -R -r '@uri'\n}\n\n"
    
    printf "_serialize_matrix() {\n"
    printf "  if [ \"\$3\" = \"true\" ]; then\n"
    printf "    printf \"%%s\" \"\$2\" | awk -F, -v n=\"\$1\" '{for(i=1;i<=NF;i++) printf \";\"n\"=\"\$i}'\n"
    printf "  else\n"
    printf "    printf \";%%s=%%s\" \"\$1\" \"\$2\"\n"
    printf "  fi\n}\n\n"

    printf "_serialize_label() {\n"
    printf "  if [ \"\$3\" = \"true\" ]; then\n"
    printf "    printf \"%%s\" \"\$2\" | awk -F, '{for(i=1;i<=NF;i++) printf \".\"\$i}'\n"
    printf "  else\n"
    printf "    printf \".%%s\" \"\$2\"\n"
    printf "  fi\n}\n\n"

    jq -r '
      if .webhooks then
        .webhooks | to_entries[] | .key as $name | .value | to_entries[] | .key as $method | .value |
        "# @webhook \($name)\n" +
        "# @method \($method | ascii_upcase)\n" +
        (if .summary then "# @description \(.summary)\n" else "" end) +
        "handle_webhook_\($name | gsub("-";"_"))() {\n" +
        "  echo \"[WEBHOOK] \($name)\"\n" +
        "}\n\n"
      else empty end
    ' "${ast}"

    jq -r '
      if .components and .components.securitySchemes then
        .components.securitySchemes | to_entries[] |
        if .value.type == "oauth2" and .value.flows and .value.flows.clientCredentials then
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
        else empty end
      else empty end
    ' "${ast}"

    jq -r '
      . as $root |
      if .paths then
        .paths | to_entries[] | .key as $path | .value | (.parameters // []) as $pathParams | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
        (if .summary == null then "Call \($method | ascii_upcase) \($path)" else .summary end) as $desc |
        ((.parameters // []) + $pathParams) as $params |
        (.security // $root.security // []) as $secReqs |
        (if .operationId then .operationId else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
        
        ([
          range(0; $params | length) as $i |
          (if $params[$i].description == null then "" else $params[$i].description end) as $pdesc |
          "# @param $\($i + 1): \($params[$i].name) (\($params[$i].in)) - \($pdesc)"
        ] | join("\n")) as $paramDocs |
        
        (if .requestBody then "# @param $\(($params | length) + 1): requestBody" else "" end) as $reqBodyDoc |
        
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
          "  if [ -n \"${\($varname)}\" ]; then\n" +
          (
            if $style == "form" and $explode == true then
              "    qs=\"${qs}&\(.name)=$(_urlencode \"${\($varname)}\")\""
            elif $style == "form" and $explode == false then
              "    qs=\"${qs}&\(.name)=$(_urlencode \"${\($varname)}\")\""
            elif $style == "spaceDelimited" then
              "    qs=\"${qs}&\(.name)=$(printf \"%s\" \"${\($varname)}\" | sed '\''s/ /%20/g'\'')\""
            elif $style == "pipeDelimited" then
              "    qs=\"${qs}&\(.name)=$(printf \"%s\" \"${\($varname)}\" | sed '\''s/|/%7C/g'\'')\""
            else
              "    qs=\"${qs}&\(.name)=$(_urlencode \"${\($varname)}\")\""
            end
          ) + "\n  fi"
        ] | join("\n")) as $queryBuild |
        
        ([
          $params[] | select(.in == "header") |
          (.name | gsub("-"; "_")) as $varname |
          "  [ -n \"${\($varname)}\" ] && curl_args=\"${curl_args} -H \\\"\(.name): ${\($varname)}\\\"\""
        ] | join("\n")) as $headerBuild |
        
        (if ($secReqs | length > 0) and $root.components and $root.components.securitySchemes then
          ($secReqs | map(keys) | flatten | unique) as $schemes |
          ([
            $schemes[] | $root.components.securitySchemes[.] | select(. != null) |
            if .type == "oauth2" or (.type == "http" and (.scheme | ascii_downcase) == "bearer") then
              "  if [ -n \"${OAUTH_TOKEN:-}\" ]; then\n    curl_args=\"${curl_args} -H \\\"Authorization: Bearer ${OAUTH_TOKEN}\\\"\"\n  fi"
            elif .type == "http" and (.scheme | ascii_downcase) == "basic" then
              "  if [ -n \"${BASIC_AUTH:-}\" ]; then\n    curl_args=\"${curl_args} -u \"${BASIC_AUTH}\"\"\n  fi"
            elif .type == "apiKey" and .in == "header" then
              "  if [ -n \"${API_KEY:-}\" ]; then\n    curl_args=\"${curl_args} -H \\\"\(.name): ${API_KEY}\\\"\"\n  fi"
            elif .type == "apiKey" and .in == "query" then
              "  if [ -n \"${API_KEY:-}\" ]; then\n    qs=\"${qs}&\(.name)=$(_urlencode \"${API_KEY}\")\"\n  fi"
            else empty end
          ] | unique | join("\n"))
        else "" end) as $securityBuild |
        
        (if .requestBody then 
          (if .requestBody.content and .requestBody.content["application/x-www-form-urlencoded"] then
            "  if [ -n \"${requestBody}\" ]; then\n    curl_args=\"${curl_args} -H \\\"Content-Type: application/x-www-form-urlencoded\\\" -d \\\"${requestBody}\\\"\"\n  fi"
          elif .requestBody.content and .requestBody.content["multipart/form-data"] then
            "  if [ -n \"${requestBody}\" ]; then\n    curl_args=\"${curl_args} -H \\\"Content-Type: multipart/form-data\\\" -d \\\"${requestBody}\\\"\"\n  fi"
          else
            "  [ -n \"${requestBody}\" ] && curl_args=\"${curl_args} -H \\\"Content-Type: application/json\\\" -d \\\"${requestBody}\\\"\""
          end)
        else "" end) as $bodyBuild |
        
        "# @function \($opId)\n# @description \($desc)" +
        (if $paramDocs != "" then "\n" + $paramDocs else "" end) +
        (if $reqBodyDoc != "" then "\n" + $reqBodyDoc else "" end) +
        "\n\($opId)() {\n" +
        (if $paramAssigns != "" then $paramAssigns + "\n" else "" end) +
        (if $reqBodyAssign != "" then $reqBodyAssign + "\n" else "" end) +
        (if $pathEncodes != "" then $pathEncodes + "\n" else "" end) +
        "  url=\"${BASE_URL}\($shellPath)\"\n" +
        "  qs=\"\"\n" +
        "  curl_args=\"\"\n" +
        (if $securityBuild != "" then $securityBuild + "\n" else "" end) +
        (if $queryBuild != "" then $queryBuild + "\n" else "" end) +
        "  [ -n \"${qs}\" ] && url=\"${url}?${qs#&}\"\n" +
        (if $headerBuild != "" then $headerBuild + "\n" else "" end) +
        (if $bodyBuild != "" then $bodyBuild + "\n" else "" end) +
        "  # shellcheck disable=SC2086\n" +
        "  curl -s -X \($method | ascii_upcase) ${curl_args} \"${url}\"\n}\n\n"
      else empty end
    ' "${ast}"
  } > "${file_path}"
}
