package main

import (
	"bytes"
	"context"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"cdd-sh/internal/goawkcli"
	"cdd-sh/internal/gojqcli"

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

	f, err := syntax.NewParser(syntax.Variant(syntax.LangPOSIX)).Parse(strings.NewReader(script), "")
	if err != nil {
		t.Fatalf("failed to parse script: %v", err)
	}

	err = runner.Run(context.Background(), f)
	return stdout.String(), stderr.String(), err
}

func TestResolvePath(t *testing.T) {
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

	// Test rm -r non-existent without -f
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -r non_existent_dir_to_remove")
	if err != nil {
		t.Errorf("rm -r non-existent should not fail if IsNotExist: %v", err)
	}

	// Test rm with -R (capital R)
	dir2 := filepath.Join(tempDir, "dir2")
	os.Mkdir(dir2, 0755)
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -R dir2")
	if err != nil {
		t.Errorf("rm -R dir2 failed: %v", err)
	}

	// Create dir without write permission, try to delete file inside it to trigger a real remove failure
	dirReadOnly := filepath.Join(tempDir, "readonlydir")
	os.Mkdir(dirReadOnly, 0755)
	fileInReadonly := filepath.Join(dirReadOnly, "test.txt")
	os.WriteFile(fileInReadonly, []byte("test"), 0644)
	os.Chmod(dirReadOnly, 0555)
	defer os.Chmod(dirReadOnly, 0755) // cleanup

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm readonlydir/test.txt")
	// On many systems this will fail because directory is read-only. We expect an error.
	if err == nil {
		t.Errorf("rm readonlydir/test.txt should fail")
	}

	_, _, err = runMwScript(t, fsMiddleware, tempDir, "rm -f readonlydir/test.txt")
	// -f swallows the error in standard rm? Actually in our mock it checks `if err != nil && !force` so -f will swallow.
	if err != nil {
		t.Errorf("rm -f readonlydir/test.txt failed: %v", err)
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
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "cp -R src.txt dir2")
	if err != nil {
		t.Errorf("cp -R src.txt dir2 failed: %v", err)
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

func TestJqMiddleware_Direct(t *testing.T) {
	mw := jqMiddleware(func(ctx context.Context, args []string) error {
		return nil
	})

	// Test len(args) == 0
	err := mw(context.Background(), []string{})
	if err != nil {
		t.Errorf("expected no error for empty args, got %v", err)
	}
}

func TestAwkMiddleware_Direct(t *testing.T) {
	mw := awkMiddleware(func(ctx context.Context, args []string) error {
		return nil
	})

	// Test len(args) == 0
	err := mw(context.Background(), []string{})
	if err != nil {
		t.Errorf("expected no error for empty args, got %v", err)
	}
}

func TestAwkMiddleware(t *testing.T) {
	_, _, err := runMwScript(t, awkMiddleware, ".", "echo test")
	if err != nil {
		t.Errorf("awkMiddleware failed for non-awk command: %v", err)
	}

	stdout, _, err := runMwScript(t, awkMiddleware, ".", "awk 'BEGIN { print \"awk_test\" }'")
	if err != nil {
		t.Errorf("awkMiddleware failed for awk command: %v", err)
	}
	if !strings.Contains(stdout, "awk_test") {
		t.Errorf("expected awk output, got %q", stdout)
	}

	_, _, err = runMwScript(t, awkMiddleware, ".", "awk 'BEGIN { exit 1 }'")
	if err == nil {
		t.Errorf("expected awk error status, got nil")
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
	if exitCode != 1 {
		t.Errorf("expected exitCode 1 for syntax error, got %d", exitCode)
	}

	// Test successful exit
	exitCode = -1
	runMain("echo test", nil, exitFunc)
	if exitCode != -1 {
		t.Errorf("expected no exit code call for successful run, got %d", exitCode)
	}

	// Test StatHandler and OpenHandler via file existence check and sourcing
	exitCode = -1
	runMain("[ -f cdd.sh ] && . cdd.sh help", nil, exitFunc)
	if exitCode != 1 {
		t.Errorf("expected exitCode 1 when sourcing cdd.sh help, got %d", exitCode)
	}

	// Test fallback to default StatHandler and OpenHandler
	exitCode = -1
	runMain("[ -f nonexistent_file_12345 ]", nil, exitFunc)
	if exitCode != 1 {
		t.Errorf("expected exitCode 1 for nonexistent file test, got %d", exitCode)
	}

	exitCode = -1
	runMain(". nonexistent_file_12345", nil, exitFunc)
	if exitCode == -1 || exitCode == 0 {
		t.Errorf("expected non-zero exitCode when sourcing nonexistent file, got %d", exitCode)
	}

	// Test error status error
	exitCode = -1
	runMain("exit 42", nil, exitFunc)
	if exitCode != 42 {
		t.Errorf("expected exit status 42, got %d", exitCode)
	}

	// Test positional arguments forwarding into script ($1, $2)
	exitCode = -1
	runMain("[ \"$1\" = \"arg_one\" ] && [ \"$2\" = \"arg_two\" ] || exit 99", []string{"arg_one", "arg_two"}, exitFunc)
	if exitCode != -1 {
		t.Errorf("expected positional args to match without calling exitFunc, got %d", exitCode)
	}
}

func TestDevNullAndReadWriteNopCloser(t *testing.T) {
	dn := devNullReadWriter{}
	if rn, rerr := dn.Read(make([]byte, 8)); rn != 0 || rerr != io.EOF {
		t.Errorf("expected (0, io.EOF), got (%d, %v)", rn, rerr)
	}
	if wn, werr := dn.Write([]byte("abc")); wn != 3 || werr != nil {
		t.Errorf("expected (3, nil), got (%d, %v)", wn, werr)
	}
	if cerr := dn.Close(); cerr != nil {
		t.Errorf("expected nil Close error, got %v", cerr)
	}
	r := readWriteNopCloser{strings.NewReader("test")}
	_, err := r.Write([]byte("test"))
	if err == nil {
		t.Errorf("expected error on Write, got nil")
	}
	err = r.Close()
	if err != nil {
		t.Errorf("expected no error on Close, got %v", err)
	}

	// Test with a closer
	// Create a dummy closer reader wrapper to test Close
	f := struct {
		io.Reader
		io.Closer
	}{
		Reader: strings.NewReader("test"),
		Closer: io.NopCloser(strings.NewReader("test")),
	}

	r2 := readWriteNopCloser{f}
	err = r2.Close()
	if err != nil {
		t.Errorf("expected no error on Close, got %v", err)
	}
}

func TestMainFallback(t *testing.T) {
	// redirect os.Exit
	oldOsExit := osExit
	defer func() { osExit = oldOsExit }()
	var codes []int
	osExit = func(code int) {
		codes = append(codes, code)
	}

	// Mock os.Args
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"cdd-sh", "help"}

	main()
	if len(codes) != 1 || codes[0] != 1 {
		t.Errorf("expected exit code 1 for 'cdd-sh help', got %v", codes)
	}

	os.Args = []string{"cdd-sh"}
	main()
	if len(codes) != 2 || codes[1] != 1 {
		t.Errorf("expected exit code 1 for 'cdd-sh', got %v", codes)
	}
}

func TestFsMiddleware_EmptyDir(t *testing.T) {
	defer os.RemoveAll("test_empty_dir_for_cov")
	_, _, err := runMwScript(t, fsMiddleware, "", "mkdir -p test_empty_dir_for_cov")
	if err != nil {
		t.Fatalf("mkdir in empty dir failed: %v", err)
	}
	info, statErr := os.Stat("test_empty_dir_for_cov")
	if statErr != nil || !info.IsDir() {
		t.Errorf("expected test_empty_dir_for_cov directory to exist, statErr=%v", statErr)
	}
}

func TestRunMain_MoreErrors(t *testing.T) {
	exitCode := -1
	runMain("set -u; echo $UNSET_VAR_FOR_TEST_12345", nil, func(code int) { exitCode = code })
	if exitCode == -1 || exitCode == 0 {
		t.Errorf("expected non-zero exitCode for unset variable expansion under set -u, got %d", exitCode)
	}
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

	// cp error writing dst when parent is a regular file
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

func TestHostCommandValidator_Direct(t *testing.T) {
	mw := hostCommandValidator(func(ctx context.Context, args []string) error {
		return nil
	})

	// Test len(args) == 0
	err := mw(context.Background(), []string{})
	if err != nil {
		t.Errorf("expected no error for empty args, got %v", err)
	}
}

func TestHostCommandValidator(t *testing.T) {
	runner, err := interp.New(interp.ExecHandlers(hostCommandValidator))
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		script      string
		expectError bool
	}{
		{"", false},
		{"jq -n '1+1'", false},
		{"cat -", false},
		{"dirname /a/b/c", false},
		{"mkdir -p /tmp/test_host_cmd", false},
		{"awk '{print $1}'", false},
		{"curl http://example.com", true},
		{"sed 's/a/b/'", true},
	}

	for _, tt := range tests {
		t.Run(tt.script, func(t *testing.T) {
			f, err := syntax.NewParser().Parse(strings.NewReader(tt.script), "")
			if err != nil {
				t.Fatalf("failed to parse script %q: %v", tt.script, err)
			}
			err = runner.Run(context.Background(), f)
			if tt.expectError && err == nil {
				t.Errorf("expected error for script %q, got nil", tt.script)
			} else if !tt.expectError && err != nil {
				t.Errorf("expected no error for script %q, got %v", tt.script, err)
			}
		})
	}
}

func TestFsMiddleware_Direct(t *testing.T) {
	mw := fsMiddleware(func(ctx context.Context, args []string) error {
		return nil
	})

	// Test len(args) == 0
	err := mw(context.Background(), []string{})
	if err != nil {
		t.Errorf("expected no error for empty args, got %v", err)
	}
}

func TestFsMiddleware_Cat(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "fsmw_cat")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	file1 := filepath.Join(tempDir, "file1.txt")
	os.WriteFile(file1, []byte("hello"), 0644)
	file2 := filepath.Join(tempDir, "file2.txt")
	os.WriteFile(file2, []byte(" world"), 0644)

	// Test cat multiple files
	stdout, _, err := runMwScript(t, fsMiddleware, tempDir, "cat file1.txt file2.txt")
	if err != nil {
		t.Errorf("cat file1.txt file2.txt failed: %v", err)
	}
	if stdout != "hello world" {
		t.Errorf("expected 'hello world', got %q", stdout)
	}

	// Test cat with stdin explicitly via '-'
	stdout, _, err = runMwScript(t, fsMiddleware, tempDir, "echo 'test stdin -' | cat -")
	if err != nil {
		t.Errorf("cat - failed: %v", err)
	}
	if !strings.Contains(stdout, "test stdin -") {
		t.Errorf("expected stdout to contain 'test stdin -', got %q", stdout)
	}

	// Test cat with no args (reads stdin)
	stdout, _, err = runMwScript(t, fsMiddleware, tempDir, "echo 'test stdin noargs' | cat")
	if err != nil {
		t.Errorf("cat no args failed: %v", err)
	}
	if !strings.Contains(stdout, "test stdin noargs") {
		t.Errorf("expected stdout to contain 'test stdin noargs', got %q", stdout)
	}

	// Test cat missing file
	_, stderr, err := runMwScript(t, fsMiddleware, tempDir, "cat missing.txt")
	if err == nil {
		t.Errorf("expected error for missing file")
	}
	if !strings.Contains(stderr, "cat:") {
		t.Errorf("expected stderr to contain 'cat:', got %q", stderr)
	}

	// Test cat directory (triggers io.Copy read error on opened fd)
	subDir := filepath.Join(tempDir, "subdir")
	if err := os.MkdirAll(subDir, 0755); err != nil {
		t.Fatal(err)
	}
	_, stderr, err = runMwScript(t, fsMiddleware, tempDir, "cat subdir")
	if err == nil {
		t.Errorf("expected error when calling cat on a directory")
	}
	if !strings.Contains(stderr, "cat:") {
		t.Errorf("expected stderr to contain 'cat:', got %q", stderr)
	}
}

func TestFsMiddleware_Dirname(t *testing.T) {
	tests := []struct {
		script   string
		expected string
	}{
		{"dirname /a/b/c", "/a/b\n"},
		{"dirname a/b", "a\n"},
		{"dirname /", "/\n"},
		{"dirname \"\"", ".\n"},
	}

	for _, tt := range tests {
		t.Run(tt.script, func(t *testing.T) {
			stdout, _, err := runMwScript(t, fsMiddleware, ".", tt.script)
			if err != nil {
				t.Errorf("script %q failed: %v", tt.script, err)
			}
			if stdout != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, stdout)
			}
		})
	}

	// Test missing operand
	_, stderr, err := runMwScript(t, fsMiddleware, ".", "dirname")
	if err == nil {
		t.Errorf("expected error for missing operand")
	}
	if !strings.Contains(stderr, "dirname: missing operand") {
		t.Errorf("expected stderr to contain 'dirname: missing operand', got %q", stderr)
	}
}

