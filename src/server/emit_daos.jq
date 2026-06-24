if .paths then
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  (if .operationId then (.operationId | split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("")) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
  "cat <<'EOF' > \"${out_dir}/dao_\($opId).sh\"\n" +
  "# dao_stub_\($opId) is the stub implementation for \($method | ascii_upcase) \($path).\n" +
  "# Returns a NotImplemented error.\n" +
  "dao_stub_\($opId)() {\n" +
  "  echo '{\"error\": \"Not Implemented\"}'\n" +
  "  return 1\n" +
  "}\n" +
  "\n" +
  "# dao_concrete_\($opId) is the concrete DB implementation for \($method | ascii_upcase) \($path).\n" +
  "# Interacts with DATABASE_URL.\n" +
  "dao_concrete_\($opId)() {\n" +
  "  echo '{}'\n" +
  "  return 0\n" +
  "}\n" +
  "EOF\n" +
  "chmod +x \"${out_dir}/dao_\($opId).sh\"\n" ] | join(""))
else
  empty
end