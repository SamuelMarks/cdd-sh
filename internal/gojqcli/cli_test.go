package gojqcli

import (
	"bytes"
	"os"
	"strings"
	"testing"
)

func runCli(args []string, stdin string) (int, string, string) {
	var stdout, stderr bytes.Buffer
	inBuf := strings.NewReader(stdin)
	exitCode := RunJq(args, inBuf, &stdout, &stderr)
	return exitCode, stdout.String(), stderr.String()
}

func TestRunFunc(t *testing.T) {
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"gojq", "-n", "1"}

	// Mock Stdin
	oldStdin := os.Stdin
	defer func() { os.Stdin = oldStdin }()
	r, w, _ := os.Pipe()
	w.Close()
	os.Stdin = r

	// Mock Stdout and Stderr to discard
	oldStdout := os.Stdout
	defer func() { os.Stdout = oldStdout }()
	devNull, _ := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	os.Stdout = devNull

	oldStderr := os.Stderr
	defer func() { os.Stderr = oldStderr }()
	os.Stderr = devNull

	code := Run()
	if code != 0 {
		t.Errorf("Run() failed with code %d", code)
	}
}

func TestRunJqFiles(t *testing.T) {
	// Test reading from file
	tests := []struct {
		name        string
		args        []string
		fileContent string
		wantCode    int
		wantOut     string
	}{
		{"read file", []string{".", "test.json"}, `{"a": 1}`, 0, "{\n  \"a\": 1\n}\n"},
		{"slurp file", []string{"-s", ".", "test.json"}, `{"a": 1}`, 0, "[\n  {\n    \"a\": 1\n  }\n]\n"},
		{"slurp raw file", []string{"-sR", ".", "test.json"}, `hello`, 0, "\"hello\"\n"},
		{"yaml file", []string{"--yaml-input", ".", "test.yaml"}, `a: 1`, 0, "{\n  \"a\": 1\n}\n"},
		{"stream file", []string{"-c", "--stream", ".", "test.json"}, `[1, 2]`, 0, "[[0],1]\n[[1],2]\n"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if strings.Contains(tt.args[len(tt.args)-1], "test.") {
				fName := tt.args[len(tt.args)-1]
				os.WriteFile(fName, []byte(tt.fileContent), 0644)
				defer os.Remove(fName)
			}
			code, out, _ := runCli(tt.args, "")
			if code != tt.wantCode {
				t.Errorf("expected exit code %d, got %d", tt.wantCode, code)
			}
			if tt.wantOut != "" && !strings.Contains(out, tt.wantOut) {
				t.Errorf("expected out %q, got %q", tt.wantOut, out)
			}
		})
	}
}
func TestRunJqFlags(t *testing.T) {
	tests := []struct {
		name     string
		args     []string
		wantCode int
	}{
		{"-c", []string{"-c", "-n", "1"}, 0},
		{"-r", []string{"-r", "-n", "1"}, 0},
		{"-R", []string{"-R", "-n", "1"}, 0},
		{"-s", []string{"-s", "-n", "1"}, 0},
		{"-e", []string{"-e", "-n", "1"}, 0},
		{"--stream", []string{"--stream", "-n", "1"}, 0},
		{"--yaml-input", []string{"--yaml-input", "-n", "1"}, 0},
		{"--yaml-output", []string{"--yaml-output", "-n", "1"}, 0},
		{"--indent", []string{"--indent", "4", "-n", "1"}, 0},
		{"--indent invalid", []string{"--indent", "invalid", "-n", "1"}, 2},
		{"--tab", []string{"--tab", "-n", "1"}, 0},
		{"--arg", []string{"--arg", "a", "1", "-n", "1"}, 0},
		{"--arg missing", []string{"--arg", "a"}, 2},
		{"--argjson", []string{"--argjson", "a", "1", "-n", "1"}, 0},
		{"--slurpfile", []string{"--slurpfile", "a", "test.json", "-n", "1"}, 0},
		{"--slurpfile error", []string{"--slurpfile", "a", "missing.json", "-n", "1"}, 5},
		{"--rawfile", []string{"--rawfile", "a", "test.json", "-n", "1"}, 0},
		{"--rawfile error", []string{"--rawfile", "a", "missing.json", "-n", "1"}, 5},
		{"--color-output", []string{"--color-output", "-n", "1"}, 0},
		{"--monochrome-output", []string{"--monochrome-output", "-n", "1"}, 0},
		{"--L", []string{"-L", ".", "-n", "1"}, 0},
	}

	os.WriteFile("test.json", []byte(`{"a":1}`), 0644)
	defer os.Remove("test.json")

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			code, _, _ := runCli(tt.args, "")
			if code != tt.wantCode {
				t.Errorf("expected exit code %d, got %d", tt.wantCode, code)
			}
		})
	}
}
func TestRunJqBasic(t *testing.T) {
	tests := []struct {
		name     string
		args     []string
		stdin    string
		wantCode int
		wantOut  string
		wantErr  string
	}{
		{"basic math", []string{"-n", "1+1"}, "", 0, "2\n", ""},
		{"null input", []string{"-n", "."}, "", 0, "null\n", ""},
		{"read json", []string{"."}, `{"a": 1}`, 0, "{\n  \"a\": 1\n}\n", ""},
		{"syntax error", []string{"-n", "{"}, "", 3, "", "unexpected EOF"},
		{"compile error", []string{"-n", "1 + "}, "", 3, "", "unexpected EOF"},
		{"runtime error", []string{"-n", "1 + \"a\""}, "", 5, "", "cannot add: number (1) and string (\"a\")"},
		{"flag error", []string{"--invalid-flag"}, "", 2, "", "unknown flag `--invalid-flag'"},
		{"exit status zero", []string{"-e", "-n", "true"}, "", 0, "true\n", ""},
		{"exit status non-zero", []string{"-e", "-n", "false"}, "", 1, "false\n", ""},
		{"raw output", []string{"-r", "-n", "\"hello\""}, "", 0, "hello\n", ""},
		{"compact output", []string{"-c", "-n", "[1,2,3]"}, "", 0, "[1,2,3]\n", ""},
		{"yaml output", []string{"--yaml-output", "-n", `{"a": 1}`}, "", 0, "a: 1\n", ""},
		{"raw input", []string{"-R", "."}, "hello\nworld", 0, "\"hello\"\n\"world\"\n", ""},
		{"slurp input", []string{"-s", "."}, "1\n2\n", 0, "[\n  1,\n  2\n]\n", ""},
		{"slurp raw input", []string{"-sR", "."}, "hello\nworld\n", 0, "\"hello\\nworld\\n\"\n", ""},
		{"arg test", []string{"-n", "--arg", "x", "hello", "$x"}, "", 0, "\"hello\"\n", ""},
		{"argjson test", []string{"-n", "--argjson", "x", "1", "$x"}, "", 0, "1\n", ""},
		{"help", []string{"-h"}, "", 0, "Usage:", ""},
		{"version", []string{"-v"}, "", 0, "gojq", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			code, out, errOut := runCli(tt.args, tt.stdin)
			if code != tt.wantCode {
				t.Errorf("expected exit code %d, got %d (errOut: %s)", tt.wantCode, code, errOut)
			}
			if tt.wantOut != "" && !strings.Contains(out, tt.wantOut) {
				t.Errorf("expected out %q, got %q", tt.wantOut, out)
			}
			if tt.wantErr != "" && !strings.Contains(errOut, tt.wantErr) {
				t.Errorf("expected errOut %q, got %q", tt.wantErr, errOut)
			}
		})
	}
}

