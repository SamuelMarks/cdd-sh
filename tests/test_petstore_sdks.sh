#!/bin/sh
set -eu

echo "Testing Swagger SDK against petstore.swagger.io..."
rm -rf temp-swagger-sdk temp-openapi-sdk
./bin/cdd-sh from_openapi to_sdk -i ../petstore.json -o temp-swagger-sdk
# shellcheck disable=SC1091
. temp-swagger-sdk/src/routes.sh

export BASE_URL="https://petstore.swagger.io/v2"

res=$(findPetsByStatus "available")
if ! echo "$res" | grep -q "\["; then
	echo "FAIL: Swagger SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "Swagger SDK test passed!"

echo "Testing OpenAPI SDK against petstore.swagger.io..."
./bin/cdd-sh from_openapi to_sdk -i ../petstore_oas3.json -o temp-openapi-sdk
# shellcheck disable=SC1091
. temp-openapi-sdk/src/routes.sh

export BASE_URL="https://petstore.swagger.io/v2"

res=$(findPetsByStatus "available")
if ! echo "$res" | grep -q "\["; then
	echo "FAIL: OpenAPI SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "OpenAPI SDK test passed!"

rm -rf temp-swagger-sdk temp-openapi-sdk
