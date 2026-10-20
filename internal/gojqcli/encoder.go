// Package gojqcli implements custom JSON encoding and pretty-printing with optional ANSI colorization.
package gojqcli

import (
	"bytes"
	"cmp"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/big"
	"sort"
	"strconv"
	"unicode/utf8"
)

// encoder formats and buffers JSON values with configurable indentation and ANSI colors.
type encoder struct {
	out    io.Writer
	w      *bytes.Buffer
	err    error
	tab    bool
	indent int
	depth  int
	colors colorConfig
	buf    [64]byte
}

// newEncoder creates a new encoder with the specified tab and indentation settings.
// Parameters:
//   - tab: Whether to indent using tab characters instead of spaces.
//   - indent: Indentation level per nesting depth (-1 for compact output).
//
// Returns a pointer to the initialized encoder.
func newEncoder(tab bool, indent int) *encoder {
	return newEncoderWithColors(tab, indent, defaultColorConfig(noColor))
}

// newEncoderWithColors creates a new encoder with the specified tab, indentation, and color configuration.
// Parameters:
//   - tab: Whether to indent using tab characters instead of spaces.
//   - indent: Indentation level per nesting depth (-1 for compact output).
//   - colors: Per-encoder ANSI color configuration.
//
// Returns a pointer to the initialized encoder.
func newEncoderWithColors(tab bool, indent int, colors colorConfig) *encoder {
	// reuse the buffer in multiple calls of marshal
	return &encoder{w: new(bytes.Buffer), tab: tab, indent: indent, colors: colors}
}

// flush writes all buffered bytes to the underlying output writer and resets the internal buffer.
// Parameters:
//   - none
//
// Returns any error encountered while writing to e.out.
func (e *encoder) flush() error {
	_, err := e.out.Write(e.w.Bytes())
	e.w.Reset()
	return cmp.Or(e.err, err)
}

// marshal encodes v as JSON and flushes the output to w.
// Parameters:
//   - v: The value to encode.
//   - w: The destination writer.
//
// Returns the first error encountered during encoding or flushing.
func (e *encoder) marshal(v any, w io.Writer) error {
	e.out = w
	return cmp.Or(e.encode(v), e.flush())
}

// encode recursively serializes a single JSON value into the internal buffer.
// Parameters:
//   - v: The value to serialize.
//
// Returns any error encountered when flushing large buffers.
func (e *encoder) encode(v any) error {
	switch v := v.(type) {
	case nil:
		e.write([]byte("null"), e.colors.nullColor)
	case bool:
		if v {
			e.write([]byte("true"), e.colors.trueColor)
		} else {
			e.write([]byte("false"), e.colors.falseColor)
		}
	case int:
		e.write(strconv.AppendInt(e.buf[:0], int64(v), 10), e.colors.numberColor)
	case float64:
		e.encodeFloat64(v)
	case *big.Int:
		e.write(v.Append(e.buf[:0], 10), e.colors.numberColor)
	case json.Number:
		e.write([]byte(v.String()), e.colors.numberColor)
	case string:
		e.encodeString(v, e.colors.stringColor)
	case []any:
		if err := e.encodeArray(v); err != nil {
			return err
		}
	case map[string]any:
		if err := e.encodeObject(v); err != nil {
			return err
		}
	default:
		return newCliError(ErrKindUnsupportedType, exitCodeDefaultErr, fmt.Sprintf("invalid type: %[1]T (%[1]v)", v))
	}
	if e.w.Len() > 8*1024 {
		return e.flush()
	}
	return nil
}

// encodeFloat64 formats a float64 value into JSON numeric representation.
// Parameters:
//   - f: The floating-point number to encode.
func (e *encoder) encodeFloat64(f float64) {
	if math.IsNaN(f) {
		e.write([]byte("null"), e.colors.nullColor)
		return
	}
	f = min(max(f, -math.MaxFloat64), math.MaxFloat64)
	format := byte('f')
	if x := math.Abs(f); x != 0 && x < 1e-6 || x >= 1e21 {
		format = 'e'
	}
	buf := strconv.AppendFloat(e.buf[:0], f, format, -1, 64)
	if format == 'e' {
		// clean up e-09 to e-9
		if n := len(buf); n >= 4 && buf[n-4] == 'e' && buf[n-3] == '-' && buf[n-2] == '0' {
			buf[n-2] = buf[n-1]
			buf = buf[:n-1]
		}
	}
	e.write(buf, e.colors.numberColor)
}

