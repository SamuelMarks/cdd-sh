#!/bin/sh
set -e
echo "Testing --input-dir..."
mkdir -p tests/tmp_input_dir
echo '{"openapi":"3.2.0","info":{"title":"A"},"paths":{"/a":{"get":{"operationId":"getA"}}}}' >tests/tmp_input_dir/1.json
echo '{"openapi":"3.2.0","info":{"title":"B"},"paths":{"/b":{"get":{"operationId":"getB"}}}}' >tests/tmp_input_dir/2.json
./bin/cdd-sh from_openapi to_sdk --input-dir tests/tmp_input_dir -o tests/tmp_out_dir
if ! grep -q "getA()" tests/tmp_out_dir/src/routes.sh; then
	echo "FAIL: missing getA"
	exit 1
fi
if ! grep -q "getB()" tests/tmp_out_dir/src/routes.sh; then
	echo "FAIL: missing getB"
	exit 1
fi
echo "SUCCESS"
rm -rf tests/tmp_input_dir tests/tmp_out_dir
