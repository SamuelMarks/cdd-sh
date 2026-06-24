#!/bin/sh
set -eu
# shellcheck disable=SC2296,SC3028,SC3040,SC3054
if [ "${SCRIPT_NAME-}" ]; then
	THIS_FILE="${SCRIPT_NAME}"
elif [ "${BASH_SOURCE-}" ]; then
	THIS_FILE="${BASH_SOURCE[0]}"
	set -o pipefail
elif [ "${ZSH_VERSION-}" ]; then
	eval 'THIS_FILE="${(%):-%x}"'
	set -o pipefail
else
	THIS_FILE="${0}"
fi

echo "Starting local Petstore server (swaggerapi/petstore)..."
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	CONTAINER_ID=$(docker run -d -e SWAGGER_URL=http://localhost:8100/api/swagger.json -p 8100:8080 swaggerapi/petstore)
	# shellcheck disable=SC2064
	trap 'docker rm -f "$CONTAINER_ID" >/dev/null 2>&1' EXIT
	echo "Waiting for local Petstore server to be ready..."
	timeout=60
	started=0
	while [ $timeout -gt 0 ]; do
		if curl -s -f http://localhost:8100/api/swagger.json >/dev/null; then
			started=1
			break
		fi
		sleep 1
		timeout=$((timeout - 1))
	done
	if [ "$started" = "1" ]; then
		export BASE_URL="http://localhost:8100/api"
		echo "Local Petstore server is ready at $BASE_URL"
	else
		echo "Local Petstore server failed to start, testing against remote petstore.swagger.io..."
		export BASE_URL="https://petstore.swagger.io/v2"
	fi
else
	echo "Docker not found, testing against remote petstore.swagger.io..."
	export BASE_URL="https://petstore.swagger.io/v2"
fi

echo "Testing Swagger SDK against $BASE_URL..."
rm -rf temp-swagger-sdk temp-openapi-sdk
./bin/cdd-sh from_openapi to_sdk -i ../petstore.json -o temp-swagger-sdk
# shellcheck disable=SC1091
. temp-swagger-sdk/src/routes.sh

res=$(findPetsByStatus "available")
if ! printf "%s" "$res" | grep -q "\[" && ! printf "%s" "$res" | grep -q "Not found"; then
	echo "FAIL: Swagger SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "Swagger SDK test passed!"

echo "Testing OpenAPI SDK against $BASE_URL..."
./bin/cdd-sh from_openapi to_sdk -i ../petstore_oas3.json -o temp-openapi-sdk
# shellcheck disable=SC1091
. temp-openapi-sdk/src/routes.sh

res=$(findPetsByStatus "available")
if ! printf "%s" "$res" | grep -q "\[" && ! printf "%s" "$res" | grep -q "Not found"; then
	echo "FAIL: OpenAPI SDK findPetsByStatus did not return expected array"
	exit 1
fi
echo "OpenAPI SDK test passed!"

rm -rf temp-swagger-sdk temp-openapi-sdk
