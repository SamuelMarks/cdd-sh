// Package main provides the WASI/WASM and native CLI runner for cdd-sh.
package main

import (
	"cmp"
	"context"
	"embed"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"cdd-sh/internal/goawkcli"
	"cdd-sh/internal/gojqcli"

	"mvdan.cc/sh/v3/expand"
	"mvdan.cc/sh/v3/interp"
	"mvdan.cc/sh/v3/syntax"
)

// RunnerErrorKind enumerates the structured error categories in the cdd-sh Go/WASM runner.
type RunnerErrorKind uint8

const (
	// ErrUnbundledCommand indicates an external host command is not bundled into the WASM runner.
	ErrUnbundledCommand RunnerErrorKind = iota
	// ErrCatFailed indicates a file read or copy error in the virtualized cat command.
	ErrCatFailed
	// ErrDirnameMissingOperand indicates dirname was invoked without an operand.
	ErrDirnameMissingOperand
	// ErrBasenameMissingOperand indicates basename was invoked without an operand.
	ErrBasenameMissingOperand
	// ErrChmodFailed indicates a file permission update error in the virtualized chmod command.
	ErrChmodFailed
	// ErrTouchFailed indicates a file creation error in the virtualized touch command.
	ErrTouchFailed
	// ErrMvFailed indicates a file rename error in the virtualized mv command.
	ErrMvFailed
	// ErrMkdirFailed indicates a directory creation error in the virtualized mkdir command.
	ErrMkdirFailed
	// ErrRmFailed indicates a file or directory removal error in the virtualized rm command.
	ErrRmFailed
	// ErrCpFailed indicates a file copy error in the virtualized cp command.
	ErrCpFailed
	// ErrMktempFailed indicates a temporary file or directory creation error in the virtualized mktemp command.
	ErrMktempFailed
	// ErrReadOnlyEmbeddedFile indicates a write attempt on a read-only embedded file.
	ErrReadOnlyEmbeddedFile
)

// RunnerError is a strongly typed error structure implementing error and ExitCode() for the shell runner.
type RunnerError struct {
	Kind RunnerErrorKind
	Msg  string
	Code uint8
}

// Error returns the formatted diagnostic message for the RunnerError.
// Parameters:
//   - none
//
// Returns the diagnostic error string.
func (e *RunnerError) Error() string {
	return e.Msg
}

// ExitCode returns the numeric exit status code associated with the RunnerError.
// Parameters:
//   - none
//
// Returns the numeric exit status code.
func (e *RunnerError) ExitCode() int {
	return int(e.Code)
}

// failRunner logs a structured RunnerError to stderr and returns the corresponding interp.ExitStatus.
// Parameters:
//   - stderr: The error output writer.
//   - kind: The structured RunnerErrorKind category.
//   - code: The numeric process exit code.
//   - msg: The diagnostic error message.
//
// Returns an error representing the interpreter exit status.
func failRunner(stderr io.Writer, kind RunnerErrorKind, code uint8, msg string) error {
	rerr := &RunnerError{Kind: kind, Msg: msg, Code: code}
	fmt.Fprintln(stderr, rerr.Error())
	return interp.NewExitStatus(uint8(rerr.ExitCode()))
}

// embeddedFiles holds the embedded POSIX shell scripts, libraries, and root marker.
//
//go:embed cdd.sh src lib ROOT
var embeddedFiles embed.FS

// workaroundBase holds an optional base directory prefix for WASI path resolution.
var workaroundBase string

// init configures the embedded filesystems and path resolvers for goawkcli and gojqcli.
// Parameters:
//   - none
//
// Returns nothing.
func init() {
	goawkcli.EmbeddedFS = embeddedFiles
	gojqcli.EmbeddedFS = embeddedFiles

	goawkcli.SetResolvePath(func(p string) string { return resolvePath(".", p) })
	gojqcli.SetResolvePath(func(p string) string { return resolvePath(".", p) })
}

// readWriteNopCloser wraps an io.Reader to satisfy io.ReadWriteCloser for read-only embedded files.
type readWriteNopCloser struct {
	io.Reader
}

