// Package gojqcli implements ANSI color configuration and formatting for gojq output.
package gojqcli

import (
	"bytes"
	"fmt"
	"strings"
)

// noColor controls whether ANSI color escape codes are suppressed during encoding.
var noColor bool

// colorConfig holds the per-encoder ANSI color palette and suppression flag.
type colorConfig struct {
	noColor        bool
	resetColor     []byte
	nullColor      []byte
	falseColor     []byte
	trueColor      []byte
	numberColor    []byte
	stringColor    []byte
	objectKeyColor []byte
	arrayColor     []byte
	objectColor    []byte
}

// defaultColorConfig constructs a colorConfig initialized from the default color palette.
// Parameters:
//   - disableColor: Whether ANSI color output is disabled for this configuration.
//
// Returns the initialized colorConfig.
func defaultColorConfig(disableColor bool) colorConfig {
	return colorConfig{
		noColor:        disableColor,
		resetColor:     resetColor,
		nullColor:      nullColor,
		falseColor:     falseColor,
		trueColor:      trueColor,
		numberColor:    numberColor,
		stringColor:    stringColor,
		objectKeyColor: objectKeyColor,
		arrayColor:     arrayColor,
		objectColor:    objectColor,
	}
}

// writeColor writes the given ANSI color bytes to buf if coloring is enabled in cfg.
// Parameters:
//   - buf: The target buffer.
//   - color: The ANSI escape sequence bytes to write.
func (cfg *colorConfig) writeColor(buf *bytes.Buffer, color []byte) {
	if !cfg.noColor {
		buf.Write(color)
	}
}

// parseColors parses a colon-delimited GOJQ_COLORS configuration string into cfg.
// Parameters:
//   - colors: Colon-separated ANSI color codes for null, false, true, number, string, key, array, object.
//
// Returns an error if any color segment is invalid.
func (cfg *colorConfig) parseColors(colors string) error {
	var color string
	for _, target := range []*[]byte{
		&cfg.nullColor, &cfg.falseColor, &cfg.trueColor, &cfg.numberColor,
		&cfg.stringColor, &cfg.objectKeyColor, &cfg.arrayColor, &cfg.objectColor,
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

// newColor constructs an ANSI SGR escape sequence byte slice from a style code string.
// Parameters:
//   - c: The ANSI style code string (e.g., "32" or "34;1").
//
// Returns the formatted ANSI escape sequence bytes.
func newColor(c string) []byte {
	return []byte("\x1b[" + c + "m")
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
