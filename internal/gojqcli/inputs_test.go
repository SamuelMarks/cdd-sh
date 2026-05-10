package gojqcli

import (
	"io"
	"strings"
	"testing"
)

func TestJSONInputIterNameClose(t *testing.T) {
	iter := newJSONInputIter(strings.NewReader(""), "test.json")
	if iter.Name() != "test.json" {
		t.Errorf("expected test.json, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestStreamInputIterNameClose(t *testing.T) {
	iter := newStreamInputIter(strings.NewReader(""), "stream.json")
	if iter.Name() != "stream.json" {
		t.Errorf("expected stream.json, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestFilesInputIterNameClose(t *testing.T) {
	iter := newFilesInputIter(newJSONInputIter, []string{"nonexistent.json"}, nil)
	if iter.Name() != "" {
		t.Errorf("expected empty, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}

	iter = newFilesInputIter(newJSONInputIter, []string{"-"}, strings.NewReader("1"))
	iter.Next()
	if iter.Name() != "<stdin>" {
		t.Errorf("expected <stdin>, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestRawInputIterNameClose(t *testing.T) {
	iter := newRawInputIter(strings.NewReader("hello"), "test.txt")
	if iter.Name() != "test.txt" {
		t.Errorf("expected test.txt, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestYAMLInputIterNameClose(t *testing.T) {
	iter := newYAMLInputIter(strings.NewReader(""), "test.yaml")
	if iter.Name() != "test.yaml" {
		t.Errorf("expected test.yaml, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestSlurpInputIterNameClose(t *testing.T) {
	iter := newSlurpInputIter(newJSONInputIter(strings.NewReader(""), "test.json"))
	if iter.Name() != "test.json" {
		t.Errorf("expected test.json, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestReadAllIterNameClose(t *testing.T) {
	iter := newReadAllIter(strings.NewReader(""), "test.txt")
	if iter.Name() != "test.txt" {
		t.Errorf("expected test.txt, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestSlurpRawInputIterNameClose(t *testing.T) {
	iter := newSlurpRawInputIter(newRawInputIter(strings.NewReader(""), "test.txt"))
	if iter.Name() != "test.txt" {
		t.Errorf("expected test.txt, got %q", iter.Name())
	}
	if err := iter.Close(); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestInputsNextAfterError(t *testing.T) {
	iters := []inputIter{
		newJSONInputIter(strings.NewReader(""), ""),
		newStreamInputIter(strings.NewReader(""), ""),
		newRawInputIter(strings.NewReader(""), ""),
		newYAMLInputIter(strings.NewReader(""), ""),
		newReadAllIter(strings.NewReader(""), ""),
		newSlurpInputIter(newJSONInputIter(strings.NewReader(""), "")),
		newSlurpRawInputIter(newRawInputIter(strings.NewReader(""), "")),
		newFilesInputIter(newJSONInputIter, []string{}, nil),
	}
	for _, iter := range iters {
		iter.Close() // this sets i.err = io.EOF
		v, ok := iter.Next()
		if ok || v != nil {
			t.Errorf("expected (nil, false) after Close, got (%v, %v) for %T", v, ok, iter)
		}
	}
}

func TestInputReaderGetContents(t *testing.T) {
	ir := newInputReader(strings.NewReader("test"))
	// Trigger the limit reader logic
	var offset int64 = 4
	var line int = 1
	contents := ir.getContents(&offset, &line)
	if contents == "" {
		t.Errorf("expected some contents, got empty")
	}
}

type errReader struct{}

func (errReader) Read(p []byte) (n int, err error) {
	return 0, io.ErrUnexpectedEOF
}

func TestInputNextErrors(t *testing.T) {
	// readAllIter with error reader
	iter := newReadAllIter(errReader{}, "test.txt")
	v, ok := iter.Next()
	if !ok || v != io.ErrUnexpectedEOF {
		t.Errorf("expected error from readAllIter, got %v, %v", v, ok)
	}

	// rawInputIter with error reader
	iter2 := newRawInputIter(errReader{}, "test.txt")
	v, ok = iter2.Next()
	if !ok || v != io.ErrUnexpectedEOF {
		t.Errorf("expected error from rawInputIter, got %v, %v", v, ok)
	}
}

type nonSeekReader struct{ io.Reader }

func TestInputReaderGetContentsNonSeeker(t *testing.T) {
	ir := newInputReader(nonSeekReader{strings.NewReader("test")})
	// Force it to read so buf is populated
	b := make([]byte, 4)
	ir.Read(b)
	contents := ir.getContents(nil, nil)
	if contents != "test" {
		t.Errorf("expected test, got %s", contents)
	}
}
