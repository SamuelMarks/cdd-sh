#!/bin/sh
# @file tests/test_docs_json.sh
# @description Integration tests for docsjson emission (structured code components, flags, webhooks, directory output) and reverse-parsing.
# shellcheck disable=SC1091,SC2016
set -eu

ROOT_DIR="$(cd "$(dirname -- "$0")/.." && pwd)"
. "${ROOT_DIR}/lib/env.sh"

TMP_DOCS_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cdd_docsjson_test.XXXXXX")
# cleanup_docs_test removes temporary test artifacts on exit.
# @param none
cleanup_docs_test() {
	rm -rf "${TMP_DOCS_DIR}"
}
trap cleanup_docs_test EXIT INT TERM

echo "Testing to_docs_json structured code components and parameter extraction..."
sh "${ROOT_DIR}/cdd.sh" to_docs_json -i "${ROOT_DIR}/tests/test_docs_json.json" -o "${TMP_DOCS_DIR}/default_docs.json"
jq -e '
  ([10] | implode) as $nl |
  (["}", "", "main " + ("$@" | tojson)] | join($nl)) as $wend |
  .endpoints["/pets"].get.imports == ". ./routes.sh" and
  .endpoints["/pets"].get.wrapper_start == "main() {" and
  .endpoints["/pets"].get.snippet == "  listPets" and
  .endpoints["/pets"].get.wrapper_end == $wend and
  .endpoints["/pets/{petId}"].get.imports == ". ./routes.sh" and
  .endpoints["/pets/{petId}"].get.wrapper_start == "main() {" and
  .endpoints["/pets/{petId}"].get.snippet == ("  showPetById " + ("petId" | tojson)) and
  .endpoints["/pets/{petId}"].get.wrapper_end == $wend
' "${TMP_DOCS_DIR}/default_docs.json" >/dev/null

echo "Testing to_docs_json --no-imports and --no-wrapping flags..."
sh "${ROOT_DIR}/cdd.sh" to_docs_json --no-imports -i "${ROOT_DIR}/tests/test_docs_json.json" -o "${TMP_DOCS_DIR}/no_imports.json"
jq -e '
  ([10] | implode) as $nl |
  (["}", "", "main " + ("$@" | tojson)] | join($nl)) as $wend |
  .endpoints["/pets/{petId}"].get.imports == "" and
  .endpoints["/pets/{petId}"].get.wrapper_start == "main() {" and
  .endpoints["/pets/{petId}"].get.snippet == ("  showPetById " + ("petId" | tojson)) and
  .endpoints["/pets/{petId}"].get.wrapper_end == $wend
' "${TMP_DOCS_DIR}/no_imports.json" >/dev/null

sh "${ROOT_DIR}/cdd.sh" to_docs_json --no-wrapping -i "${ROOT_DIR}/tests/test_docs_json.json" -o "${TMP_DOCS_DIR}/no_wrapping.json"
jq -e '
  .endpoints["/pets/{petId}"].get.imports == ". ./routes.sh" and
  .endpoints["/pets/{petId}"].get.wrapper_start == "" and
  .endpoints["/pets/{petId}"].get.snippet == ("  showPetById " + ("petId" | tojson)) and
  .endpoints["/pets/{petId}"].get.wrapper_end == ""
' "${TMP_DOCS_DIR}/no_wrapping.json" >/dev/null

sh "${ROOT_DIR}/cdd.sh" to_docs_json --no-imports --no-wrapping -i "${ROOT_DIR}/tests/test_docs_json.json" -o "${TMP_DOCS_DIR}/no_both.json"
jq -e '
  .endpoints["/pets/{petId}"].get.imports == "" and
  .endpoints["/pets/{petId}"].get.wrapper_start == "" and
  .endpoints["/pets/{petId}"].get.snippet == ("  showPetById " + ("petId" | tojson)) and
  .endpoints["/pets/{petId}"].get.wrapper_end == ""
' "${TMP_DOCS_DIR}/no_both.json" >/dev/null

echo "Testing to_docs_json directory -o output path handling..."
WORK_OUT="${TMP_DOCS_DIR}/work_out"
mkdir -p "${WORK_OUT}"
sh "${ROOT_DIR}/cdd.sh" to_docs_json -i "${ROOT_DIR}/tests/test_docs_json.json" -o "${WORK_OUT}"
[ -f "${WORK_OUT}/docs.json" ]
jq -e '.endpoints["/pets/{petId}"].get.snippet == ("  showPetById " + ("petId" | tojson))' "${WORK_OUT}/docs.json" >/dev/null

