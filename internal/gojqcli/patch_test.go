package gojqcli

import (
	"bytes"
	"testing"
	"testing/fstest"
)

func TestEmbeddedFS(t *testing.T) {
	origFS := EmbeddedFS
	defer func() { EmbeddedFS = origFS }()

	EmbeddedFS = fstest.MapFS{
		"test.json":            &fstest.MapFile{Data: []byte(`{"a": 1}`)},
		"test.jq":              &fstest.MapFile{Data: []byte(`.a`)},
		"bad.json":             &fstest.MapFile{Data: []byte(`{bad`)},
		"bad.jq":               &fstest.MapFile{Data: []byte(`1 + `)},
		"lib/_common/mymod.jq": &fstest.MapFile{Data: []byte(`def myfn: 42;`)},
	}

	cli := &cli{
		inStream:  bytes.NewReader(nil),
		outStream: new(bytes.Buffer),
		errStream: new(bytes.Buffer),
	}

	exitCode := cli.run([]string{"--slurpfile", "val", "test.json", ".", "test.json"})
	if exitCode != exitCodeOK {
		t.Errorf("expected OK, got %v\nstderr: %s", exitCode, cli.errStream.(*bytes.Buffer).String())
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"-f", "test.jq", "test.json"})
	if exitCode != exitCodeOK {
		t.Errorf("expected OK, got %v\nstderr: %s", exitCode, cli.errStream.(*bytes.Buffer).String())
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"--rawfile", "val", "/test.json", "-f", "/test.jq", "test.json"})
	if exitCode != exitCodeOK {
		t.Errorf("expected OK, got %v\nstderr: %s", exitCode, cli.errStream.(*bytes.Buffer).String())
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"-f", "bad.jq", "test.json"})
	if exitCode != exitCodeCompileErr {
		t.Errorf("expected exitCodeCompileErr (%d), got %d", exitCodeCompileErr, exitCode)
	}
	if cli.errStream.(*bytes.Buffer).Len() == 0 {
		t.Errorf("expected non-empty stderr for bad.jq")
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"--slurpfile", "val", "bad.json", "."})
	if exitCode != exitCodeDefaultErr {
		t.Errorf("expected exitCodeDefaultErr (%d), got %d", exitCodeDefaultErr, exitCode)
	}
	if cli.errStream.(*bytes.Buffer).Len() == 0 {
		t.Errorf("expected non-empty stderr for bad.json")
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{".", "/test.json"})
	if exitCode != exitCodeOK {
		t.Errorf("expected exitCodeOK (%d), got %d", exitCodeOK, exitCode)
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"-L", "./lib/_common", "-n", `include "mymod"; myfn`})
	if exitCode != exitCodeOK {
		t.Errorf("expected exitCodeOK for embedded module, got %d: %s", exitCode, cli.errStream.(*bytes.Buffer).String())
	}

	cli.outStream = new(bytes.Buffer)
	cli.errStream = new(bytes.Buffer)
	exitCode = cli.run([]string{"-L", "./lib/_common", "-n", `include "nonexistent_mod_xyz"; .`})
	if exitCode == exitCodeOK {
		t.Errorf("expected failure for missing module")
	}
}
