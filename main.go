package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
"runtime"

	"cdd-sh/internal/goawkcli"
	"cdd-sh/internal/gojqcli"
	"embed"
	"io/fs"

	"mvdan.cc/sh/v3/expand"
	"mvdan.cc/sh/v3/interp"
	"mvdan.cc/sh/v3/syntax"
)

// script contains the entry point for the shell execution.
// It checks for the existence of cdd.sh and sources it.

//go:embed cdd.sh src lib ROOT
var embeddedFiles embed.FS

var workaroundBase string

func init() {
	goawkcli.EmbeddedFS = embeddedFiles
	gojqcli.EmbeddedFS = embeddedFiles

	goawkcli.ResolvePath = func(p string) string { return resolvePath(".", p) }
	gojqcli.ResolvePath = func(p string) string { return resolvePath(".", p) }
	
	if runtime.GOOS == "wasip1" {
		statDot, err := os.Stat(".")
		if err == nil {
			entries, err := os.ReadDir("..")
			if err == nil {
				for _, e := range entries {
					if !e.IsDir() {
						continue
					}
					statParent, err := os.Stat("../" + e.Name())
					if err == nil && os.SameFile(statDot, statParent) {
						workaroundBase = "../" + e.Name()
						break
					}
				}
			}
		}
	}
}

func getDir(ctx context.Context) string {
	defer func() { recover() }()
	hc := interp.HandlerCtx(ctx)
	if hc.Dir != "" {
		return hc.Dir
	}
	return "."
}

type readWriteNopCloser struct {
	io.Reader
}

func (readWriteNopCloser) Write(p []byte) (n int, err error) {
	return 0, fmt.Errorf("read-only embedded file")
}
func (r readWriteNopCloser) Close() error {
	if c, ok := r.Reader.(io.Closer); ok {
		return c.Close()
	}
	return nil
}

var script = `#!/bin/sh
set -x
if [ -f "./cdd.sh" ]; then
    . ./cdd.sh "$@"
elif [ -f "/cdd.sh" ]; then
    . /cdd.sh "$@"
else
    echo "Error: cdd.sh not found in current directory or root" >&2
    exit 1
fi
`

// jqMiddleware intercepts the 'jq' command and runs the internal gojqcli implementation.

func awkMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) > 0 && args[0] == "awk" {
			hc := interp.HandlerCtx(ctx)
			exitCode := goawkcli.RunAwk(args[1:], hc.Stdin, hc.Stdout, hc.Stderr)
			if exitCode == 0 {
				return nil
			}
			return interp.NewExitStatus(uint8(exitCode))
		}
		return next(ctx, args)
	}
}

func jqMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) > 0 && args[0] == "jq" {
			hc := interp.HandlerCtx(ctx)
			exitCode := gojqcli.RunJq(args[1:], hc.Stdin, hc.Stdout, hc.Stderr)
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
func resolvePath(base, p string) string {
	if filepath.IsAbs(p) {
		return p
	}
	joined := filepath.Join(base, p)
	if workaroundBase != "" && !filepath.IsAbs(joined) && !strings.HasPrefix(joined, "..") {
		return filepath.Join(workaroundBase, joined)
	}
	return joined
}

// hostCommandValidator ensures that only a specific set of bundled commands are permitted to run.
// If an unbundled command is requested, it logs an error to Stderr and returns an exit status.
func hostCommandValidator(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) == 0 {
			return next(ctx, args)
		}

		switch args[0] {
		case "awk", "jq", "mkdir", "rm", "cp", "cat", "dirname", "mv":
			return next(ctx, args)
		default:
			hc := interp.HandlerCtx(ctx)
			fmt.Fprintf(hc.Stderr, "Error: host OS command '%s' is not bundled into the WASM environment\n", args[0])
			return interp.NewExitStatus(127)
		}
	}
}

