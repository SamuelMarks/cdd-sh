if .paths then
  "cat <<'EOF' > \"${out_dir}/run_all.sh\"\n" +
  "#!/bin/sh\n" +
  "set -e\n" +
  "DIR=\"$(dirname \"$0\")\"\n" +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  (if .operationId then (.operationId | split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("")) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
  "echo \"Testing \($opId)...\"\n" +
  "sh \"$DIR/test_\($opId).sh\"\n" ] | join("")) +
  "EOF\n" +
  "chmod +x \"${out_dir}/run_all.sh\"\n" +
  ([ .paths | to_entries[] | .key as $path | .value | to_entries[] | select(.key != "parameters" and .key != "summary" and .key != "description" and .key != "servers") | .key as $method | .value |
  (if .operationId then (.operationId | split("") | map(if test("[A-Z]") then "_" + ascii_downcase else . end) | join("")) else "\($method | ascii_upcase)_\($path | gsub("/"; "_") | gsub("[{}]"; ""))" end) as $opId |
  "cat <<'EOF' > \"${out_dir}/test_\($opId).sh\"\n" +
  "#!/bin/sh\n" +
  "set -e\n" +
  "# Simple test script\n" +
  "EOF\n" +
  "chmod +x \"${out_dir}/test_\($opId).sh\"\n" ] | join(""))
else
  empty
end