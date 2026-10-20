#!/bin/sh
# @file tests/test_coverage_exhaustive.sh
# @description Exhaustive branch, function, CLI subcommand, parser, emitter, and Swagger/OpenAPI conversion coverage tests.
# shellcheck disable=SC1091,SC2016
. "$(cd "$(dirname -- "$0")/.." && pwd)/lib/env.sh"

TMP_COV="$(mktemp -d "${TMPDIR:-/tmp}/cdd_cov.XXXXXX")"
export CDD_AST_PATH="${TMP_COV}/ast.json"

# cleanup_cov_exhaustive removes the temporary directory used by exhaustive coverage tests.
# @param none
# @return Returns 0.
cleanup_cov_exhaustive() {
	rm -rf "${TMP_COV}"
}
trap cleanup_cov_exhaustive EXIT INT TERM

echo "Testing all cdd.sh help and version flags..."
for help_cmd in \
	"--help" "-h" "-help" \
	"from_openapi --help" \
	"from_openapi to_sdk --help" \
	"from_openapi to_sdk_cli --help" \
	"from_openapi to_server --help" \
	"to_openapi --help" \
	"from_arazzo --help" \
	"from_arazzo to_sdk --help" \
	"from_arazzo to_sdk_cli --help" \
	"from_arazzo to_server --help" \
	"to_arazzo --help" \
	"sync --help" \
	"to_docs_json --help" \
	"serve_json_rpc --help" \
	"mcp --help" \
	"parse --help" \
	"emit --help"; do
	# shellcheck disable=SC2086
	out=$(sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" ${help_cmd} 2>&1 || true)
	if ! printf '%s' "${out}" | grep -q "Usage:"; then
		echo "FAIL: Help output missing Usage for '${help_cmd}'"
		exit 1
	fi
done

for ver_flag in "-v" "-V" "--version" "-version"; do
	v_out=$(sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" "${ver_flag}")
	if [ "${v_out}" != "0.0.4" ]; then
		echo "FAIL: Version flag ${ver_flag} returned ${v_out}"
		exit 1
	fi
done

# Test unknown command and unknown global flag
if sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" unknown_cmd >/dev/null 2>&1; then
	echo "FAIL: unknown_cmd should exit non-zero"
	exit 1
fi
if sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" to_openapi --unknown-flag >/dev/null 2>&1; then
	echo "FAIL: --unknown-flag should exit non-zero"
	exit 1
fi
if sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse unknown_type foo >/dev/null 2>&1; then
	echo "FAIL: parse unknown_type should exit non-zero"
	exit 1
fi

echo "Testing functions, docstrings, mocks, and tests parsers and emitters..."
cat <<'FUNC_IN' >"${TMP_COV}/funcs_in.sh"
#!/bin/sh
# @function greet_user
# @description Greets a "quoted" user\name across lines
greet_user() {
  msg="Hello $1"
  echo "$msg"
}
FUNC_IN

sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse functions "${TMP_COV}/funcs_in.sh"
if ! jq -e '."x-functions".greet_user.description == "Greets a \"quoted\" user\\name across lines"' "${CDD_AST_PATH}" >/dev/null; then
	echo "FAIL: functions/parse.sh did not escape quotes/backslashes properly"
	cat "${CDD_AST_PATH}"
	exit 1
fi
if ! jq -e '."x-functions".greet_user.body | contains("\n")' "${CDD_AST_PATH}" >/dev/null; then
	echo "FAIL: functions/parse.sh did not preserve multi-line function body"
	cat "${CDD_AST_PATH}"
	exit 1
fi
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" emit functions "${TMP_COV}/funcs_out.sh"
if ! grep -q "greet_user()" "${TMP_COV}/funcs_out.sh"; then
	echo "FAIL: functions/emit.sh did not emit greet_user()"
	exit 1
fi

echo "Testing docstrings/parse.sh with quotes..."
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse openapi tests/test.json
cat <<'DOCS_IN' >"${TMP_COV}/docs.md"
# Quoted "API" Title (1.2.3)
API description with "quotes" and \backslash.

## getUsers
Operation description with "quotes".
DOCS_IN
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse docstrings "${TMP_COV}/docs.md"
if ! jq -e '.info.title == "Quoted \"API\" Title" and .paths["/users"].get.description == "Operation description with \"quotes\"."' "${CDD_AST_PATH}" >/dev/null; then
	echo "FAIL: docstrings/parse.sh did not preserve quotes"
	cat "${CDD_AST_PATH}"
	exit 1
fi

echo "Testing mocks/emit.sh with custom filename and mocks/parse.sh..."
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" emit mocks "${TMP_COV}/custom_mocks.json"
if ! grep -q "custom_mocks.json" "${TMP_COV}/mocks.sh"; then
	echo "FAIL: mocks/emit.sh did not reference custom_mocks.json in mocks.sh"
	cat "${TMP_COV}/mocks.sh"
	exit 1
fi
echo '{"sampleExample": {"value": {"id": 42}}}' >"${TMP_COV}/custom_mocks.json"
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse mocks "${TMP_COV}/custom_mocks.json"
if ! jq -e '.components.examples.sampleExample.value.id == 42' "${CDD_AST_PATH}" >/dev/null; then
	echo "FAIL: mocks/parse.sh did not update components.examples"
	exit 1
fi

echo "Testing Swagger 2.0 body/formData/response/ref conversion and relative server URLs..."
cat <<'SWAG2' >"${TMP_COV}/swagger2_full.json"
{
  "swagger": "2.0",
  "info": {"title": "Full Swagger 2", "version": "1.0.0"},
  "host": "petstore.swagger.io",
  "basePath": "/v2",
  "schemes": ["https"],
  "consumes": ["application/json"],
  "produces": ["application/json"],
  "paths": {
    "/pet": {
      "post": {
        "operationId": "addPet",
        "parameters": [
          {
            "in": "body",
            "name": "body",
            "required": true,
            "schema": {"$ref": "#/definitions/Pet"}
          }
        ],
        "responses": {
          "200": {
            "description": "Created",
            "schema": {"$ref": "#/definitions/Pet"}
          }
        }
      }
    },
    "/pet/{petId}/upload": {
      "post": {
        "operationId": "uploadFile",
        "consumes": ["multipart/form-data"],
        "parameters": [
          {"name": "petId", "in": "path", "required": true, "type": "integer"},
          {"name": "additionalMetadata", "in": "formData", "type": "string"}
        ],
        "responses": {"200": {"description": "OK"}}
      }
    }
  },
  "definitions": {
    "Pet": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": {"type": "string", "minLength": 3, "maxLength": 10},
        "weight": {"type": "number", "minimum": 0.5, "maximum": 99.5, "exclusiveMinimum": 0.1, "exclusiveMaximum": 100.0}
      }
    }
  }
}
SWAG2

sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" parse openapi "${TMP_COV}/swagger2_full.json"
if ! jq -e '.paths["/pet"].post.requestBody.content["application/json"].schema."$ref" == "#/components/schemas/Pet"' "${CDD_AST_PATH}" >/dev/null; then
	echo 'FAIL: swagger2openapi.jq did not convert in:body parameter and rewrite $ref'
	cat "${CDD_AST_PATH}"
	exit 1
fi
if ! jq -e '.paths["/pet/{petId}/upload"].post.requestBody.content["multipart/form-data"].schema.properties.additionalMetadata.type == "string"' "${CDD_AST_PATH}" >/dev/null; then
	echo "FAIL: swagger2openapi.jq did not convert formData parameter"
	exit 1
fi

CDD_EMIT_SWAGGER2=1 sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" emit openapi "${TMP_COV}/back_to_swagger2.json"
if ! jq -e '.definitions.Pet and (.paths["/pet"].post.parameters[0].in == "body") and (.paths["/pet"].post.parameters[0].schema."$ref" == "#/definitions/Pet")' "${TMP_COV}/back_to_swagger2.json" >/dev/null; then
	echo 'FAIL: openapi2swagger.jq did not convert requestBody and $ref back to Swagger 2.0'
	cat "${TMP_COV}/back_to_swagger2.json"
	exit 1
fi

echo "Testing exact string length and float validation in classes/emit.jq..."
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" emit classes "${TMP_COV}/pet_classes.sh"
# shellcheck disable=SC1090
. "${TMP_COV}/pet_classes.sh"
if ! validate_Pet '{"name": "cat", "weight": 1.5}'; then
	echo "FAIL: validate_Pet rejected 3-char string 'cat' (minLength=3) or float weight 1.5"
	exit 1
fi
if validate_Pet '{"name": "ab", "weight": 1.5}'; then
	echo "FAIL: validate_Pet accepted 2-char string 'ab' (minLength=3)"
	exit 1
fi
if validate_Pet '{"name": "cat", "weight": 0.2}'; then
	echo "FAIL: validate_Pet accepted float weight 0.2 < minimum 0.5"
	exit 1
fi

echo "Testing from_openapi to_docs_json and to_openapi subcommands..."
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" from_openapi to_docs_json -i tests/test.json -o "${TMP_COV}/docs_out"
if [ ! -f "${TMP_COV}/docs_out/docs.json" ] || ! jq -e '.endpoints["/users"].get' "${TMP_COV}/docs_out/docs.json" >/dev/null; then
	echo "FAIL: from_openapi to_docs_json did not produce valid docs.json"
	exit 1
fi

sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" from_openapi to_sdk --tests -i tests/test.json -o "${TMP_COV}/sdk_dir" --no-github-actions --no-installable-package
sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" from_openapi to_openapi -i "${TMP_COV}/sdk_dir" -o "${TMP_COV}/extracted_oas"
if [ ! -f "${TMP_COV}/extracted_oas/spec.json" ]; then
	echo "FAIL: from_openapi to_openapi did not produce spec.json"
	exit 1
fi

sh "${LIBSCRIPT_ROOT_DIR}/cdd.sh" to_openapi -i "${TMP_COV}/sdk_dir" -o "${TMP_COV}/dir_oas.json"
if [ ! -f "${TMP_COV}/dir_oas.json" ]; then
	echo "FAIL: to_openapi on directory failed"
	exit 1
fi

echo "All exhaustive coverage tests passed!"
