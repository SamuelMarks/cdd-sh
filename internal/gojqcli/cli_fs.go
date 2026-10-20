// Package gojqcli implements the internal gojq command-line interface and virtualized filesystem hooks.
package gojqcli

import (
	"io/fs"
	"sync"
)

// EmbeddedFS is an optional filesystem from which JQ scripts and modules can be loaded.
var EmbeddedFS fs.FS

// ResolvePath is an optional callback used to resolve relative JQ file paths against the active directory.
var ResolvePath func(string) string

// resolveMu synchronizes concurrent reads and updates to ResolvePath.
var resolveMu sync.RWMutex

// SetResolvePath safely updates ResolvePath under a write lock.
// Parameters:
//   - fn: The path resolution callback function.
//
// Returns nothing.
func SetResolvePath(fn func(string) string) {
	resolveMu.Lock()
	ResolvePath = fn
	resolveMu.Unlock()
}

// resolveJqPath resolves the given file path using ResolvePath if configured, or returns p unchanged.
// Parameters:
//   - p: The input file path to resolve.
//
// Returns the resolved file path string.
func resolveJqPath(p string) string {
	resolveMu.RLock()
	fn := ResolvePath
	resolveMu.RUnlock()
	if fn != nil {
		return fn(p)
	}
	return p
}
