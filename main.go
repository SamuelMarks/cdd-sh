package main

import (
	"context"
	"fmt"
	"os"
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

func main() {
	r := strings.NewReader(script)
	f, err := syntax.NewParser().Parse(r, "")
	if err != nil {
		fmt.Println(err)
		return
	}

	args := []string{}
	if len(os.Args) > 1 {
		args = os.Args[1:]
	}

	runner, err := interp.New(
		interp.StdIO(os.Stdin, os.Stdout, os.Stderr),
		interp.Params(args...),
		interp.ExecHandlers(jqMiddleware),
	)
	if err != nil {
		fmt.Println(err)
		return
	}

	err = runner.Run(context.Background(), f)
	if err != nil {
		if status, ok := interp.IsExitStatus(err); ok {
			os.Exit(int(status))
		}
		fmt.Println(err)
		os.Exit(1)
	}
}