func TestFsMiddleware_BasenameAndMktemp(t *testing.T) {
	tempDir := t.TempDir()

	// basename tests
	out, _, err := runMwScript(t, fsMiddleware, tempDir, "basename /a/b/c.sh .sh")
	if err != nil || strings.TrimSpace(out) != "c" {
		t.Errorf("expected 'c', got %q (err=%v)", out, err)
	}
	out, _, err = runMwScript(t, fsMiddleware, tempDir, "basename \"\"")
	if err != nil || strings.TrimSpace(out) != "." {
		t.Errorf("expected '.', got %q (err=%v)", out, err)
	}
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "basename"); err == nil {
		t.Errorf("expected error for basename missing operand")
	}

	// mktemp file and dir tests
	out, _, err = runMwScript(t, fsMiddleware, tempDir, "mktemp")
	if err != nil {
		t.Fatalf("mktemp failed: %v", err)
	}
	createdFile := strings.TrimSpace(out)
	defer os.Remove(createdFile)
	if info, statErr := os.Stat(createdFile); statErr != nil || info.IsDir() {
		t.Errorf("expected mktemp file to exist, statErr=%v", statErr)
	}

	out, _, err = runMwScript(t, fsMiddleware, tempDir, "mktemp -d cdd_test.XXXXXX")
	if err != nil {
		t.Fatalf("mktemp -d failed: %v", err)
	}
	createdDir := strings.TrimSpace(out)
	defer os.RemoveAll(createdDir)
	if info, statErr := os.Stat(createdDir); statErr != nil || !info.IsDir() {
		t.Errorf("expected mktemp -d directory to exist, statErr=%v", statErr)
	}

	// mktemp failure when parent directory does not exist
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "mktemp nonexistent_parent_xyz/tmp.XXXXXX"); err == nil {
		t.Errorf("expected mktemp file in nonexistent parent to fail")
	}
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "mktemp -d nonexistent_parent_xyz/tmp.XXXXXX"); err == nil {
		t.Errorf("expected mktemp -d in nonexistent parent to fail")
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

	// Copying a file onto a path whose parent is a regular file deterministically fails WriteFile on all platforms.
	_, stderr, err := runMwScript(t, fsMiddleware, tempDir, "cp file1.txt file1.txt/dst")
	if err == nil {
		t.Errorf("expected error when copying to invalid destination path, got nil")
	}
	if !strings.Contains(stderr, "cp:") {
		t.Errorf("expected stderr to contain 'cp:', got %q", stderr)
	}
}

