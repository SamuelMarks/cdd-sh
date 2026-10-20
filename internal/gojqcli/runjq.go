// Package gojqcli implements the stream-parameterized CLI runner for gojq.
package gojqcli

import "io"

// RunJq executes gojq with the given arguments and standard streams using default path resolution.
// Parameters:
//   - args: Command-line arguments passed to jq.
//   - inStream: Standard input stream.
//   - outStream: Standard output stream.
//   - errStream: Standard error stream.
//
// Returns the numeric exit status code.
func RunJq(args []string, inStream io.Reader, outStream, errStream io.Writer) int {
	return RunJqWithResolver(args, inStream, outStream, errStream, resolveJqPath)
}

// RunJqWithResolver executes gojq with the given arguments, standard streams, and an explicit path resolver.
// Parameters:
//   - args: Command-line arguments passed to jq.
//   - inStream: Standard input stream.
//   - outStream: Standard output stream.
//   - errStream: Standard error stream.
//   - resolver: Scoped path resolution function for relative file paths.
//
// Returns the numeric exit status code.
func RunJqWithResolver(args []string, inStream io.Reader, outStream, errStream io.Writer, resolver func(string) string) int {
	return (&cli{
		inStream:    inStream,
		outStream:   outStream,
		errStream:   errStream,
		resolvePath: resolver,
	}).run(args)
}
