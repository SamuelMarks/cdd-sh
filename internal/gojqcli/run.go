package gojqcli

import "os"

// Run executes the gojq command-line interface using os.Args and standard streams.
func Run() int {
	return (&cli{
		inStream:  os.Stdin,
		outStream: os.Stdout,
		errStream: os.Stderr,
	}).run(os.Args[1:])
}