// encodeString writes a JSON-escaped and quoted string with optional ANSI color codes.
// Parameters:
//   - s: The string to escape and write.
//   - color: Optional ANSI escape sequence bytes for coloring.
func (e *encoder) encodeString(s string, color []byte) {
	if color != nil {
		e.colors.writeColor(e.w, color)
	}
	e.w.WriteByte('"')
	start := 0
	for i := 0; i < len(s); {
		if b := s[i]; b < utf8.RuneSelf {
			if ' ' <= b && b <= '~' && b != '"' && b != '\\' {
				i++
				continue
			}
			if start < i {
				e.w.WriteString(s[start:i])
			}
			switch b {
			case '"':
				e.w.WriteString(`\"`)
			case '\\':
				e.w.WriteString(`\\`)
			case '\b':
				e.w.WriteString(`\b`)
			case '\f':
				e.w.WriteString(`\f`)
			case '\n':
				e.w.WriteString(`\n`)
			case '\r':
				e.w.WriteString(`\r`)
			case '\t':
				e.w.WriteString(`\t`)
			default:
				const hex = "0123456789abcdef"
				e.w.WriteString(`\u00`)
				e.w.WriteByte(hex[b>>4])
				e.w.WriteByte(hex[b&0xF])
			}
			i++
			start = i
			continue
		}
		c, size := utf8.DecodeRuneInString(s[i:])
		if c == utf8.RuneError && size == 1 {
			if start < i {
				e.w.WriteString(s[start:i])
			}
			e.w.WriteString(`\ufffd`)
			i += size
			start = i
			continue
		}
		i += size
	}
	if start < len(s) {
		e.w.WriteString(s[start:])
	}
	e.w.WriteByte('"')
	if color != nil {
		e.colors.writeColor(e.w, e.colors.resetColor)
	}
}

// encodeArray serializes a slice of values as a JSON array.
// Parameters:
//   - vs: The slice of elements to encode.
//
// Returns any encoding or flush error.
func (e *encoder) encodeArray(vs []any) error {
	e.writeByte('[', e.colors.arrayColor)
	e.depth += e.indent
	for i, v := range vs {
		if i > 0 {
			e.writeByte(',', e.colors.arrayColor)
		}
		if e.indent >= 0 {
			e.writeIndent()
		}
		if err := e.encode(v); err != nil {
			return err
		}
	}
	e.depth -= e.indent
	if len(vs) > 0 && e.indent >= 0 {
		e.writeIndent()
	}
	e.writeByte(']', e.colors.arrayColor)
	return nil
}

// encodeObject serializes a string-keyed map as a sorted JSON object.
// Parameters:
//   - vs: The map of key-value pairs to encode.
//
// Returns any encoding or flush error.
func (e *encoder) encodeObject(vs map[string]any) error {
	e.writeByte('{', e.colors.objectColor)
	e.depth += e.indent
	type keyVal struct {
		key string
		val any
	}
	kvs := make([]keyVal, len(vs))
	var i int
	for k, v := range vs {
		kvs[i] = keyVal{k, v}
		i++
	}
	sort.Slice(kvs, func(i, j int) bool {
		return kvs[i].key < kvs[j].key
	})
	for i, kv := range kvs {
		if i > 0 {
			e.writeByte(',', e.colors.objectColor)
		}
		if e.indent >= 0 {
			e.writeIndent()
		}
		e.encodeString(kv.key, e.colors.objectKeyColor)
		e.writeByte(':', e.colors.objectColor)
		if e.indent >= 0 {
			e.w.WriteByte(' ')
		}
		if err := e.encode(kv.val); err != nil {
			return err
		}
	}
	e.depth -= e.indent
	if len(vs) > 0 && e.indent >= 0 {
		e.writeIndent()
	}
	e.writeByte('}', e.colors.objectColor)
	return nil
}

// writeIndent writes a newline followed by indentation whitespace for the current nesting depth.
// Parameters:
//   - none
func (e *encoder) writeIndent() {
	e.w.WriteByte('\n')
	if n := e.depth; n > 0 {
		if e.tab {
			e.writeIndentInternal(n, "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t")
		} else {
			e.writeIndentInternal(n, "                                ")
		}
	}
}

// writeIndentInternal writes n indentation characters using spaces as a repeating template.
// Parameters:
//   - n: Number of indentation characters to write.
//   - spaces: Template whitespace string.
func (e *encoder) writeIndentInternal(n int, spaces string) {
	if l := len(spaces); n <= l {
		_, err := e.w.WriteString(spaces[:n])
		e.err = cmp.Or(e.err, err)
	} else {
		_, err := e.w.WriteString(spaces)
		e.err = cmp.Or(e.err, err)
		for n -= l; n > 0; n, l = n-l, l*2 {
			if n < l {
				l = n
			}
			_, werr := e.w.Write(e.w.Bytes()[e.w.Len()-l:])
			e.err = cmp.Or(e.err, werr)
		}
	}
}

// writeByte writes a single byte to the internal buffer wrapped in optional ANSI color codes.
// Parameters:
//   - b: The byte to write.
//   - color: Optional ANSI color escape sequence bytes.
func (e *encoder) writeByte(b byte, color []byte) {
	if color == nil {
		e.err = cmp.Or(e.err, e.w.WriteByte(b))
	} else {
		e.colors.writeColor(e.w, color)
		e.err = cmp.Or(e.err, e.w.WriteByte(b))
		e.colors.writeColor(e.w, e.colors.resetColor)
	}
}

// write writes a byte slice to the internal buffer wrapped in optional ANSI color codes.
// Parameters:
//   - bs: The byte slice to write.
//   - color: Optional ANSI color escape sequence bytes.
func (e *encoder) write(bs, color []byte) {
	if color == nil {
		_, err := e.w.Write(bs)
		e.err = cmp.Or(e.err, err)
	} else {
		e.colors.writeColor(e.w, color)
		_, err := e.w.Write(bs)
		e.err = cmp.Or(e.err, err)
		e.colors.writeColor(e.w, e.colors.resetColor)
	}
}
