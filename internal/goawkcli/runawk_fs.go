package goawkcli

import "io/fs"

// EmbeddedFS is an optional filesystem from which scripts/modules can be loaded.
var EmbeddedFS fs.FS

var ResolvePath func(string) string

// resolveAwkPath is a function
func resolveAwkPath(p string) string {
	if ResolvePath != nil {
		return ResolvePath(p)
	}
	return p
}
