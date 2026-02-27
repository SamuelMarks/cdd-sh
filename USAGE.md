# Usage Guide

`cdd-sh` acts as a compiler that translates back and forth between an OpenAPI spec and executable code.

## Command Reference

The CLI syntax is:
```sh
./cdd.sh <command> <module_type> [file_path]
```

* `command`: Either `parse` (Code -> AST) or `emit` (AST -> Code).
* `module_type`: `openapi`, `routes`, `classes`, `tests`, `mocks`, `docstrings`.
* `file_path`: (Optional) Target file. Defaults to `type.extension` (e.g., `routes.sh`, `classes.sh`).

## Workflow 1: Spec to Code

If you start with an OpenAPI `openapi.json`:

```sh
# 1. Load the spec into the compiler's memory (ast.json)
./cdd.sh parse openapi openapi.json

# 2. Generate your API client
./cdd.sh emit routes my_client.sh

# 3. Generate your data validators
./cdd.sh emit classes my_classes.sh

# 4. Generate your markdown documentation
./cdd.sh emit docstrings docs.md
```

You can now `. ./my_client.sh` in your shell scripts to execute `getUsers()`, `createUser()`, etc.

## Workflow 2: Code to Spec (Bidirectional Sync)

The true power of `cdd-sh` is that you do not need to manually write YAML/JSON to update your OpenAPI specification. Just edit the shell files!

Open the generated `routes.sh`. You will notice comment annotations like `# @function`, `# @param`, and `# @description`. 

Add your own route at the bottom of the file:

```sh
# @function checkHealth
# @description Ping the health server
# @param $1: force (query) - Force deep check
checkHealth() {
  force="${1:-}"
  url="${BASE_URL}/health"
  qs=""
  [ -n "${force}" ] && qs="force=$(_urlencode "${force}")"
  [ -n "${qs}" ] && url="${url}?${qs}"
  curl -s -X GET "${url}"
}
```

Now, tell `cdd-sh` to ingest your code changes:

```sh
# 1. Parse the routes back into the AST
./cdd.sh parse routes routes.sh

# 2. Emit the updated OpenAPI specification!
./cdd.sh emit openapi updated_spec.json
```

If you look at `updated_spec.json`, you will see your new `/health` path, operations, and parameters meticulously documented in OpenAPI 3.2.0 JSON.

## Environment Variables
When using the generated `routes.sh` client, the following standard variables will control request behavior:

* `BASE_URL`: Overrides the default server from the spec.
* `OAUTH_TOKEN`: If using Bearer/OAuth2, this value is injected.
* `API_KEY`: If using API Keys, this value is injected.
* `BASIC_AUTH`: If using Basic Auth, formatted as `user:pass`.
