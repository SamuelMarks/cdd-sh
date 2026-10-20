// Package goawkcli provides a command-line wrapper and virtualized filesystem adapter for goawk.
package goawkcli

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"os"
	"strings"

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
	// ErrAwkInvalidVar indicates a `-v` argument did not contain an `=` assignment.
	ErrAwkInvalidVar
)

// AwkError is a strongly typed error returned during AWK CLI parsing or execution.
type AwkError struct {
	Kind AwkErrorKind
	Msg  string
}

// Error returns the formatted AWK diagnostic message.
// Parameters:
//   - none
//
// Returns the formatted error string.
func (e *AwkError) Error() string {
	return "awk: " + e.Msg
}

// ExitCode returns the numeric exit status code (1) for the AWK error.
// Parameters:
//   - none
//
// Returns 1.
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

// RunAwk executes goawk with the given arguments and standard streams using default path resolution.
// Parameters:
//   - args: Command-line arguments passed to awk.
//   - stdin: Standard input stream.
//   - stdout: Standard output stream.
//   - stderr: Standard error stream.
//
// Returns the numeric exit status code.
func RunAwk(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	return RunAwkWithResolver(args, stdin, stdout, stderr, resolveAwkPath)
}

// RunAwkWithResolver executes goawk with the given arguments, streams, and an explicit path resolver.
// Parameters:
//   - args: Command-line arguments passed to awk.
//   - stdin: Standard input stream.
//   - stdout: Standard output stream.
//   - stderr: Standard error stream.
//   - resolver: Scoped path resolution function for relative file paths.
//
// Returns the numeric exit status code.
func RunAwkWithResolver(args []string, stdin io.Reader, stdout, stderr io.Writer, resolver func(string) string) int {
	var prog string
	var progFiles []string
	var files []string
	var vars []string
	var fsVar string

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "--" {
			i++
			break
		} else if arg == "-F" {
			if i+1 < len(args) {
				fsVar = args[i+1]
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- F")
			}
		} else if strings.HasPrefix(arg, "-F") {
			fsVar = arg[2:]
			i++
		} else if arg == "-v" {
			if i+1 < len(args) {
				vars = append(vars, args[i+1])
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- v")
			}
		} else if strings.HasPrefix(arg, "-v") {
			vars = append(vars, arg[2:])
			i++
		} else if arg == "-f" {
			if i+1 < len(args) {
				progFiles = append(progFiles, args[i+1])
				i += 2
			} else {
				return failAwk(stderr, ErrAwkMissingArg, "option requires an argument -- f")
			}
		} else if strings.HasPrefix(arg, "-f") {
			progFiles = append(progFiles, arg[2:])
			i++
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
			resolved := f
			if resolver != nil {
				resolved = resolver(f)
			}
			b, err = os.ReadFile(resolved)
		}

		if err != nil {
			return failAwk(stderr, ErrAwkFileOpen, fmt.Sprintf("cannot open %s (%s)", f, err))
		}
		progBuf.Write(b)
		progBuf.WriteByte(10)
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
		eqIdx := strings.IndexByte(v, '=')
		if eqIdx <= 0 {
			return failAwk(stderr, ErrAwkInvalidVar, fmt.Sprintf("invalid -v assignment: %s", v))
		}
		config.Vars = append(config.Vars, v[:eqIdx], v[eqIdx+1:])
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
