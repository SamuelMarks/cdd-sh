package gojqcli

import "io/fs"

// EmbeddedFS is an optional filesystem from which scripts/modules can be loaded.
var EmbeddedFS fs.FS

var ResolvePath func(string) string

func resolveJqPath(p string) string {
	if ResolvePath != nil {
		return ResolvePath(p)
	}
	return p
}
