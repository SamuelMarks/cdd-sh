package goawkcli

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"
)

func TestRunAwk(t *testing.T) {
	// Create some temp files
	tmpDir := t.TempDir()
	progFile := filepath.Join(tmpDir, "test.awk")
	os.WriteFile(progFile, []byte("BEGIN { print \"hello\" }"), 0644)
	inputFile := filepath.Join(tmpDir, "input.txt")
	os.WriteFile(inputFile, []byte("a,b,c\n1,2,3"), 0644)

	tests := []struct {
		name       string
		args       []string
		stdinStr   string
		expected   int
		outContain string
		errContain string
	}{
		{
			name:       "simple print",
			args:       []string{"BEGIN { print \"test\" }"},
			expected:   0,
			outContain: "test\n",
		},
		{
			name:       "missing program",
			args:       []string{},
			expected:   1,
			errContain: "missing program",
		},
		{
			name:       "syntax error",
			args:       []string{"{"},
			expected:   1,
			errContain: "syntax error",
		},
		{
			name:       "with -F",
			args:       []string{"-F", ",", "{print $2}"},
			stdinStr:   "a,b,c",
			expected:   0,
			outContain: "b\n",
		},
		{
			name:       "missing -F arg",
			args:       []string{"-F"},
			expected:   1,
			errContain: "awk: option requires an argument -- F",
		},
		{
			name:       "with -v",
			args:       []string{"-v", "VAR=val", "BEGIN {print VAR}"},
			expected:   0,
			outContain: "val\n",
		},
		{
			name:       "missing -v arg",
			args:       []string{"-v"},
			expected:   1,
			errContain: "awk: option requires an argument -- v",
		},
		{
			name:       "with -f",
			args:       []string{"-f", progFile},
			expected:   0,
			outContain: "hello\n",
		},
		{
			name:       "missing -f arg",
			args:       []string{"-f"},
			expected:   1,
			errContain: "awk: option requires an argument -- f",
		},
		{
			name:       "invalid -f file",
			args:       []string{"-f", filepath.Join(tmpDir, "nonexistent.awk")},
			expected:   1,
			errContain: "cannot open",
		},
		{
			name:       "input files",
			args:       []string{"-F", ",", "{print $2}"},
			stdinStr:   "", // stdin ignored when file is given
			expected:   0,
		},
		{
			name:       "execution error",
			args:       []string{"BEGIN { exit 42 }"},
			expected:   42,
		},
		{
			name:       "internal error via execution",
			args:       []string{"BEGIN { print 1/0 }"},
			expected:   1,
			errContain: "division by zero",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			stdin := bytes.NewBufferString(tt.stdinStr)
			
			// For the "input files" test we dynamically add the input file
			args := tt.args
			if tt.name == "input files" {
				args = append(args, inputFile)
			}
			
			exitCode := RunAwk(args, stdin, &stdout, &stderr)
			
			if exitCode != tt.expected {
				t.Errorf("expected exit code %d, got %d. stderr: %s", tt.expected, exitCode, stderr.String())
			}
			
			if tt.outContain != "" && !bytes.Contains(stdout.Bytes(), []byte(tt.outContain)) {
				t.Errorf("expected stdout to contain %q, got %q", tt.outContain, stdout.String())
			}
			if tt.errContain != "" && !bytes.Contains(stderr.Bytes(), []byte(tt.errContain)) {
				t.Errorf("expected stderr to contain %q, got %q", tt.errContain, stderr.String())
			}
		})
	}

	// Test EmbeddedFS fallback
	t.Run("embedded FS success", func(t *testing.T) {
		oldFS := EmbeddedFS
		defer func() { EmbeddedFS = oldFS }()
		EmbeddedFS = fstest.MapFS{
			"lib/merge.awk": &fstest.MapFile{Data: []byte("BEGIN { print \"embedded\" }")},
		}
		
		var stdout, stderr bytes.Buffer
		stdin := bytes.NewBufferString("")
		exitCode := RunAwk([]string{"-f", "/lib/merge.awk"}, stdin, &stdout, &stderr)
		if exitCode != 0 {
			t.Errorf("expected 0, got %d. stderr: %s", exitCode, stderr.String())
		}
		if !bytes.Contains(stdout.Bytes(), []byte("embedded\n")) {
			t.Errorf("expected 'embedded\\n', got %q", stdout.String())
		}
	})
}