// fsMiddleware provides basic implementations for standard file system commands like mkdir, rm, cp, cat, and dirname
// so that the script can execute them natively within the WASM environment without external binaries.
func fsMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) == 0 {
			return next(ctx, args)
		}
		hc := interp.HandlerCtx(ctx)
		dir := hc.Dir

		if args[0] == "mv" {
			if len(args) != 3 {
				return interp.NewExitStatus(1)
			}
			src := resolvePath(dir, args[1])
			dst := resolvePath(dir, args[2])
			if err := os.Rename(src, dst); err != nil {
				return interp.NewExitStatus(1)
			}
			return nil
		}
		if args[0] == "cat" {
			if len(args) == 1 {
				io.Copy(hc.Stdout, hc.Stdin)
				return nil
			}
			for _, arg := range args[1:] {
				if arg == "-" {
					io.Copy(hc.Stdout, hc.Stdin)
					continue
				}
				target := resolvePath(dir, arg)
				f, err := os.Open(target)
				if err != nil {
					fmt.Fprintln(hc.Stderr, "cat:", err)
					return interp.NewExitStatus(1)
				}
				io.Copy(hc.Stdout, f)
				f.Close()
			}
			return nil
		}

		if args[0] == "dirname" {
			if len(args) < 2 {
				fmt.Fprintln(hc.Stderr, "dirname: missing operand")
				return interp.NewExitStatus(1)
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
						fmt.Fprintln(hc.Stderr, "mkdir:", err)
						return interp.NewExitStatus(1)
					}
				} else {
					if err := os.Mkdir(target, 0755); err != nil {
						fmt.Fprintln(hc.Stderr, "mkdir:", err)
						return interp.NewExitStatus(1)
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
					fmt.Fprintln(hc.Stderr, "rm:", err)
					return interp.NewExitStatus(1)
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
						fmt.Fprintln(hc.Stderr, "cp:", err)
						return interp.NewExitStatus(1)
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
						fmt.Fprintln(hc.Stderr, "cp:", err)
						return interp.NewExitStatus(1)
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
func builtinCallHandler(ctx context.Context, args []string) ([]string, error) {
	if len(args) == 0 {
		return args, nil
	}

	if args[0] == "TRIGGER_FATAL_ERROR" {
		return nil, fmt.Errorf("fatal error")
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

// osExit is a variable pointing to os.Exit to allow mocking in tests.
var osExit = os.Exit

// runMain parses the given shell script override and executes it using the mvdan.cc/sh/v3/interp runner.
// It initializes all necessary middleware handlers and captures exit statuses appropriately.
func runMain(scriptOverride string, args []string, exitFunc func(int)) {
	r := strings.NewReader(scriptOverride)
	f, err := syntax.NewParser().Parse(r, "")
	if err != nil {
		fmt.Println(err)
		return
	}

	runner, err := interp.New(
		interp.StdIO(os.Stdin, os.Stdout, os.Stderr),
		interp.Env(expand.ListEnviron(os.Environ()...)),
		interp.Params(append([]string{"--"}, args...)...),

		interp.CallHandler(builtinCallHandler),
		interp.ExecHandlers(awkMiddleware, jqMiddleware, fsMiddleware, hostCommandValidator),
		interp.StatHandler(func(ctx context.Context, name string, followSymlinks bool) (fs.FileInfo, error) {
			cleanName := filepath.Clean(name)
			cleanEmbedName := strings.TrimPrefix(cleanName, "/")
			info, err := fs.Stat(embeddedFiles, cleanEmbedName)
			if err == nil {
				return info, nil
			}
			resolvedName := resolvePath(getDir(ctx), name)
			return interp.DefaultStatHandler()(ctx, resolvedName, followSymlinks)
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
			resolvedPath := resolvePath(getDir(ctx), path)
			return interp.DefaultOpenHandler()(ctx, resolvedPath, flag, perm)
		}),
	)

	err = runner.Run(context.Background(), f)
	if err != nil {
		if status, ok := interp.IsExitStatus(err); ok {
			exitFunc(int(status))
			return
		}
		fmt.Println(err)
		exitFunc(1)
	}
}

// main reads the runtime arguments and delegates execution to runMain with the default script.
func main() {
	var args []string
	if len(os.Args) > 1 {
		args = os.Args[1:]
	}
	runMain(script, args, osExit)
}
