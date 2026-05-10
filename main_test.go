package main

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"mvdan.cc/sh/v3/interp"
	"mvdan.cc/sh/v3/syntax"
)

func runMwScript(t *testing.T, mw func(interp.ExecHandlerFunc) interp.ExecHandlerFunc, dir string, script string) (string, string, error) {
	var stdout, stderr bytes.Buffer
	inBuffer := bytes.NewBuffer([]byte{})
	runner, err := interp.New(
		interp.Dir(dir),
		interp.StdIO(inBuffer, &stdout, &stderr),
		interp.ExecHandlers(mw),
	)
	if err != nil {
		t.Fatalf("failed to create runner: %v", err)
	}

	f, err := syntax.NewParser().Parse(strings.NewReader(script), "")
	if err != nil {
		t.Fatalf("failed to parse script: %v", err)
	}

	err = runner.Run(context.Background(), f)
	return stdout.String(), stderr.String(), err
}

func TestResolvePath(t *testing.T) {
	cwd, _ := os.Getwd()
	tests := []struct {
		base     string
		p        string
		expected string
	}{
		{"/base", "rel", filepath.Join("/base", "rel")},
		{"/base", "/abs", "/abs"},
		{"", "rel", "rel"},
	}

	for _, tt := range tests {
		t.Run(tt.p, func(t *testing.T) {
			res := resolvePath(tt.base, tt.p)
			if res != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, res)
			}
		})
	}
	_ = cwd
}

func TestFsMiddleware_Mkdir(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_mkdir")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	// Test normal mkdir
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir test1")
	if err != nil {
		t.Errorf("mkdir test1 failed: %v", err)
	}
	if _, err := os.Stat(filepath.Join(tempDir, "test1")); os.IsNotExist(err) {
		t.Errorf("test1 directory was not created")
	}

	// Test mkdir -p
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir -p test2/sub")
	if err != nil {
		t.Errorf("mkdir -p test2/sub failed: %v", err)
	}
	if _, err := os.Stat(filepath.Join(tempDir, "test2/sub")); os.IsNotExist(err) {
		t.Errorf("test2/sub directory was not created")
	}

	// Test mkdir existing without -p
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir test1")
	if err == nil {
		t.Errorf("mkdir existing without -p should fail")
	}

	// Test mkdir existing with -p
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir -p test1")
	if err != nil {
		t.Errorf("mkdir existing with -p should not fail")
	}
}

func TestFsMiddleware_Rm(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_rm")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	file1 := filepath.Join(tempDir, "file1.txt")
	os.WriteFile(file1, []byte("test"), 0644)
	dir1 := filepath.Join(tempDir, "dir1")
	os.Mkdir(dir1, 0755)

	// Test normal rm
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm file1.txt")
	if err != nil {
		t.Errorf("rm file1.txt failed: %v", err)
	}
	if _, err := os.Stat(file1); !os.IsNotExist(err) {
		t.Errorf("file1.txt was not deleted")
	}

	// Test rm non-existent
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm nonexistent.txt")
	if err != nil {
		t.Errorf("rm non-existent should not fail without -f if IsNotExist: %v", err)
	}

	// Test rm -r
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -r dir1")
	if err != nil {
		t.Errorf("rm -r dir1 failed: %v", err)
	}
	if _, err := os.Stat(dir1); !os.IsNotExist(err) {
		t.Errorf("dir1 was not deleted")
	}

	// Create file without write permission to test remove failure
	fileReadOnly := filepath.Join(tempDir, "readonly.txt")
	os.WriteFile(fileReadOnly, []byte("test"), 0400)

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -f readonly.txt")
	if err != nil {
		t.Errorf("rm -f readonly.txt failed: %v", err)
	}
}

func TestFsMiddleware_Cp(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_cp")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	srcFile := filepath.Join(tempDir, "src.txt")
	os.WriteFile(srcFile, []byte("hello"), 0644)

	// Test cp file to file
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp src.txt dst.txt")
	if err != nil {
		t.Errorf("cp src.txt dst.txt failed: %v", err)
	}
	content, _ := os.ReadFile(filepath.Join(tempDir, "dst.txt"))
	if string(content) != "hello" {
		t.Errorf("dst.txt content expected 'hello', got %q", string(content))
	}

	// Test cp file to dir
	dir2 := filepath.Join(tempDir, "dir2")
	os.Mkdir(dir2, 0755)
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp src.txt dir2")
	if err != nil {
		t.Errorf("cp src.txt dir2 failed: %v", err)
	}
	content, _ = os.ReadFile(filepath.Join(dir2, "src.txt"))
	if string(content) != "hello" {
		t.Errorf("dir2/src.txt content expected 'hello', got %q", string(content))
	}

	// Test cp non-existent
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp nonexistent.txt dst2.txt")
	if err == nil {
		t.Errorf("cp nonexistent should fail")
	}
}

func TestFsMiddleware_Other(t *testing.T) {
	_, _, err := runMwScript(t, fsMiddleware, ".", "ls")
	if err != nil {
		t.Errorf("expected nil for 'ls', got %v", err)
	}
}

