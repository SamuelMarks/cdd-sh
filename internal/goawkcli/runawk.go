// Package goawkcli provides a command-line wrapper and virtualized filesystem adapter for goawk.
package goawkcli

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"os"

	"github.com/benhoyt/goawk/interp"
	"github.com/benhoyt/goawk/parser"
)

// AwkErrorKind enumerates the structured error categories in goawkcli.
type AwkErrorKind uint8

const (
	// ErrAwkMissingArg indicates a CLI flag is missing its required argument.
	ErrAwkMissingArg AwkErrorKind = iota
	// ErrAwkMissingProg indicates no AWK program was provided on the command line.
	ErrAwkMissingProg
	// ErrAwkFileOpen indicates an AWK script file could not be read.
	ErrAwkFileOpen
	// ErrAwkSyntax indicates an AWK program syntax error.
	ErrAwkSyntax
	// ErrAwkRuntime indicates an AWK runtime execution error.
	ErrAwkRuntime
)

// AwkError is a strongly typed error returned during AWK CLI parsing or execution.
type AwkError struct {
	Kind AwkErrorKind
	Msg  string
}

// Error returns the formatted AWK diagnostic message.
func (e *AwkError) Error() string {
	return "awk: " + e.Msg
}

// ExitCode returns the numeric exit status code (1) for the AWK error.
func (e *AwkError) ExitCode() int {
	return 1
}

// failAwk logs a structured AwkError to stderr and returns its exit code.
// Parameters:
//   - stderr: The error output writer.
//   - kind: The structured AwkErrorKind category.
//   - msg: The diagnostic message.
//
// Returns the numeric exit status code.
func failAwk(stderr io.Writer, kind AwkErrorKind, msg string) int {
	err := &AwkError{Kind: kind, Msg: msg}
	fmt.Fprintln(stderr, err.Error())
	return err.ExitCode()
}

// RunAwk executes goawk with the given arguments and standard streams.
// Parameters:
//   - args: Command-line arguments passed to awk.
//   - stdin: Standard input stream.
//   - stdout: Standard output stream.
//   - stderr: Standard error stream.
//
// Returns the numeric exit status code.
func RunAwk(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	var prog string
	var progFiles []string
	var files []string
	var vars []string
	var fsVar string

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "-F" {
			if i+1 < len(args) {
				fsVar = args[i+1]
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- F")
			}
		} else if arg == "-v" {
			if i+1 < len(args) {
				vars = append(vars, args[i+1])
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- v")
			}
		} else if arg == "-f" {
			if i+1 < len(args) {
				progFiles = append(progFiles, args[i+1])
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- f")
			}
		} else {
			break
		}
	}

	if len(progFiles) == 0 {
		if i < len(args) {
			prog = args[i]
			i++
		} else {
			return failAwk(stderr, ErrAwkMissingProg, "missing program")
		}
	}

	for i < len(args) {
		files = append(files, args[i])
		i++
	}

	var progBuf bytes.Buffer
	for _, f := range progFiles {
		var b []byte
		var err error
		if EmbeddedFS != nil {
			cleanName := f
			for len(cleanName) > 0 && cleanName[0] == '/' {
				cleanName = cleanName[1:]
			}
			b, err = fs.ReadFile(EmbeddedFS, cleanName)
		}
		if err != nil || EmbeddedFS == nil {
			b, err = os.ReadFile(resolveAwkPath(f))
		}

		if err != nil {
			return failAwk(stderr, ErrAwkFileOpen, fmt.Sprintf("cannot open %s (%s)", f, err))
		}
		progBuf.Write(b)
		progBuf.WriteByte('\n')
	}
	if len(progFiles) > 0 {
		prog = progBuf.String()
	}

	p, err := parser.ParseProgram([]byte(prog), nil)
	if err != nil {
		return failAwk(stderr, ErrAwkSyntax, fmt.Sprintf("syntax error: %s", err))
	}

	config := &interp.Config{
		Stdin:  stdin,
		Output: stdout,
		Error:  stderr,
		Vars:   []string{},
	}
	if fsVar != "" {
		config.Vars = append(config.Vars, "FS", fsVar)
	}
	for _, v := range vars {
		for j := 0; j < len(v); j++ {
			if v[j] == '=' {
				config.Vars = append(config.Vars, v[:j], v[j+1:])
				break
			}
		}
	}

	if len(files) > 0 {
		config.Args = files
	}

	status, err := interp.ExecProgram(p, config)
	if err != nil {
		return failAwk(stderr, ErrAwkRuntime, err.Error())
	}
	return status
}
