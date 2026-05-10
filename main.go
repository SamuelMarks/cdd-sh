package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"cdd-sh/internal/gojqcli"

	"mvdan.cc/sh/v3/interp"
	"mvdan.cc/sh/v3/syntax"
)

var script = `#!/bin/sh
if [ -f "./cdd.sh" ]; then
    . ./cdd.sh "$@"
elif [ -f "/cdd.sh" ]; then
    . /cdd.sh "$@"
else
    echo "Error: cdd.sh not found in current directory or root"
    exit 1
fi
`

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

func resolvePath(base, p string) string {
	if filepath.IsAbs(p) {
		return p
	}
	return filepath.Join(base, p)
}

func fsMiddleware(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
	return func(ctx context.Context, args []string) error {
		if len(args) == 0 {
			return next(ctx, args)
		}
		hc := interp.HandlerCtx(ctx)
		dir := hc.Dir
		if dir == "" {
			dir, _ = os.Getwd()
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

func builtinCallHandler(ctx context.Context, args []string) ([]string, error) {
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

var osExit = os.Exit

func runMain(scriptOverride string, args []string, exitFunc func(int)) {
	r := strings.NewReader(scriptOverride)
	f, err := syntax.NewParser().Parse(r, "")
	if err != nil {
		fmt.Println(err)
		return
	}

	runner, err := interp.New(
		interp.StdIO(os.Stdin, os.Stdout, os.Stderr),
		interp.Params(args...),
		interp.CallHandler(builtinCallHandler),
		interp.ExecHandlers(jqMiddleware, fsMiddleware),
	)
	if err != nil {
		fmt.Println(err)
		return
	}

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

func main() {
	var args []string
	if len(os.Args) > 1 {
		args = os.Args[1:]
	}
	runMain(script, args, osExit)
}
