// Package gojqcli implements the default standard-stream CLI runner for gojq.
package gojqcli

import "os"

// Run executes the gojq command-line interface using os.Args and standard streams.
// Parameters:
//   - none
//
// Returns the numeric exit status code.
func Run() int {
	return (&cli{
		inStream:  os.Stdin,
		outStream: os.Stdout,
		errStream: os.Stderr,
	}).run(os.Args[1:])
}