func TestRunJqMoreBranches(t *testing.T) {
	// NO_COLOR
	os.Setenv("NO_COLOR", "1")
	runCli([]string{"-n", "1"}, "")
	os.Unsetenv("NO_COLOR")

	// TERM=dumb
	os.Setenv("TERM", "dumb")
	runCli([]string{"-n", "1"}, "")
	os.Unsetenv("TERM")

	// GOJQ_COLORS
	os.Setenv("GOJQ_COLORS", "31;32;33;34;35;36;37")
	runCli([]string{"-n", "1"}, "")
	os.Setenv("GOJQ_COLORS", "invalid")
	runCli([]string{"-n", "1"}, "")
	os.Unsetenv("GOJQ_COLORS")

	// indent > 9 and < 0
	runCli([]string{"--indent", "10", "-n", "1"}, "")
	runCli([]string{"--indent", "-1", "-n", "1"}, "")

	// yaml output with tab
	runCli([]string{"--yaml-output", "--tab", "-n", "1"}, "")

	// invalid json in argjson
	runCli([]string{"--argjson", "x", "{", "-n", "1"}, "")

	// jsonargs
	runCli([]string{"--jsonargs", "-n", "$ARGS.positional", "1", "2"}, "")
	runCli([]string{"--jsonargs", "-n", "$ARGS.positional", "{"}, "")

	// FromFile with missing file
	runCli([]string{"-f"}, "")
	runCli([]string{"-f", "missing_file_abc.jq"}, "")

	// HaltError
	runCli([]string{"-n", "halt"}, "")
	runCli([]string{"-n", "halt_error"}, "")
	runCli([]string{"-n", `"hello" | halt_error`}, "")

	// debug and stderr
	runCli([]string{"-n", "debug"}, "")
	runCli([]string{"-n", "stderr"}, "")

	// input_filename
	runCli([]string{"-n", "input_filename"}, "")
	runCli([]string{"input_filename"}, "1")

	// Print value error handling
	runCli([]string{"-n", "--yaml-output", "debug"}, "")
}

