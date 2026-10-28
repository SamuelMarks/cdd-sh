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