func TestRunMain_Errors(t *testing.T) {
	called := false
	exitCode := -1
	runMain("unknown_command_xyz_123", nil, func(code int) {
		called = true
		exitCode = code
	})
	if !called || exitCode != 127 {
		t.Errorf("expected exitFunc(127) to be called for unknown command, got called=%v, code=%d", called, exitCode)
	}
}

func TestMvCoverage(t *testing.T) {
	tempDir, _ := os.MkdirTemp("", "mv_test")
	defer os.RemoveAll(tempDir)
	src := tempDir + "/src.txt"
	os.WriteFile(src, []byte("test"), 0644)

	// mv success
	_, _, err := runMwScript(t, fsMiddleware, tempDir, "mv "+src+" "+tempDir+"/dst.txt")
	if err != nil {
		t.Error("expected nil")
	}

	// mv fail count
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mv a")
	if err == nil {
		t.Error("expected err")
	}

	// mv fail rename
	_, _, err = runMwScript(t, fsMiddleware, tempDir, "mv non_existent_src dst")
	if err == nil {
		t.Error("expected err")
	}
}

func TestRunMain_Embedded(t *testing.T) {
	called := false
	runMain("[ -f cdd.sh ] && exit 42", nil, func(c int) {
		if c == 42 {
			called = true
		}
	})
	if !called {
		t.Error("expected embedded cdd.sh to be found and stat to succeed")
	}
}

