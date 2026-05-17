# Shell WASM Support

The Shell toolchain leverages Go for certain core logic components, which are compiled to WASI (`wasip1`/`wasm`) utilizing the Go compiler.
WASM support is active and compiled using `make build_wasm`.