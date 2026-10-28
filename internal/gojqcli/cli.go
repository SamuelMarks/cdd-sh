// Package gojqcli implements the internal gojq command.
package gojqcli

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/itchyny/gojq"
)

const name = "gojq"

const version = "0.12.19"

var revision = "HEAD"

const (
	exitCodeOK = iota
	exitCodeFalsyErr
	exitCodeFlagParseErr
	exitCodeCompileErr
	exitCodeNoValueErr
	exitCodeDefaultErr
)

// cli holds the execution state, streams, and formatting options for a gojq invocation.
type cli struct {
	inStream  io.Reader
	outStream io.Writer
	errStream io.Writer

	outputRaw     bool
	outputRaw0    bool
	outputJoin    bool
	outputCompact bool
	outputIndent  *int
	outputTab     bool
	inputRaw      bool
	inputSlurp    bool

	argnames  []string
	argvalues []any

	exitCodeError error
	colors        colorConfig
	resolvePath   func(string) string
}

// resolveFilePath resolves a file path using the CLI's scoped resolver or falls back to resolveJqPath.
// Parameters:
//   - p: The file path to resolve.
//
// Returns the resolved file path string.
func (cli *cli) resolveFilePath(p string) string {
	if cli.resolvePath != nil {
		return cli.resolvePath(p)
	}
	return resolveJqPath(p)
}

// flagopts defines the command-line flags accepted by the gojq CLI.
type flagopts struct {
	OutputRaw     bool              `short:"r" long:"raw-output" description:"output raw strings"`
	OutputRaw0    bool              `long:"raw-output0" description:"implies -r with NUL character delimiter"`
	OutputJoin    bool              `short:"j" long:"join-output" description:"implies -r with no newline delimiter"`
	OutputCompact bool              `short:"c" long:"compact-output" description:"output without pretty-printing"`
	OutputIndent  *int              `long:"indent" args:"number" description:"number of spaces for indentation"`
	OutputTab     bool              `long:"tab" description:"use tabs for indentation"`
	OutputColor   bool              `short:"C" long:"color-output" description:"output with colors even if piped"`
	OutputMono    bool              `short:"M" long:"monochrome-output" description:"output without colors"`
	InputNull     bool              `short:"n" long:"null-input" description:"use null as input value"`
	InputRaw      bool              `short:"R" long:"raw-input" description:"read input as raw strings"`
	InputSlurp    bool              `short:"s" long:"slurp" description:"read all inputs into an array"`
	FromFile      bool              `short:"f" long:"from-file" description:"load query from file"`
	ModulePaths   []string          `short:"L" long:"library-path" args:"dir" description:"directory to search modules from"`
	Arg           map[string]string `long:"arg" args:"name value" description:"set a string value to a variable"`
	ArgJSON       map[string]string `long:"argjson" args:"name value" description:"set a JSON value to a variable"`
	SlurpFile     map[string]string `long:"slurpfile" args:"name file" description:"set the JSON contents of a file to a variable"`
	RawFile       map[string]string `long:"rawfile" args:"name file" description:"set the contents of a file to a variable"`
	Args          []any             `long:"args" positional:"" description:"consume remaining arguments as positional string values"`
	JSONArgs      []any             `long:"jsonargs" positional:"" description:"consume remaining arguments as positional JSON values"`
	ExitStatus    bool              `short:"e" long:"exit-status" description:"exit 1 when the last value is false or null"`
	Version       bool              `short:"v" long:"version" description:"display version information"`
	Help          bool              `short:"h" long:"help" description:"display this help information"`
}

var addDefaultModulePaths = true

// run executes the gojq CLI with the given arguments and returns the process exit code.
// Parameters:
//   - args: The command-line arguments slice.
//
// Returns the numeric exit status code.
func (cli *cli) run(args []string) int {
	if err := cli.runInternal(args); err != nil {
		if _, ok := err.(EmptyError); !ok {
			fmt.Fprintf(cli.errStream, "%s: %s\n", name, err)
		}
		if err, ok := err.(ExitCoder); ok {
			return err.ExitCode()
		}
		return exitCodeDefaultErr
	}
	return exitCodeOK
}