func TestRunMain_EmbeddedStat(t *testing.T) {
	called := false
	runMain("if [ -f /cdd.sh ]; then exit 42; fi", nil, func(c int) {
		if c == 42 {
			called = true
		}
	})
	if !called {
		t.Error("expected /cdd.sh to be found in embedded files")
	}
}

func TestRunMain_BadRedirect(t *testing.T) {
	called := false
	runMain("echo hello > /", nil, func(c int) { called = true })
	if !called {
		t.Error("expected exitFunc to be called for bad redirect")
	}
}
func TestRunMain_FatalError(t *testing.T) {
	oldCallHandler := activeCallHandler
	defer func() { activeCallHandler = oldCallHandler }()
	activeCallHandler = func(ctx context.Context, args []string) ([]string, error) {
		_ = ctx
		_ = args
		return nil, os.ErrInvalid
	}

	called := false
	runMain("echo test", nil, func(c int) {
		if c == 1 {
			called = true
		}
	})
	if !called {
		t.Error("expected exitFunc(1) to be called for fatal error")
	}
}

type errWriter struct{}

func (errWriter) Write(_ []byte) (int, error) {
	return 0, os.ErrInvalid
}

func TestRunMain_NewRunnerError(t *testing.T) {
	oldNewRunner := newRunner
	defer func() { newRunner = oldNewRunner }()
	newRunner = func(_ ...interp.RunnerOption) (*interp.Runner, error) {
		return nil, os.ErrInvalid
	}

	exitCode := -1
	runMain("echo test", nil, func(c int) { exitCode = c })
	if exitCode != 1 {
		t.Errorf("expected exitCode 1 when newRunner fails, got %d", exitCode)
	}
}

