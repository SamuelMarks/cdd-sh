# Shell WASM Support

The Shell toolchain leverages Go for certain core logic components, which are compiled to WASI (`wasip1`/`wasm`) utilizing the Go compiler.
WASM support is active and compiled using `make build_wasm`.

## Binary Size Optimization

`make build_wasm` applies several size reduction techniques to keep `wasm_build/cdd-sh.wasm` compact (~8.9 MB vs ~12 MB unoptimized):

1. **Pruned CLI Dependencies (`internal/gojqcli`)**: Excludes unused heavy dependencies from the embedded `gojq` CLI wrapper (`github.com/itchyny/go-yaml`, `github.com/mattn/go-runewidth` / `uax29/graphemes`, `github.com/mattn/go-isatty`, and `--stream` / `--yaml-*` modes).
2. **`GOEXPERIMENT=nojsonv2`**: Disables Go 1.26's experimental `encoding/json/v2` engine (`encoding/json/v2`, `encoding/json/jsontext`, `encoding/json/internal/*`), saving ~950 KB.
3. **Linker & Path Stripping (`-ldflags="-s -w" -trimpath`)**: Strips DWARF debugging tables, symbol tables, and local filesystem build paths.
4. **Binaryen Post-Processing (`wasm-opt -Oz`)**: When `wasm-opt` is available on `PATH`, runs size-focused WebAssembly bytecode optimization and strips custom debug/producer sections.