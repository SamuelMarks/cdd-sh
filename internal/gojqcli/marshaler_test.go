package gojqcli

import (
	"bytes"
	"io"
	"testing"
)

type dummyMarshaler struct{}

func (dummyMarshaler) marshal(v any, w io.Writer) error {
	return nil
}

func TestRawMarshaler(t *testing.T) {
	m := &rawMarshaler{m: dummyMarshaler{}, checkNul: true}
	var buf bytes.Buffer
	err := m.marshal("hello\x00world", &buf)
	if err == nil || err.Error() != `cannot output a string containing NUL character: "hello\x00world"` {
		t.Errorf("unexpected error: %v", err)
	}
}

type failingWriter struct{}

func (failingWriter) Write(p []byte) (n int, err error) {
	return 0, io.ErrShortWrite
}

func TestYamlMarshalerError(t *testing.T) {
	m := yamlFormatter(nil)
	err := m.marshal(map[string]string{"foo": "bar"}, failingWriter{})
	if err == nil {
		t.Errorf("expected error, got nil")
	}
}
