# Migration Plan: Integrating `jqjs` into the WASM Shell Environment

This plan outlines the steps required to use the pure-JavaScript `@michaelhomer/jqjs` implementation within the `cdd-sh` Go/WASM shell interpreter. 

Because `cdd-sh` compiles its Bash environment to WebAssembly via Go (`mvdan.cc/sh/v3/interp`), calling `jq` inside the shell script currently fails if a native `jq` binary isn't present in the WASM filesystem. To use a JavaScript implementation, we must create a bridge between the Go interpreter and the JavaScript host.

## 1. JavaScript Host Setup
- [ ] Set up a Node.js or Browser host environment capable of loading the `wasm_build/cdd-sh.wasm` file.
- [ ] Install the JS library: `npm install @michaelhomer/jqjs`.
- [ ] Create a globally accessible JS function (e.g., `globalThis.executeJqCLI = function(args, stdin, readFileCallback) { ... }`) that the Go WASM runtime can invoke.

## 2. JavaScript `jq` CLI Emulation
Since `jqjs` is an AST/library evaluator and not a CLI tool, you must write JS logic to mimic the `jq` CLI arguments heavily used in your `.sh` scripts.
- [ ] **Flag Parsing:** Parse standard flags like `-r` (raw output), `-c` (compact output), `-e` (exit status), `-s` (slurp), and `-n` (null input).
- [ ] **Variable Injection (`--arg`):** Map `--arg key value` CLI arguments into the `jqjs` evaluation context.
- [ ] **File Loading (`--slurpfile`):** Implement logic to read secondary files and inject them as arrays into the context. *(Note: Since the files live in the Go/WASM virtual filesystem, Go must either pass file contents to JS, or JS must be able to read from the WASM filesystem).*
- [ ] **Input Handling:** Parse the incoming `stdin` string as JSON (or treat as raw text if specific flags are passed).
- [ ] **Output Formatting:** Format the resulting JS generator output back into strings (e.g., unquoting strings if `-r` is used, strictly throwing exit codes if `-e` fails).

## 3. Go WebAssembly Command Interceptor (`main.go`)
The Go shell interpreter needs to catch calls to `jq` and redirect them to your JS function instead of trying to execute a missing binary.
- [ ] Import the `syscall/js` package in `main.go` (conditionally built for `js/wasm`).
- [ ] Define a custom `interp.ExecHandler` for the `runner`.
- [ ] Within the handler, check if the executed command is `jq`. (If not, fall back to the default handler).
- [ ] If `jq`, capture `args` and read all bytes from the interpreter's `ctx.Stdin()`.
- [ ] Use `js.Global().Call("executeJqCLI", ...)` to pass the arguments and stdin to the JavaScript environment.
- [ ] Write the returned JS string into `ctx.Stdout()`.
- [ ] Translate JavaScript exceptions or `-e` failure states into a non-zero Go shell exit status.

## 4. Filesystem Synchronization Strategy
- [ ] Design a mechanism for `--slurpfile` and standard file inputs (e.g., `jq . ast.json`) to work across the boundary.
  - *Option A:* The Go interceptor parses the `jq` arguments, reads all required files from the Go filesystem into memory, and passes their contents to JS.
  - *Option B:* The JS host environment uses a shared filesystem mechanism (like Emscripten's FS or a bridged Node `fs`) that maps to the same files Go sees.

## 5. Testing & Validation
- [ ] Execute `test.sh` inside the WASM environment utilizing the new bridge.
- [ ] Validate AST merging works (tests multiple `--slurpfile` loads).
- [ ] Validate URL encoding (`@uri`) and `gsub` functions behave identically to native C `jq`.
- [ ] Validate that errors and exit codes appropriately fail the Bash `if` statements (e.g., `if ! jq -e ...`).

---

**💡 Architectural Note / Alternative:**
While bridging Go/WASM to a JavaScript `jq` library works, it introduces a complex serialization boundary (`stdin`/`stdout` crossing the WASM-JS bridge repeatedly). 
Since your interpreter is written in Go, an alternative, dependency-free approach is to compile a pure-Go implementation of jq (like [`github.com/itchyny/gojq`](https://github.com/itchyny/gojq)) directly into `main.go`. You can mount `gojq` as an interceptor in the exact same way, but it avoids the JS bridge entirely, supports all CLI flags natively, and results in a completely self-contained `.wasm` binary.