// runInternal parses flags, compiles the jq query, and processes all input streams.
// Parameters:
//   - args: The command-line arguments slice.
//
// Returns any flag, compilation, or runtime execution error.
func (cli *cli) runInternal(args []string) (err error) {
	var opts flagopts
	args, err = parseFlags(args, &opts)
	if err != nil {
		return &flagParseError{err}
	}
	if opts.Help {
		fmt.Fprintf(cli.outStream, `%[1]s - Go implementation of jq

Version: %s (rev: %s/%s)

Synopsis:
  %% echo '{"foo": 128}' | %[1]s '.foo'

Usage:
  %[1]s [OPTIONS]

`,
			name, version, revision, runtime.Version())
		fmt.Fprintln(cli.outStream, formatFlags(&opts))
		return nil
	}
	if opts.Version {
		fmt.Fprintf(cli.outStream, "%s %s (rev: %s/%s)\n", name, version, revision, runtime.Version())
		return nil
	}
	cli.outputRaw, cli.outputRaw0, cli.outputJoin,
		cli.outputCompact, cli.outputIndent, cli.outputTab =
		opts.OutputRaw, opts.OutputRaw0, opts.OutputJoin,
		opts.OutputCompact, opts.OutputIndent, opts.OutputTab
	disableColor := !opts.OutputColor || opts.OutputMono || os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb"
	cli.colors = defaultColorConfig(disableColor)
	if !cli.colors.noColor {
		if colors := os.Getenv("GOJQ_COLORS"); colors != "" {
			if err := cli.colors.parseColors(colors); err != nil {
				return err
			}
		}
	}
	if i := cli.outputIndent; i != nil {
		if *i > 9 {
			return newCliError(ErrKindInvalidIndent, exitCodeDefaultErr, fmt.Sprintf("too many indentation count: %d", *i))
		} else if *i < 0 {
			return newCliError(ErrKindInvalidIndent, exitCodeDefaultErr, fmt.Sprintf("negative indentation count: %d", *i))
		}
	}
	cli.inputRaw, cli.inputSlurp = opts.InputRaw, opts.InputSlurp
	for k, v := range opts.Arg {
		cli.argnames = append(cli.argnames, "$"+k)
		cli.argvalues = append(cli.argvalues, v)
	}
	for k, v := range opts.ArgJSON {
		val, _ := newJSONInputIter(strings.NewReader(v), "$"+k).Next()
		if err, ok := val.(error); ok {
			return err
		}
		cli.argnames = append(cli.argnames, "$"+k)
		cli.argvalues = append(cli.argvalues, val)
	}
	for k, v := range opts.SlurpFile {
		val, err := cli.slurpFile(v)
		if err != nil {
			return err
		}
		cli.argnames = append(cli.argnames, "$"+k)
		cli.argvalues = append(cli.argvalues, val)
	}
	for k, v := range opts.RawFile {
		var val []byte
		var err error
		if EmbeddedFS != nil {
			cleanName := filepath.Clean(v)
			for len(cleanName) > 0 && cleanName[0] == '/' {
				cleanName = cleanName[1:]
			}
			val, err = fs.ReadFile(EmbeddedFS, cleanName)
		}
		if err != nil || EmbeddedFS == nil {
			val, err = os.ReadFile(cli.resolveFilePath(v))
		}
		if err != nil {
			return err
		}
		cli.argnames = append(cli.argnames, "$"+k)
		cli.argvalues = append(cli.argvalues, string(val))
	}
	named := make(map[string]any, len(cli.argnames))
	for i, name := range cli.argnames {
		named[name[1:]] = cli.argvalues[i]
	}
	positional := opts.Args
	for i, v := range opts.JSONArgs {
		if strVal, ok := v.(string); ok {
			val, _ := newJSONInputIter(strings.NewReader(strVal), "--jsonargs").Next()
			if err, ok := val.(error); ok {
				return err
			}
			if i < len(positional) {
				positional[i] = val
			} else {
				positional = append(positional, val)
			}
		}
	}
	cli.argnames = append(cli.argnames, "$ARGS")
	cli.argvalues = append(cli.argvalues, map[string]any{
		"named":      named,
		"positional": positional,
	})
	var arg, fname string
	if opts.FromFile {
		if len(args) == 0 {
			return newCliError(ErrKindMissingFlagFile, exitCodeDefaultErr, "expected a query file for flag `-f'")
		}
		var src []byte
		var err error
		if EmbeddedFS != nil {
			cleanName := filepath.Clean(args[0])
			for len(cleanName) > 0 && cleanName[0] == '/' {
				cleanName = cleanName[1:]
			}
			src, err = fs.ReadFile(EmbeddedFS, cleanName)
		}
		if err != nil || EmbeddedFS == nil {
			src, err = os.ReadFile(cli.resolveFilePath(args[0]))
		}
		if err != nil {
			return err
		}
		arg, args, fname = string(src), args[1:], args[0]
	} else if len(args) == 0 {
		arg = "."
	} else {
		arg, args, fname = strings.TrimSpace(args[0]), args[1:], "<arg>"
	}
	if opts.ExitStatus {
		cli.exitCodeError = &exitCodeError{exitCodeNoValueErr}
		defer func() {
			if _, ok := err.(ExitCoder); !ok {
				err = cli.exitCodeError
			}
		}()
	}
	query, err := gojq.Parse(arg)
	if err != nil {
		return &queryParseError{fname, arg, err}
	}
	modulePaths := opts.ModulePaths
	if len(modulePaths) == 0 && addDefaultModulePaths {
		modulePaths = []string{"~/.jq", "$ORIGIN/../lib/gojq", "$ORIGIN/../lib"}
	}
	var iter inputIter
	if opts.InputNull {
		iter = newNullInputIter()
	} else {
		iter = cli.createInputIter(args)
	}
	defer iter.Close()
	code, err := gojq.Compile(query, gojq.WithModuleLoader(gojq.NewModuleLoader(modulePaths)),
		gojq.WithEnvironLoader(os.Environ),
		gojq.WithVariables(cli.argnames),
		gojq.WithFunction("debug", 0, 0, cli.funcDebug),
		gojq.WithFunction("stderr", 0, 0, cli.funcStderr),
		gojq.WithFunction("input_filename", 0, 0,
			func(iter inputIter) func(any, []any) any {
				return func(any, []any) any {
					if fname := iter.Name(); fname != "" && (len(args) > 0 || !opts.InputNull) {
						return fname
					}
					return nil
				}
			}(iter),
		),
		gojq.WithInputIter(iter),
	)
	if err != nil {
		if err, ok := err.(interface {
			QueryParseError() (string, string, error)
		}); ok {
			name, query, err := err.QueryParseError()
			return &queryParseError{name, query, err}
		}
		if err, ok := err.(interface {
			JSONParseError() (string, string, error)
		}); ok {
			fname, contents, err := err.JSONParseError()
			return &compileError{&jsonParseError{fname, contents, 0, err}}
		}
		return &compileError{err}
	}
	return cli.process(iter, code)
}