func TestFsMiddleware_CatStdinError(t *testing.T) {
	var stderr bytes.Buffer
	runner, err := interp.New(
		interp.StdIO(strings.NewReader("hello"), errWriter{}, &stderr),
		interp.ExecHandlers(fsMiddleware),
	)
	if err != nil {
		t.Fatal(err)
	}

	f1, _ := syntax.NewParser().Parse(strings.NewReader("cat"), "")
	if err := runner.Run(context.Background(), f1); err == nil {
		t.Errorf("expected cat with failing stdout to fail")
	}

	runner2, _ := interp.New(
		interp.StdIO(strings.NewReader("hello"), errWriter{}, &stderr),
		interp.ExecHandlers(fsMiddleware),
	)
	f2, _ := syntax.NewParser().Parse(strings.NewReader("cat -"), "")
	if err := runner2.Run(context.Background(), f2); err == nil {
		t.Errorf("expected cat - with failing stdout to fail")
	}
}

func TestInitResolvePath(t *testing.T) {
	// These were set in init()
	if goawkcli.ResolvePath == nil {
		t.Error("goawkcli.ResolvePath is nil")
	} else {
		res := goawkcli.ResolvePath("test")
		if res != "test" { // resolvePath(".", "test") == "test"
			t.Errorf("goawkcli.ResolvePath returned %q", res)
		}
	}

	if gojqcli.ResolvePath == nil {
		t.Error("gojqcli.ResolvePath is nil")
	} else {
		res := gojqcli.ResolvePath("test")
		if res != "test" { // resolvePath(".", "test") == "test"
			t.Errorf("gojqcli.ResolvePath returned %q", res)
		}
	}
}

