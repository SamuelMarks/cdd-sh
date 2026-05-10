package gojqcli

import (
	"bytes"
	"encoding/json"
	"errors"
	"math"
	"math/big"
	"testing"
)

func TestEncoder(t *testing.T) {
	origNoColor := noColor
	noColor = true
	defer func() { noColor = origNoColor }()

	tests := []struct {
		name     string
		val      any
		tab      bool
		indent   int
		expected string
		colors   bool // if we need to test color logic
	}{
		{name: "nil", val: nil, expected: "null"},
		{name: "bool true", val: true, expected: "true"},
		{name: "bool false", val: false, expected: "false"},
		{name: "int", val: int(42), expected: "42"},
		{name: "float64", val: float64(3.14), expected: "3.14"},
		{name: "float64 zero", val: float64(0), expected: "0"},
		{name: "float64 NaN", val: math.NaN(), expected: "null"},
		{name: "float64 inf max", val: math.Inf(1), expected: "1.7976931348623157e+308"},
		{name: "float64 inf min", val: math.Inf(-1), expected: "-1.7976931348623157e+308"},
		{name: "float64 small", val: 1e-7, expected: "1e-7"},
		{name: "float64 e-09", val: 1e-9, expected: "1e-9"},
		{name: "float64 big", val: 1e22, expected: "1e+22"},
		{name: "big.Int", val: big.NewInt(12345), expected: "12345"},
		{name: "json.Number", val: json.Number("123.45"), expected: "123.45"},
		{name: "string normal", val: "hello", expected: "\"hello\""},
		{name: "string escape", val: "a\nb\tc\rd\be\ff\"g\\h", expected: `"a\nb\tc\rd\be\ff\"g\\h"`},
		{name: "string control char", val: "\u0001", expected: `"\u0001"`},
		{name: "string invalid utf8", val: "\xff", expected: `"\ufffd"`},
		{name: "string mixed invalid utf8", val: "ab\xff", expected: `"ab\ufffd"`},
		{name: "string mixed escape", val: "ab\u0001", expected: `"ab\u0001"`},
		{name: "array empty", val: []any{}, expected: "[]"},
		{name: "array one", val: []any{1}, expected: "[\n  1\n]", indent: 2},
		{name: "object empty", val: map[string]any{}, expected: "{}"},
		{name: "object one", val: map[string]any{"a": 1}, expected: "{\n  \"a\": 1\n}", indent: 2},
		{name: "array tabs", val: []any{1}, expected: "[\n\t1\n]", indent: 1, tab: true},
		{name: "array many tabs", val: []any{[]any{1}}, expected: "[\n\t[\n\t\t1\n\t]\n]", indent: 1, tab: true},
		{name: "indent spaces large", val: []any{1}, expected: "[\n                                  1\n]", indent: 34},
		{name: "indent tabs large", val: []any{1}, expected: "[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t1\n]", indent: 17, tab: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := newEncoder(tt.tab, tt.indent)
			var buf bytes.Buffer
			err := e.marshal(tt.val, &buf)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got := buf.String(); got != tt.expected {
				t.Errorf("expected %q, got %q", tt.expected, got)
			}
		})
	}
}

func TestEncoderPanic(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic, got nil")
		}
	}()
	e := newEncoder(false, 0)
	var buf bytes.Buffer
	_ = e.marshal(func() {}, &buf)
}

func TestEncoderFlushBufferLimit(t *testing.T) {
	e := newEncoder(false, 0)
	var buf bytes.Buffer

	// generate a large array to trigger flush
	largeArr := make([]any, 0)
	for i := 0; i < 9000; i++ {
		largeArr = append(largeArr, 1)
	}

	err := e.marshal(largeArr, &buf)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

type errWriter struct{}

func (w *errWriter) Write(p []byte) (n int, err error) {
	return 0, errors.New("write error")
}

func TestEncoderErrors(t *testing.T) {
	e := newEncoder(false, 0)
	largeStr := string(make([]byte, 8193))
	err := e.marshal([]any{largeStr, largeStr}, &errWriter{})
	if err == nil {
		t.Fatalf("expected error, got nil")
	}

	e2 := newEncoder(false, 0)
	err2 := e2.marshal(map[string]any{"a": largeStr, "b": largeStr}, &errWriter{})
	if err2 == nil {
		t.Fatalf("expected error, got nil")
	}
}

func TestEncoderColors(t *testing.T) {
	origNoColor := noColor
	noColor = false

	origNullColor := nullColor
	origTrueColor := trueColor
	origFalseColor := falseColor
	origNumberColor := numberColor
	origStringColor := stringColor
	origArrayColor := arrayColor
	origObjectColor := objectColor
	origObjectKeyColor := objectKeyColor

	nullColor = []byte("N")
	trueColor = []byte("T")
	falseColor = []byte("F")
	numberColor = []byte("#")
	stringColor = []byte("S")
	arrayColor = []byte("A")
	objectColor = []byte("O")
	objectKeyColor = []byte("K")
	resetColor = []byte("R")

	defer func() {
		noColor = origNoColor
		nullColor = origNullColor
		trueColor = origTrueColor
		falseColor = origFalseColor
		numberColor = origNumberColor
		stringColor = origStringColor
		arrayColor = origArrayColor
		objectColor = origObjectColor
		objectKeyColor = origObjectKeyColor
		resetColor = []byte("\x1b[0m")
	}()

	e := newEncoder(false, 0)
	var buf bytes.Buffer

	val := []any{nil, true, false, 1, 1.2, map[string]any{"a": "b"}}
	err := e.marshal(val, &buf)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// we mainly want to ensure that coloring code runs without error and covers the branches.
}