// Write rejects write attempts to read-only embedded files.
// Parameters:
//   - p: The byte slice to write.
//
// Returns 0 and a RunnerError with ErrReadOnlyEmbeddedFile.
func (readWriteNopCloser) Write(p []byte) (n int, err error) {
	_ = p
	return 0, &RunnerError{Kind: ErrReadOnlyEmbeddedFile, Msg: "read-only embedded file", Code: 1}
}

// Close closes the underlying reader if it implements io.Closer.
// Parameters:
//   - none
//
// Returns any error encountered while closing.
func (r readWriteNopCloser) Close() error {
	if c, ok := r.Reader.(io.Closer); ok {
		return c.Close()
	}
	return nil
}

// script contains the entry point for the shell execution.
// It checks for the existence of cdd.sh and sources it.
var script = `#!/bin/sh
if [ -f "./cdd.sh" ]; then
    . ./cdd.sh "$@"
elif [ -f "/cdd.sh" ]; then
    . /cdd.sh "$@"
else
    echo "Error: cdd.sh not found in current directory or root" >&2
    exit 1
fi
`

// awkMiddleware intercepts the 'awk' command and runs the internal goawkcli implementation.
// Parameters:
//   - next: The next execution handler in the middleware chain.
//
// Returns an interp.ExecHandlerFunc that handles 'awk' invocations.
func awkMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) > 0 && args[0] == "awk" {
			hc := interp.HandlerCtx(ctx)
			exitCode := goawkcli.RunAwkWithResolver(args[1:], hc.Stdin, hc.Stdout, hc.Stderr, func(p string) string {
				return resolvePath(hc.Dir, p)
			})
			if exitCode == 0 {
				return nil
			}
			return interp.NewExitStatus(uint8(exitCode))
		}
		return next(ctx, args)
	}
}

// jqMiddleware intercepts the 'jq' command and runs the internal gojqcli implementation.
// Parameters:
//   - next: The next execution handler in the middleware chain.
//
// Returns an interp.ExecHandlerFunc that handles 'jq' invocations.
func jqMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) > 0 && args[0] == "jq" {
			hc := interp.HandlerCtx(ctx)
			exitCode := gojqcli.RunJqWithResolver(args[1:], hc.Stdin, hc.Stdout, hc.Stderr, func(p string) string {
				return resolvePath(hc.Dir, p)
			})
			if exitCode == 0 {
				return nil
			}
			return interp.NewExitStatus(uint8(exitCode))
		}
		return next(ctx, args)
	}
}

// resolvePath returns the absolute path based on a given base directory and a relative path p.
// If p is already absolute, it returns p directly.
// Parameters:
//   - base: The base working directory.
//   - p: The relative or absolute target path.
//
// Returns the resolved path string.
func resolvePath(base, p string) string {
	if filepath.IsAbs(p) {
		return p
	}
	joined := filepath.Join(base, p)
	if workaroundBase != "" && !filepath.IsAbs(joined) {
		if strings.HasPrefix(joined, "..") {
			return filepath.ToSlash(workaroundBase) + "/" + filepath.ToSlash(joined)
		}
		return filepath.Join(workaroundBase, joined)
	}
	return joined
}

// parseChmodMode parses an octal or symbolic chmod mode string into an os.FileMode.
// Parameters:
//   - modeStr: The mode argument (e.g., "+x", "0755", "644").
//
// Returns the parsed os.FileMode and any parse error.
func parseChmodMode(modeStr string) (os.FileMode, error) {
	if strings.Contains(modeStr, "+x") {
		return 0755, nil
	}
	if strings.Contains(modeStr, "-w") {
		return 0555, nil
	}
	parsed, err := strconv.ParseUint(modeStr, 8, 32)
	if err != nil {
		return 0, err
	}
	return os.FileMode(parsed), nil
}

// hostCommandValidator ensures that only a specific set of bundled commands are permitted to run.
// If an unbundled command is requested, it logs an error to Stderr and returns an exit status.
// Parameters:
//   - next: The next execution handler in the middleware chain.
//
// Returns an interp.ExecHandlerFunc that validates host command execution.
func hostCommandValidator(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) == 0 {
			return next(ctx, args)
		}

		switch args[0] {
		case "awk", "jq", "mkdir", "rm", "cp", "cat", "dirname", "basename", "mktemp", "mv", "chmod", "touch":
			return next(ctx, args)
		default:
			hc := interp.HandlerCtx(ctx)
			return failRunner(hc.Stderr, ErrUnbundledCommand, 127, fmt.Sprintf("Error: host OS command '%s' is not bundled into the WASM environment", args[0]))
		}
	}
}