func TestConcurrentMiddlewares(t *testing.T) {
	t.Run("awk_1", func(t *testing.T) {
		t.Parallel()
		out, _, err := runMwScript(t, awkMiddleware, ".", "awk 'BEGIN { print \"p1\" }'")
		if err != nil || strings.TrimSpace(out) != "p1" {
			t.Errorf("expected 'p1', got %q (%v)", out, err)
		}
	})
	t.Run("awk_2", func(t *testing.T) {
		t.Parallel()
		out, _, err := runMwScript(t, awkMiddleware, ".", "awk 'BEGIN { print \"p2\" }'")
		if err != nil || strings.TrimSpace(out) != "p2" {
			t.Errorf("expected 'p2', got %q (%v)", out, err)
		}
	})
	t.Run("jq_1", func(t *testing.T) {
		t.Parallel()
		out, _, err := runMwScript(t, jqMiddleware, ".", "jq -C -n '{\"a\": 1}'")
		if err != nil || !strings.Contains(out, "1") {
			t.Errorf("expected jq output with 1, got %q (%v)", out, err)
		}
	})
	t.Run("jq_2", func(t *testing.T) {
		t.Parallel()
		out, _, err := runMwScript(t, jqMiddleware, ".", "jq -M -n '{\"b\": 2}'")
		if err != nil || !strings.Contains(out, "\"b\": 2") {
			t.Errorf("expected monochrome jq output, got %q (%v)", out, err)
		}
	})
}

func TestResolvePathWorkaround(t *testing.T) {
	oldWorkaround := workaroundBase
	defer func() { workaroundBase = oldWorkaround }()

	workaroundBase = "/workaround"

	// Test with relative path that triggers workaround
	res := resolvePath(".", "rel")
	if res != filepath.Join("/workaround", "rel") {
		t.Errorf("expected %q, got %q", filepath.Join("/workaround", "rel"), res)
	}

	// Test with path that starts with ..
	res = resolvePath(".", "../rel")
	if res != "/workaround/../rel" {
		t.Errorf("expected '/workaround/../rel', got %q", res)
	}

	// Test with absolute path joined
	res = resolvePath("/base", "rel") // Wait, joined is /base/rel, IsAbs is true. Workaround is skipped.
	if res != "/base/rel" {
		t.Errorf("expected '/base/rel', got %q", res)
	}
}

func TestGoAwkCliResolvePath(t *testing.T) {
	tempDir := t.TempDir()
	scriptPath := filepath.Join(tempDir, "test.awk")
	if err := os.WriteFile(scriptPath, []byte("BEGIN { print \"resolved_ok\" }\n"), 0644); err != nil {
		t.Fatal(err)
	}

	stdout, stderr, err := runMwScript(t, awkMiddleware, tempDir, "awk -f test.awk")
	if err != nil {
		t.Fatalf("awkMiddleware failed to resolve relative script in dir: %v (stderr: %s)", err, stderr)
	}
	if strings.TrimSpace(stdout) != "resolved_ok" {
		t.Errorf("expected 'resolved_ok', got %q", stdout)
	}

	jsonPath := filepath.Join(tempDir, "data.json")
	if err := os.WriteFile(jsonPath, []byte("{\"val\":42}"), 0644); err != nil {
		t.Fatal(err)
	}
	jqOut, jqErr, err := runMwScript(t, jqMiddleware, tempDir, "jq -r '.val' data.json")
	if err != nil {
		t.Fatalf("jqMiddleware failed to resolve relative file in dir: %v (stderr: %s)", err, jqErr)
	}
	if strings.TrimSpace(jqOut) != "42" {
		t.Errorf("expected '42', got %q", jqOut)
	}
}

