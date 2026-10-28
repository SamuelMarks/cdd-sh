// Package gojqcli implements output marshalers for JSON and raw string formats.
package gojqcli

import (
	"fmt"
	"io"
	"strings"
)

// marshaler defines the interface for serializing a jq evaluation value to an io.Writer.
type marshaler interface {
	marshal(any, io.Writer) error
}

// rawMarshaler wraps a fallback marshaler and writes string values directly without JSON quoting.
type rawMarshaler struct {
	m        marshaler
	checkNul bool
}

// marshal writes v as an unquoted string if v is a string, or delegates to the underlying marshaler.
// Parameters:
//   - v: The value to serialize.
//   - w: The destination writer.
//
// Returns an error if NUL check fails or writing fails.
func (m *rawMarshaler) marshal(v any, w io.Writer) error {
	if s, ok := v.(string); ok {
		if m.checkNul && strings.ContainsRune(s, '\x00') {
			return newCliError(ErrKindNulOutput, exitCodeDefaultErr, fmt.Sprintf("cannot output a string containing NUL character: %q", s))
		}
		_, err := w.Write([]byte(s))
		return err
	}
	return m.m.marshal(v, w)
}
