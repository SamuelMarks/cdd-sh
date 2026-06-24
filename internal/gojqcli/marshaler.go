package gojqcli

import (
	"fmt"
	"io"
	"strings"

	"github.com/itchyny/go-yaml"
)

// marshaler is a type
type marshaler interface {
	marshal(any, io.Writer) error
}

// rawMarshaler is a type
type rawMarshaler struct {
	m        marshaler
	checkNul bool
}

// marshal is a function
func (m *rawMarshaler) marshal(v any, w io.Writer) error {
	if s, ok := v.(string); ok {
		if m.checkNul && strings.ContainsRune(s, '\x00') {
			return fmt.Errorf("cannot output a string containing NUL character: %q", s)
		}
		_, err := w.Write([]byte(s))
		return err
	}
	return m.m.marshal(v, w)
}

// yamlFormatter is a function
func yamlFormatter(indent *int) *yamlMarshaler {
	return &yamlMarshaler{indent}
}

// yamlMarshaler is a type
type yamlMarshaler struct {
	indent *int
}

// marshal is a function
func (m *yamlMarshaler) marshal(v any, w io.Writer) error {
	enc := yaml.NewEncoder(w)
	if i := m.indent; i != nil {
		enc.SetIndent(*i)
	} else {
		enc.SetIndent(2)
	}
	if err := enc.Encode(v); err != nil {
		return err
	}
	return enc.Close()
}