func TestFsMiddleware_ChmodAndTouch(t *testing.T) {
	tempDir := t.TempDir()

	// touch missing operand
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "touch"); err == nil {
		t.Errorf("expected touch without args to fail")
	}

	// touch success
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "touch touched.txt"); err != nil {
		t.Fatalf("touch failed: %v", err)
	}
	if _, err := os.Stat(filepath.Join(tempDir, "touched.txt")); err != nil {
		t.Errorf("expected touched.txt to exist: %v", err)
	}

	// touch invalid path (parent is file)
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "touch touched.txt/sub"); err == nil {
		t.Errorf("expected touch on invalid path to fail")
	}

	// chmod missing operand
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "chmod +x"); err == nil {
		t.Errorf("expected chmod with < 3 args to fail")
	}

	// chmod invalid mode
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "chmod invalid_mode touched.txt"); err == nil {
		t.Errorf("expected chmod with invalid mode to fail")
	}

	// chmod missing target file
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "chmod 0755 nonexistent_target.txt"); err == nil {
		t.Errorf("expected chmod on nonexistent file to fail")
	}

	// chmod octal and -w modes
	if _, _, err := runMwScript(t, fsMiddleware, tempDir, "chmod -w touched.txt && chmod 0644 touched.txt"); err != nil {
		t.Fatalf("chmod -w and 0644 failed: %v", err)
	}

	// chmod success via hostCommandValidator + fsMiddleware
	if _, _, err := runMwScript(t, func(next interp.ExecHandlerFunc) interp.ExecHandlerFunc {
		return fsMiddleware(hostCommandValidator(next))
	}, tempDir, "chmod +x touched.txt && touch touched.txt"); err != nil {
		t.Fatalf("chmod/touch failed: %v", err)
	}
}

func TestRunMain_ArazzoRoundTrip(t *testing.T) {
	tempDir := t.TempDir()
	sdkOut := filepath.Join(tempDir, "sdk_out")
	roundtripOut := filepath.Join(tempDir, "roundtrip.arazzo.json")
	astPath := filepath.Join(tempDir, "ast.json")
	t.Setenv("CDD_AST_PATH", astPath)

	var exitCode int
	exitFn := func(c int) { exitCode = c }

	runMain(script, []string{"from_arazzo", "to_sdk", "-i", "tests/test_arazzo.json", "-o", sdkOut, "--no-github-actions"}, exitFn)
	if exitCode != 0 {
		t.Fatalf("expected exitCode 0 for from_arazzo to_sdk, got %d", exitCode)
	}
	if _, err := os.Stat(filepath.Join(sdkOut, "src", "workflows.sh")); err != nil {
		t.Fatalf("expected generated workflows.sh to exist: %v", err)
	}

	runMain(script, []string{"to_arazzo", "-i", filepath.Join(sdkOut, "src", "workflows.sh"), "-o", roundtripOut}, exitFn)
	if exitCode != 0 {
		t.Fatalf("expected exitCode 0 for to_arazzo, got %d", exitCode)
	}
	data, err := os.ReadFile(roundtripOut)
	if err != nil {
		t.Fatalf("failed to read roundtrip.arazzo.json: %v", err)
	}
	if !strings.Contains(string(data), "\"orderCheckoutFlow\"") {
		t.Errorf("expected roundtrip.arazzo.json to contain orderCheckoutFlow, got %s", string(data))
	}
}

func TestPOSIXShellSyntaxAudit(t *testing.T) {
	parser := syntax.NewParser(syntax.Variant(syntax.LangPOSIX))
	dirs := []string{"cdd.sh", "test.sh", "run_in_dash.sh", "setup_boiler.sh", "update_shields.sh", "lib", "src", "tests"}
	for _, root := range dirs {
		err := filepath.Walk(root, func(path string, info os.FileInfo, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if info.IsDir() || !strings.HasSuffix(path, ".sh") {
				return nil
			}
			content, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			if _, err := parser.Parse(bytes.NewReader(content), path); err != nil {
				t.Errorf("POSIX /bin/sh syntax error in %s: %v", path, err)
			}
			return nil
		})
		if err != nil {
			t.Fatalf("failed walking %s: %v", root, err)
		}
	}
}