// slurpFile reads all JSON values from the specified file into a slice.
// Parameters:
//   - name: Path to the JSON file to slurp.
//
// Returns the slice of parsed JSON values and any file or parse error.
func (cli *cli) slurpFile(name string) (any, error) {
	iter := newSlurpInputIter(
		newFilesInputIterWithResolver(newJSONInputIter, []string{name}, nil, cli.resolveFilePath),
	)
	defer iter.Close()
	val, _ := iter.Next()
	if err, ok := val.(error); ok {
		return nil, err
	}
	return val, nil
}

// createInputIter constructs the appropriate inputIter based on CLI input flags and file arguments.
// Parameters:
//   - args: File paths to read from (or empty for stdin).
//
// Returns the configured inputIter.
func (cli *cli) createInputIter(args []string) (iter inputIter) {
	var newIter func(io.Reader, string) inputIter
	if cli.inputRaw {
		if cli.inputSlurp {
			newIter = newReadAllIter
		} else {
			newIter = newRawInputIter
		}
	} else {
		newIter = newJSONInputIter
	}
	if cli.inputSlurp {
		defer func() {
			if cli.inputRaw {
				iter = newSlurpRawInputIter(iter)
			} else {
				iter = newSlurpInputIter(iter)
			}
		}()
	}
	if len(args) == 0 {
		return newIter(cli.inStream, "<stdin>")
	}
	return newFilesInputIterWithResolver(newIter, args, cli.inStream, cli.resolveFilePath)
}

