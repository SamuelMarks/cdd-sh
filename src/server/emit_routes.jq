if .paths then
  "cat <<'EOF' > \"${out_dir}/router.sh\"\n" +
  "router_dispatch() {\n" +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  (if .operationId then (.operationId | split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("")) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
  "  if [ \"$path\" = \"\($path)\" ] && [ \"$method\" = \"\($method | ascii_upcase)\" ]; then\n" +
  "    found=\"true\"\n" +
  "    set +e\n" +
  "    res=$(dao_${ACTIVE_DAO}_\($opId))\n" +
  "    exit_code=$?\n" +
  "    set -e\n" +
  "    if [ \"$exit_code\" -ne 0 ]; then\n" +
  "      response_json=\"{\\\"error\\\": \\\"Not Implemented\\\"}\"\n" +
  "    else\n" +
  "      response_json=\"$res\"\n" +
  "    fi\n" +
  "    return 0\n" +
  "  fi\n" ] | join("")) +
  "  return 1\n" +
  "}\n" +
  "EOF\n" +
  "chmod +x \"${out_dir}/router.sh\"\n"
else
  empty
end