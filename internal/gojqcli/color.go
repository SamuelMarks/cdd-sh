// Package gojqcli implements ANSI color configuration and formatting for gojq output.
package gojqcli

import (
	"bytes"
	"fmt"
	"strings"
)

// noColor controls whether ANSI color escape codes are suppressed during encoding.
var noColor bool

// newColor constructs an ANSI SGR escape sequence byte slice from a style code string.
// Parameters:
//   - c: The ANSI style code string (e.g., "32" or "34;1").
//
// Returns the formatted ANSI escape sequence bytes.
func newColor(c string) []byte {
	return []byte("\x1b[" + c + "m")
}

// setColor writes the given ANSI color bytes to buf if coloring is enabled.
// Parameters:
//   - buf: The target buffer.
//   - color: The ANSI escape sequence bytes to write.
func setColor(buf *bytes.Buffer, color []byte) {
	if !noColor {
		buf.Write(color)
	}
}

var (
	resetColor     = newColor("0")    // Reset
	nullColor      = newColor("90")   // Bright black
	falseColor     = newColor("33")   // Yellow
	trueColor      = newColor("33")   // Yellow
	numberColor    = newColor("36")   // Cyan
	stringColor    = newColor("32")   // Green
	objectKeyColor = newColor("34;1") // Bold Blue
	arrayColor     = []byte(nil)      // No color
	objectColor    = []byte(nil)      // No color
)

// validColor reports whether x is a valid semicolon-delimited ANSI numeric color code string.
// Parameters:
//   - x: The color specification string to validate.
//
// Returns true if valid, false otherwise.
func validColor(x string) bool {
	var num bool
	for _, c := range x {
		if '0' <= c && c <= '9' {
			num = true
		} else if c == ';' && num {
			num = false
		} else {
			return false
		}
	}
	return num
}

// setColors parses a colon-delimited GOJQ_COLORS configuration string and updates the color palette.
// Parameters:
//   - colors: Colon-separated ANSI color codes for null, false, true, number, string, key, array, object.
//
// Returns an error if any color segment is invalid.
func setColors(colors string) error {
	var color string
	for _, target := range []*[]byte{
		&nullColor, &falseColor, &trueColor, &numberColor,
		&stringColor, &objectKeyColor, &arrayColor, &objectColor,
	} {
		color, colors, _ = strings.Cut(colors, ":")
		if color != "" {
			if !validColor(color) {
				return newCliError(ErrKindInvalidColor, exitCodeDefaultErr, fmt.Sprintf("invalid color: %q", color))
			}
			*target = newColor(color)
		} else {
			*target = nil
		}
	}
	return nil
}