echo "Testing to_docs_json realistic parameter examples, requestBody schemas, and OpenAPI webhooks..."
cat <<'EOF' >"${TMP_DOCS_DIR}/rich_spec.json"
{
  "openapi": "3.2.0",
  "info": {
    "title": "Rich Docs Spec",
    "version": "0.0.4"
  },
  "paths": {
    "/items/{itemId}": {
      "parameters": [
        {
          "name": "itemId",
          "in": "path",
          "required": true,
          "example": "item-42"
        }
      ],
      "post": {
        "operationId": "updateItem",
        "parameters": [
          {
            "name": "mode",
            "in": "query",
            "schema": {
              "type": "string",
              "enum": ["fast", "safe"]
            }
          }
        ],
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/ItemUpdate"
              }
            }
          }
        },
        "responses": {
          "200": { "description": "OK" }
        }
      }
    }
  },
  "webhooks": {
    "itemCreated": {
      "post": {
        "operationId": "onItemCreated",
        "requestBody": {
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "eventId": { "type": "string", "example": "evt-001" },
                  "active": { "type": "boolean" }
                }
              }
            }
          }
        },
        "responses": {
          "200": { "description": "Webhook received" }
        }
      }
    },
    "order-cancelled": {
      "post": {
        "summary": "Order cancelled webhook",
        "responses": {
          "200": { "description": "OK" }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "ItemUpdate": {
        "type": "object",
        "properties": {
          "title": { "type": "string", "example": "Laptop" },
          "count": { "type": "integer", "default": 3 }
        }
      }
    }
  }
}
EOF

sh "${ROOT_DIR}/cdd.sh" to_docs_json -i "${TMP_DOCS_DIR}/rich_spec.json" -o "${TMP_DOCS_DIR}/rich_docs.json"
jq -e '
  ([39] | implode) as $sq |
  .endpoints["/items/{itemId}"].post.imports == ". ./routes.sh" and
  .endpoints["/items/{itemId}"].post.wrapper_start == "main() {" and
  .endpoints["/items/{itemId}"].post.snippet == ("  updateItem " + ("fast" | tojson) + " " + ("item-42" | tojson) + " " + $sq + ({"title":"Laptop","count":3} | tojson) + $sq) and
  .webhooks.itemCreated.post.imports == ". ./routes.sh" and
  .webhooks.itemCreated.post.snippet == ("  onItemCreated " + $sq + ({"eventId":"evt-001","active":true} | tojson) + $sq) and
  .webhooks["order-cancelled"].post.snippet == "  handle_webhook_order_cancelled"
' "${TMP_DOCS_DIR}/rich_docs.json" >/dev/null

echo "Testing src/docsjson/parse.sh with structured and flat docs.json inputs..."
export CDD_AST_PATH="${TMP_DOCS_DIR}/ast_structured.json"
sh "${ROOT_DIR}/cdd.sh" parse docsjson "${TMP_DOCS_DIR}/rich_docs.json"
jq -e '
  .paths["/items/{itemId}"].post.operationId == "updateItem" and
  (.paths["/items/{itemId}"].post.parameters | length) == 2 and
  .paths["/items/{itemId}"].post.requestBody.content["application/json"].schema.properties.title.example == "Laptop" and
  .webhooks.itemCreated.post.operationId == "onItemCreated" and
  .webhooks.itemCreated.post.requestBody.content["application/json"].schema.properties.eventId.example == "evt-001"
' "${CDD_AST_PATH}" >/dev/null

jq -n '
  ([10] | implode) as $nl |
  ([39] | implode) as $sq |
  {
    "endpoints": {
      "/pets": {
        "get": ([". ./routes.sh", "", "main() {", "  listPets " + ("limit" | tojson), "}", "", "main " + ("$@" | tojson)] | join($nl))
      },
      "/pets/{petId}": {
        "get": ("  showPetById " + ("pet-99" | tojson)),
        "post": ("  updatePet " + ("pet-99" | tojson) + " " + $sq + ({"name":"Bella"} | tojson) + $sq)
      }
    },
    "webhooks": {
      "newPet": {
        "post": ([". ./routes.sh", "", "main() {", "  handle_webhook_newPet " + $sq + ({"id":7} | tojson) + $sq, "}", "", "main " + ("$@" | tojson)] | join($nl))
      }
    },
    "workflows": {
      "adoptFlow": ([". ./workflows.sh", "", "main() {", "  workflow_adopt_flow " + $sq + ({"petId":"pet-99"} | tojson) + $sq, "}", "", "main " + ("$@" | tojson)] | join($nl))
    }
  }
' >"${TMP_DOCS_DIR}/flat_docs.json"

export CDD_AST_PATH="${TMP_DOCS_DIR}/ast_flat.json"
sh "${ROOT_DIR}/cdd.sh" parse docsjson "${TMP_DOCS_DIR}/flat_docs.json"
jq -e '
  .paths["/pets"].get.operationId == "listPets" and
  .paths["/pets"].get.parameters[0].name == "limit" and
  .paths["/pets/{petId}"].get.operationId == "showPetById" and
  .paths["/pets/{petId}"].get.parameters[0].name == "petId" and
  .paths["/pets/{petId}"].get.parameters[0].example == "pet-99" and
  .paths["/pets/{petId}"].post.operationId == "updatePet" and
  .paths["/pets/{petId}"].post.requestBody.content["application/json"].schema.properties.name.example == "Bella" and
  .webhooks.newPet.post.operationId == "handle_webhook_newPet" and
  .workflows[0].workflowId == "adoptFlow" and
  .workflows[0].inputs.properties.petId.example == "pet-99"
' "${CDD_AST_PATH}" >/dev/null

echo "All docsjson tests passed!"
