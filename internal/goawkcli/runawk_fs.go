// Package goawkcli provides an internal CLI runner for the GoAWK interpreter,
// supporting embedded filesystems and custom path resolution in WASI/WASM environments.
package goawkcli

import (
	"io/fs"
	"sync"
)

// EmbeddedFS is an optional filesystem from which AWK scripts and modules can be loaded.
var EmbeddedFS fs.FS

// ResolvePath is an optional callback used to resolve relative AWK file paths against the active directory.
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

// resolveAwkPath resolves the given file path using ResolvePath if configured, or returns p unchanged.
// Parameters:
//   - p: The input file path to resolve.
//
// Returns the resolved file path string.
func resolveAwkPath(p string) string {
	resolveMu.RLock()
	fn := ResolvePath
	resolveMu.RUnlock()
	if fn != nil {
		return fn(p)
	}
	return p
}