// fsMiddleware provides basic implementations for standard file system commands like mkdir, rm, cp, cat, dirname, basename, mktemp, mv, chmod, and touch
// so that the script can execute them natively within the WASM environment without external binaries.
// Parameters:
//   - next: The next execution handler in the middleware chain.
//
// Returns an interp.ExecHandlerFunc that implements virtualized filesystem utilities.
func fsMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) == 0 {
			return next(ctx, args)
		}
		hc := interp.HandlerCtx(ctx)
		dir := hc.Dir

		if args[0] == "chmod" {
			if len(args) < 3 {
				return failRunner(hc.Stderr, ErrChmodFailed, 1, "chmod: missing operand")
			}
			mode, err := parseChmodMode(args[1])
			if err != nil {
				return failRunner(hc.Stderr, ErrChmodFailed, 1, fmt.Sprintf("chmod: %v", err))
			}
			for _, arg := range args[2:] {
				target := resolvePath(dir, arg)
				if err := os.Chmod(target, mode); err != nil {
					return failRunner(hc.Stderr, ErrChmodFailed, 1, fmt.Sprintf("chmod: %v", err))
				}
			}
			return nil
		}
		if args[0] == "touch" {
			if len(args) < 2 {
				return failRunner(hc.Stderr, ErrTouchFailed, 1, "touch: missing file operand")
			}
			for _, arg := range args[1:] {
				target := resolvePath(dir, arg)
				if _, err := os.Stat(target); err != nil {
					if err := os.WriteFile(target, []byte{}, 0644); err != nil {
						return failRunner(hc.Stderr, ErrTouchFailed, 1, fmt.Sprintf("touch: %v", err))
					}
				}
			}
			return nil
		}

		if args[0] == "mv" {
			if len(args) != 3 {
				return failRunner(hc.Stderr, ErrMvFailed, 1, "mv: missing file operand")
			}
			src := resolvePath(dir, args[1])
			dst := resolvePath(dir, args[2])
			if err := os.Rename(src, dst); err != nil {
				return failRunner(hc.Stderr, ErrMvFailed, 1, fmt.Sprintf("mv: %v", err))
			}
			return nil
		}
		if args[0] == "cat" {
			if len(args) == 1 {
				if _, copyErr := io.Copy(hc.Stdout, hc.Stdin); copyErr != nil {
					return failRunner(hc.Stderr, ErrCatFailed, 1, fmt.Sprintf("cat: %v", copyErr))
				}
				return nil
			}
			for _, arg := range args[1:] {
				if arg == "-" {
					if _, copyErr := io.Copy(hc.Stdout, hc.Stdin); copyErr != nil {
						return failRunner(hc.Stderr, ErrCatFailed, 1, fmt.Sprintf("cat: %v", copyErr))
					}
					continue
				}
				target := resolvePath(dir, arg)
				f, err := os.Open(target)
				if err != nil {
					return failRunner(hc.Stderr, ErrCatFailed, 1, fmt.Sprintf("cat: %v", err))
				}
				_, copyErr := io.Copy(hc.Stdout, f)
				closeErr := f.Close()
				if err := cmp.Or(copyErr, closeErr); err != nil {
					return failRunner(hc.Stderr, ErrCatFailed, 1, fmt.Sprintf("cat: %v", err))
				}
			}
			return nil
		}

		if args[0] == "dirname" {
			if len(args) < 2 {
				return failRunner(hc.Stderr, ErrDirnameMissingOperand, 1, "dirname: missing operand")
			}
			pathArg := args[len(args)-1]
			if pathArg == "" {
				fmt.Fprintln(hc.Stdout, ".")
				return nil
			}
			dir := filepath.Dir(pathArg)
			fmt.Fprintln(hc.Stdout, dir)
			return nil
		}

		if args[0] == "basename" {
			if len(args) < 2 {
				return failRunner(hc.Stderr, ErrBasenameMissingOperand, 1, "basename: missing operand")
			}
			pathArg := args[1]
			if pathArg == "" {
				fmt.Fprintln(hc.Stdout, ".")
				return nil
			}
			base := filepath.Base(pathArg)
			if len(args) >= 3 && args[2] != "" && base != args[2] && strings.HasSuffix(base, args[2]) {
				base = strings.TrimSuffix(base, args[2])
			}
			fmt.Fprintln(hc.Stdout, base)
			return nil
		}

		if args[0] == "mktemp" {
			makeDir := false
			var templateArg string
			for _, arg := range args[1:] {
				if arg == "-d" {
					makeDir = true
				} else if !strings.HasPrefix(arg, "-") {
					templateArg = arg
				}
			}
			parentDir := os.TempDir()
			pattern := "cdd_tmp.*"
			if templateArg != "" {
				resolvedTpl := resolvePath(dir, templateArg)
				parentDir = filepath.Dir(resolvedTpl)
				baseTpl := filepath.Base(resolvedTpl)
				pattern = strings.ReplaceAll(baseTpl, "XXXXXX", "*")
			}
			if makeDir {
				createdDir, err := os.MkdirTemp(parentDir, pattern)
				if err != nil {
					return failRunner(hc.Stderr, ErrMktempFailed, 1, fmt.Sprintf("mktemp: %v", err))
				}
				fmt.Fprintln(hc.Stdout, createdDir)
				return nil
			}
			createdFile, err := os.CreateTemp(parentDir, pattern)
			if err != nil {
				return failRunner(hc.Stderr, ErrMktempFailed, 1, fmt.Sprintf("mktemp: %v", err))
			}
			_ = createdFile.Close()
			fmt.Fprintln(hc.Stdout, createdFile.Name())
			return nil
		}

		if args[0] == "mkdir" {
			makeParents := false
			var dirs []string
			for _, arg := range args[1:] {
				if strings.HasPrefix(arg, "-") {
					if strings.Contains(arg, "p") {
						makeParents = true
					}
				} else {
					dirs = append(dirs, arg)
				}
			}
			for _, d := range dirs {
				target := resolvePath(dir, d)
				if makeParents {
					if err := os.MkdirAll(target, 0755); err != nil {
						return failRunner(hc.Stderr, ErrMkdirFailed, 1, fmt.Sprintf("mkdir: %v", err))
					}
				} else {
					if err := os.Mkdir(target, 0755); err != nil {
						return failRunner(hc.Stderr, ErrMkdirFailed, 1, fmt.Sprintf("mkdir: %v", err))
					}
				}
			}
			return nil
		}

		if args[0] == "rm" {
			force := false
			recursive := false
			var targets []string
			for _, arg := range args[1:] {
				if strings.HasPrefix(arg, "-") {
					if strings.Contains(arg, "r") || strings.Contains(arg, "R") {
						recursive = true
					}
					if strings.Contains(arg, "f") {
						force = true
					}
				} else {
					targets = append(targets, arg)
				}
			}
			for _, t := range targets {
				target := resolvePath(dir, t)
				var err error
				if recursive {
					err = os.RemoveAll(target)
				} else {
					err = os.Remove(target)
				}
				if err != nil && !force && !os.IsNotExist(err) {
					return failRunner(hc.Stderr, ErrRmFailed, 1, fmt.Sprintf("rm: %v", err))
				}
			}
			return nil
		}

		if args[0] == "cp" {
			var targets []string
			for _, arg := range args[1:] {
				if !strings.HasPrefix(arg, "-") {
					targets = append(targets, arg)
				}
			}
			if len(targets) >= 2 {
				dst := resolvePath(dir, targets[len(targets)-1])
				srcs := targets[:len(targets)-1]
				for _, s := range srcs {
					src := resolvePath(dir, s)
					input, err := os.ReadFile(src)
					if err != nil {
						return failRunner(hc.Stderr, ErrCpFailed, 1, fmt.Sprintf("cp: %v", err))
					}
					info, err := os.Stat(src)
					perm := os.FileMode(0644)
					if err == nil {
						perm = info.Mode().Perm()
					}

					dstPath := dst
					dstInfo, err := os.Stat(dst)
					if err == nil && dstInfo.IsDir() {
						dstPath = filepath.Join(dst, filepath.Base(src))
					}

					if err := os.WriteFile(dstPath, input, perm); err != nil {
						return failRunner(hc.Stderr, ErrCpFailed, 1, fmt.Sprintf("cp: %v", err))
					}
				}
			}
			return nil
		}

		return next(ctx, args)
	}
}