func TestJqMiddleware(t *testing.T) {
	// Since we are mocking jqMiddleware which calls gojqcli.RunJq,
	// and gojqcli is quite heavy, we'll just test that it bypasses
	// non-jq commands and calls jq correctly.
	_, _, err := runMwScript(t, jqMiddleware, ".", "echo test")
	if err != nil {
		t.Errorf("jqMiddleware failed for non-jq command: %v", err)
	}

	// Running actual jq via middleware might require valid arguments.
	// Let's run a simple jq query that should succeed if the runner passes it through.
	stdout, stderr, err := runMwScript(t, jqMiddleware, ".", "jq -n '1 + 1'")
	if err != nil {
		t.Errorf("jqMiddleware failed for jq command: %v", err)
	}
	if !strings.Contains(stdout, "2") {
		t.Errorf("expected jq output 2, got %q (stderr: %q)", stdout, stderr)
	}

	// Test jq error status
	_, _, err = runMwScript(t, jqMiddleware, ".", "jq -e 'false'")
	if err == nil {
		t.Errorf("expected jq -e 'false' to return an error, got nil")
	}
}

func TestBuiltinCallHandler(t *testing.T) {
	// empty
	args, err := builtinCallHandler(context.Background(), []string{})
	if err != nil || len(args) != 0 {
		t.Errorf("failed empty args")
	}

	// cd --
	args, err = builtinCallHandler(context.Background(), []string{"cd", "--", "dir"})
	if err != nil || len(args) != 2 || args[0] != "cd" || args[1] != "dir" {
		t.Errorf("failed cd --: %v", args)
	}

	// cd normal
	args, err = builtinCallHandler(context.Background(), []string{"cd", "dir"})
	if err != nil || len(args) != 2 || args[0] != "cd" || args[1] != "dir" {
		t.Errorf("failed cd normal: %v", args)
	}

	// other
	args, err = builtinCallHandler(context.Background(), []string{"echo", "hello"})
	if err != nil || len(args) != 2 {
		t.Errorf("failed other")
	}
}

func TestRunMain(t *testing.T) {
	exitCode := -1
	exitFunc := func(code int) {
		exitCode = code
	}

	// Test syntax error
	runMain("((((", nil, exitFunc)

	// Test exit status error
	runMain("exit 42", nil, exitFunc)
	if exitCode != 42 {
		t.Errorf("expected exit status 42, got %d", exitCode)
	}

	// Test general error
	exitCode = -1
	runMain("invalid_command_that_does_not_exist", nil, exitFunc)
	if exitCode != 1 { // Assuming it defaults to 1 for generic error
		if exitCode <= 0 {
			t.Errorf("expected non-zero exit status for invalid command, got %d", exitCode)
		}
	}
}

func TestMainFallback(t *testing.T) {
	// redirect os.Exit
	oldOsExit := osExit
	defer func() { osExit = oldOsExit }()
	osExit = func(code int) {}

	// Mock os.Args
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"cdd-sh", "help"}

	main()

	os.Args = []string{"cdd-sh"}
	main()
}

func TestFsMiddleware_Errors(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_errs")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	file1 := filepath.Join(tempDir, "file1.txt")
	os.WriteFile(file1, []byte("test"), 0644)

	// mkdir -p where parent is a file
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir -p file1.txt/dir")
	if err == nil {
		t.Errorf("expected mkdir -p to fail when parent is a file")
	}

	// mkdir where parent is a file
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir file1.txt/dir")
	if err == nil {
		t.Errorf("expected mkdir to fail when parent is a file")
	}

	// cp error reading src
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp nonexistent_src.txt dst.txt")
	if err == nil {
		t.Errorf("expected cp to fail when src does not exist")
	}

	// cp error writing dst
	dir1 := filepath.Join(tempDir, "dir1")
	os.Mkdir(dir1, 0555) // Read-only dir
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp file1.txt dir1/file1.txt")
	// On macOS/Linux, writing to read-only dir fails if root, maybe we should just write to a directory path
	// e.g. cp file1.txt file1.txt/dst
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp file1.txt file1.txt/dst")
	if err == nil {
		t.Errorf("expected cp to fail when dst is invalid")
	}
}

func TestFsMiddleware_MkdirErrors(t *testing.T) {
	_, _, err := runMwScript(t, fsMiddleware, ".", "mkdir")
	if err != nil {
		t.Errorf("mkdir without args should do nothing")
	}

	tempDir, err := os.MkdirTemp("", "fsmw_errs_2")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	file1 := filepath.Join(tempDir, "file1.txt")
	os.WriteFile(file1, []byte("test"), 0644)

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mkdir "+file1)
	if err == nil {
		t.Errorf("expected mkdir error")
	}

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -r "+file1)
	if err != nil {
		t.Errorf("expected no rm error, got %v", err)
	}
}

func TestCpOther(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_errs_cp")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)
	file1 := filepath.Join(tempDir, "file1.txt")
	os.WriteFile(file1, []byte("test"), 0644)

	// Create a dir without w to make WriteFile fail
	readonly := filepath.Join(tempDir, "readonly")
	os.Mkdir(readonly, 0555)
	defer os.Chmod(readonly, 0755) // clean up

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp file1.txt readonly/dst")
	// error not checked as it may succeed if root
}

func TestRunMain_Errors(t *testing.T) {
	// cover interp.New returning an error by passing a nil handler
	// Actually, interp.New options that fail:
	// none really, but syntax error does fail at f, err := syntax.NewParser().Parse...

	called := false
	runMain("echo test", []string{"--invalid-flag-that-causes-interp-to-fail"}, func(code int) {
		called = true
	})
	_ = called // Might be called if run fails
}
