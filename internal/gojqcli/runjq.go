// Package gojqcli implements the stream-parameterized CLI runner for gojq.
package gojqcli

import "io"

// RunJq executes gojq with the given arguments and standard streams.
// Parameters:
//   - args: Command-line arguments passed to jq.
//   - inStream: Standard input stream.
//   - outStream: Standard output stream.
//   - errStream: Standard error stream.
//
// Returns the numeric exit status code.
func RunJq(args []string, inStream io.Reader, outStream, errStream io.Writer) int {
	return (&cli{
		inStream:  inStream,
		outStream: outStream,
		errStream: errStream,
	}).run(args)
}