// process iterates over all input values, evaluates the compiled jq code, and prints output values.
// Parameters:
//   - iter: The input value iterator.
//   - code: The compiled gojq bytecode program.
//
// Returns an emptyError wrapping any input or evaluation error.
func (cli *cli) process(iter inputIter, code *gojq.Code) error {
	var err error
	for {
		v, ok := iter.Next()
		if !ok {
			break
		}
		if e, ok := v.(error); ok {
			fmt.Fprintf(cli.errStream, "%s: %s\n", name, e)
			err = e
			continue
		}
		if e := cli.printValues(code.Run(v, cli.argvalues...)); e != nil {
			if e, ok := e.(*gojq.HaltError); ok {
				if v := e.Value(); v != nil {
					if str, ok := v.(string); ok {
						cli.errStream.Write([]byte(str))
					} else {
						bs, _ := gojq.Marshal(v)
						cli.errStream.Write(bs)
						cli.errStream.Write([]byte{'\n'})
					}
				}
				err = e
				break
			}
			fmt.Fprintf(cli.errStream, "%s: %s\n", name, e)
			err = e
		}
	}
	if err != nil {
		return &emptyError{err}
	}
	return nil
}

// printValues marshals and writes each value yielded by a gojq evaluation iterator to outStream.
// Parameters:
//   - iter: The gojq result iterator.
//
// Returns any evaluation or output marshaling error.
func (cli *cli) printValues(iter gojq.Iter) error {
	m := cli.createMarshaler()
	for {
		v, ok := iter.Next()
		if !ok {
			break
		}
		if err, ok := v.(error); ok {
			return err
		}
		if err := m.marshal(v, cli.outStream); err != nil {
			return err
		}
		if cli.exitCodeError != nil {
			if v == nil || v == false {
				cli.exitCodeError = &exitCodeError{exitCodeFalsyErr}
			} else {
				cli.exitCodeError = &exitCodeError{exitCodeOK}
			}
		}
		if cli.outputRaw0 {
			cli.outStream.Write([]byte{'\x00'})
		} else if !cli.outputJoin {
			cli.outStream.Write([]byte{'\n'})
		}
	}
	return nil
}

// createMarshaler selects and configures the output marshaler based on CLI formatting flags.
// Parameters:
//   - none
//
// Returns the configured marshaler instance.
func (cli *cli) createMarshaler() marshaler {
	indent := 2
	if cli.outputCompact {
		indent = -1
	} else if cli.outputTab {
		indent = 1
	} else if i := cli.outputIndent; i != nil {
		indent = *i
	}
	f := newEncoderWithColors(cli.outputTab, indent, cli.colors)
	if cli.outputRaw || cli.outputRaw0 || cli.outputJoin {
		return &rawMarshaler{f, cli.outputRaw0}
	}
	return f
}

// funcDebug implements the built-in jq `debug` function by writing `["DEBUG:", v]` to errStream.
// Parameters:
//   - v: The current pipeline value.
//
// Returns v unchanged or an error if writing to errStream fails.
func (cli *cli) funcDebug(v any, _ []any) any {
	if err := newEncoderWithColors(false, -1, cli.colors).
		marshal([]any{"DEBUG:", v}, cli.errStream); err != nil {
		return err
	}
	if _, err := cli.errStream.Write([]byte{'\n'}); err != nil {
		return err
	}
	return v
}

// funcStderr implements the built-in jq `stderr` function by writing v in raw mode to errStream.
// Parameters:
//   - v: The current pipeline value.
//
// Returns v unchanged or an error if writing to errStream fails.
func (cli *cli) funcStderr(v any, _ []any) any {
	if err := (&rawMarshaler{m: newEncoderWithColors(false, -1, cli.colors)}).
		marshal(v, cli.errStream); err != nil {
		return err
	}
	return v
}
