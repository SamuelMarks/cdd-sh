package goawkcli

import "io/fs"

// EmbeddedFS is an optional filesystem from which scripts/modules can be loaded.
var EmbeddedFS fs.FS
