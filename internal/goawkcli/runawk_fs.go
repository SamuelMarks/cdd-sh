// Package goawkcli provides an internal CLI runner for the GoAWK interpreter,
// supporting embedded filesystems and custom path resolution in WASI/WASM environments.
package goawkcli

import "io/fs"

// EmbeddedFS is an optional filesystem from which AWK scripts and modules can be loaded.
var EmbeddedFS fs.FS

// ResolvePath is an optional callback used to resolve relative AWK file paths against the active directory.
var ResolvePath func(string) string

// resolveAwkPath resolves the given file path using ResolvePath if configured, or returns p unchanged.
// Parameters:
//   - p: The input file path to resolve.
//
// Returns the resolved file path string.
func resolveAwkPath(p string) string {
	if ResolvePath != nil {
		return ResolvePath(p)
	}
	return p
}
