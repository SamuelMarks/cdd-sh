package gojqcli

import "io"

// RunJq ...
func RunJq(args []string, inStream io.Reader, outStream, errStream io.Writer) int {
	return (&cli{
		inStream:  inStream,
		outStream: outStream,
		errStream: errStream,
	}).run(args)
}
