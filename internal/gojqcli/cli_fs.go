// Package gojqcli implements the internal gojq command-line interface and virtualized filesystem hooks.
package gojqcli

import "io/fs"

// EmbeddedFS is an optional filesystem from which JQ scripts and modules can be loaded.
var EmbeddedFS fs.FS

// ResolvePath is an optional callback used to resolve relative JQ file paths against the active directory.
var ResolvePath func(string) string

// resolveJqPath resolves the given file path using ResolvePath if configured, or returns p unchanged.
// Parameters:
//   - p: The input file path to resolve.
//
// Returns the resolved file path string.
func resolveJqPath(p string) string {
	if ResolvePath != nil {
		return ResolvePath(p)
	}
	return p
}