func TestRunJqEvenMoreBranches(t *testing.T) {
	// GOJQ_COLORS with -C
	os.Setenv("GOJQ_COLORS", "31;32;33;34;35;36;37")
	runCli([]string{"-C", "-n", "1"}, "")
	os.Setenv("GOJQ_COLORS", "invalid")
	runCli([]string{"-C", "-n", "1"}, "")
	os.Unsetenv("GOJQ_COLORS")

	// iter.Next() error
	runCli([]string{"."}, "{")

	// HaltError with non-string
	runCli([]string{"-n", "1 | halt_error"}, "")

	// YAML separator
	runCli([]string{"--yaml-output", "-n", "1, 2"}, "")

	// Exit code error with multiple values
	runCli([]string{"-e", "-n", "1, false"}, "")
	runCli([]string{"-e", "-n", "false, 1"}, "")
}

type errorWriter struct{}

func (w *errorWriter) Write(p []byte) (n int, err error) {
	return 0, os.ErrClosed
}

func TestRunJqErrorWriter(t *testing.T) {
	cli := &cli{
		inStream:  strings.NewReader(""),
		outStream: &errorWriter{},
		errStream: &errorWriter{},
	}
	// trigger error in printValues -> marshal
	cli.outputYAML = true
	cli.run([]string{"-n", "1"})

	// trigger error in funcDebug
	cli.run([]string{"-n", "debug"})

	// trigger error in funcStderr
	cli.run([]string{"-n", "stderr"})
}

func TestRunJqMoreCliBranches(t *testing.T) {
	// exitCodeError override
	runCli([]string{"-e", "-f", "missing.jq"}, "")

	// raw-output0
	runCli([]string{"--raw-output0", "-n", "1"}, "")

	// jsonargs with missing positional
	// wait, runCli with jsonargs?
	runCli([]string{"--jsonargs", "-n", "1"}, "")
}

func TestFuncDebug(t *testing.T) {
	c := &cli{outStream: os.Stdout, errStream: os.Stderr}
	c.funcDebug("test", nil)
}

func TestFuncStderr(t *testing.T) {
	c := &cli{outStream: os.Stdout, errStream: os.Stderr}
	c.funcStderr("test", nil)
}

func TestFuncDebugError(t *testing.T) {
	c := &cli{errStream: &errWriter{}}
	c.funcDebug("test", nil)
	c.funcStderr("test", nil)
}
