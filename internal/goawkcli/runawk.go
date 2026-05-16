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

// RunAwk executes goawk with the given arguments and standard streams.
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
				fmt.Fprintln(stderr, "awk: option requires an argument -- F")
				return 1
			}
		} else if arg == "-v" {
			if i+1 < len(args) {
				vars = append(vars, args[i+1])
				i += 2
			} else {
				fmt.Fprintln(stderr, "awk: option requires an argument -- v")
				return 1
			}
		} else if arg == "-f" {
			if i+1 < len(args) {
				progFiles = append(progFiles, args[i+1])
				i += 2
			} else {
				fmt.Fprintln(stderr, "awk: option requires an argument -- f")
				return 1
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
			fmt.Fprintln(stderr, "awk: missing program")
			return 1
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
			b, err = os.ReadFile(f)
		}

		if err != nil {
			fmt.Fprintf(stderr, "awk: cannot open %s (%s)\n", f, err)
			return 1
		}
		progBuf.Write(b)
		progBuf.WriteByte('\n')
	}
	if len(progFiles) > 0 {
		prog = progBuf.String()
	}

	p, err := parser.ParseProgram([]byte(prog), nil)
	if err != nil {
		fmt.Fprintf(stderr, "awk: syntax error: %s\n", err)
		return 1
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
		fmt.Fprintf(stderr, "awk: %s\n", err)
		return 1
	}
	return status
}
