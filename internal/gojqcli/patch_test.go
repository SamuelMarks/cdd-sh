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
		"test.json": &fstest.MapFile{Data: []byte(`{"a": 1}`)},
		"test.jq":   &fstest.MapFile{Data: []byte(`.a`)},
		"bad.json":  &fstest.MapFile{Data: []byte(`{bad`)},
		"bad.jq":    &fstest.MapFile{Data: []byte(`1 + `)},
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
	cli.run([]string{"-f", "bad.jq", "test.json"})
	cli.run([]string{"--slurpfile", "val", "bad.json", "."})
	cli.run([]string{".", "/test.json"})
	}