// builtinCallHandler allows simple overrides for builtin shell commands.
// Currently, it removes the "--" argument from 'cd'.
// Parameters:
//   - ctx: The execution context.
//   - args: The command arguments slice.
//
// Returns the transformed argument slice and any call error.
func builtinCallHandler(ctx context.Context, args []string) ([]string, error) {
	_ = ctx
	if len(args) == 0 {
		return args, nil
	}

	if args[0] == "cd" {
		var newArgs []string
		for _, arg := range args {
			if arg == "--" {
				continue
			}
			newArgs = append(newArgs, arg)
		}
		return newArgs, nil
	}

	return args, nil
}

// activeCallHandler holds the interp.CallHandlerFunc used by runMain, allowing injection in tests.
var activeCallHandler interp.CallHandlerFunc = builtinCallHandler

// newRunner is the factory function for creating an interp.Runner, allowing error injection in tests.
var newRunner = interp.New

// osExit is a variable pointing to os.Exit to allow mocking in tests.
var osExit = os.Exit

// runMain parses the given shell script override and executes it using the mvdan.cc/sh/v3/interp runner.
// It initializes all necessary middleware handlers and captures exit statuses appropriately.
// Parameters:
//   - scriptOverride: The shell script source code to execute.
//   - args: Positional arguments passed to the script.
//   - exitFunc: Callback invoked with the non-zero exit code on failure.
//
// Returns nothing.
func runMain(scriptOverride string, args []string, exitFunc func(int)) {
	r := strings.NewReader(scriptOverride)
	f, err := syntax.NewParser(syntax.Variant(syntax.LangPOSIX)).Parse(r, "")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		exitFunc(1)
		return
	}

	runner, err := newRunner(
		interp.StdIO(os.Stdin, os.Stdout, os.Stderr),
		interp.Env(expand.ListEnviron(os.Environ()...)),
		interp.Params(append([]string{"--"}, args...)...),

		interp.CallHandler(activeCallHandler),
		interp.ExecHandlers(awkMiddleware, jqMiddleware, fsMiddleware, hostCommandValidator),
		interp.StatHandler(func(ctx context.Context, name string, followSymlinks bool) (fs.FileInfo, error) {
			cleanName := filepath.Clean(name)
			cleanEmbedName := strings.TrimPrefix(cleanName, "/")
			info, err := fs.Stat(embeddedFiles, cleanEmbedName)
			if err == nil {
				return info, nil
			}
			return interp.DefaultStatHandler()(ctx, name, followSymlinks)
		}),
		interp.OpenHandler(func(ctx context.Context, path string, flag int, perm os.FileMode) (io.ReadWriteCloser, error) {
			cleanName := filepath.Clean(path)
			if flag == os.O_RDONLY {
				cleanEmbedName := strings.TrimPrefix(cleanName, "/")
				file, err := embeddedFiles.Open(cleanEmbedName)
				if err == nil {
					return readWriteNopCloser{file}, nil
				}
			}
			return interp.DefaultOpenHandler()(ctx, path, flag, perm)
		}),
	)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		exitFunc(1)
		return
	}

	err = runner.Run(context.Background(), f)
	if err != nil {
		if status, ok := interp.IsExitStatus(err); ok {
			exitFunc(int(status))
			return
		}
		fmt.Fprintln(os.Stderr, err)
		exitFunc(1)
	}
}

// main reads the runtime arguments and delegates execution to runMain with the default script.
// Parameters:
//   - none
//
// Returns nothing.
func main() {
	var args []string
	if len(os.Args) > 1 {
		args = os.Args[1:]
	}
	runMain(script, args, osExit)
}
