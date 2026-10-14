// Package gojqcli implements structured diagnostic and exit-code error types for gojq.
package gojqcli

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/itchyny/go-yaml"
	"github.com/mattn/go-runewidth"

	"github.com/itchyny/gojq"
)

// ExitCoder is implemented by error types that specify a process exit status code.
type ExitCoder interface {
	error
	ExitCode() int
}

// EmptyError is implemented by error types that suppress top-level diagnostic output.
type EmptyError interface {
	error
	isEmptyError()
}

// ErrorKind enumerates the structured error categories in gojqcli.
type ErrorKind uint8

const (
	// ErrKindDefault represents a general runtime or validation error.
	ErrKindDefault ErrorKind = iota
	// ErrKindFlagParse represents a command-line flag parsing error.
	ErrKindFlagParse
	// ErrKindCompile represents a jq query compilation error.
	ErrKindCompile
	// ErrKindInvalidIndent represents an out-of-range indentation count.
	ErrKindInvalidIndent
	// ErrKindYAMLTab represents an incompatible --yaml-output and --tab combination.
	ErrKindYAMLTab
	// ErrKindMissingFlagFile represents a missing file argument for -f.
	ErrKindMissingFlagFile
	// ErrKindInvalidColor represents a malformed GOJQ_COLORS specification.
	ErrKindInvalidColor
	// ErrKindNulOutput represents an invalid NUL character in --raw-output0 mode.
	ErrKindNulOutput
)

// cliError is a strongly typed error structure carrying an ErrorKind, message, and exit code.
type cliError struct {
	kind ErrorKind
	msg  string
	code int
}

// newCliError constructs a new cliError with the specified kind, exit code, and message.
// Parameters:
//   - kind: The structured ErrorKind category.
//   - code: The numeric process exit code.
//   - msg: The diagnostic error message.
//
// Returns a pointer to the initialized cliError.
func newCliError(kind ErrorKind, code int, msg string) *cliError {
	return &cliError{kind: kind, msg: msg, code: code}
}

// Error returns the diagnostic message for the cliError.
func (err *cliError) Error() string {
	return err.msg
}

// ExitCode returns the numeric exit status code for the cliError.
func (err *cliError) ExitCode() int {
	return err.code
}

// emptyError wraps an already-reported error so that run() suppresses duplicate stderr output.
type emptyError struct {
	err error
}

// Error returns an empty diagnostic string.
func (*emptyError) Error() string {
	return ""
}

// isEmptyError marks emptyError as suppressing top-level stderr logging.
func (*emptyError) isEmptyError() { _ = 1 }

// ExitCode returns the underlying error's exit code or exitCodeDefaultErr.
func (err *emptyError) ExitCode() int {
	if err, ok := err.err.(ExitCoder); ok {
		return err.ExitCode()
	}
	return exitCodeDefaultErr
}

// exitCodeError represents an explicit process exit code without a diagnostic message.
type exitCodeError struct {
	code int
}

// Error formats the exit code as a diagnostic string.
func (err *exitCodeError) Error() string {
	return "exit code: " + strconv.Itoa(err.code)
}

// isEmptyError marks exitCodeError as suppressing top-level stderr logging.
func (*exitCodeError) isEmptyError() { _ = 1 }

// ExitCode returns the numeric exit code stored in exitCodeError.
func (err *exitCodeError) ExitCode() int {
	return err.code
}

// flagParseError wraps a command-line flag parsing error with exitCodeFlagParseErr.
type flagParseError struct {
	err error
}

// Error returns the underlying flag parsing error message.
func (err *flagParseError) Error() string {
	return err.err.Error()
}

// ExitCode returns exitCodeFlagParseErr (2).
func (*flagParseError) ExitCode() int {
	return exitCodeFlagParseErr
}

// compileError wraps a jq query compilation error with exitCodeCompileErr.
type compileError struct {
	err error
}

// Error formats the compilation error message.
func (err *compileError) Error() string {
	return "compile error: " + err.err.Error()
}

// ExitCode returns exitCodeCompileErr (3).
func (*compileError) ExitCode() int {
	return exitCodeCompileErr
}

// queryParseError represents a syntax error encountered while parsing a jq query.
type queryParseError struct {
	fname, contents string
	err             error
}

// Error formats the query syntax error with line and column context.
func (err *queryParseError) Error() string {
	var offset int
	var e *gojq.ParseError
	if errors.As(err.err, &e) {
		offset = e.Offset - len(e.Token) + 1
	}
	linestr, line, column := getLineByOffset(err.contents, offset)
	if err.fname != "<arg>" || containsNewline(err.contents) {
		return fmt.Sprintf("invalid query: %s:%d\n%s  %s",
			err.fname, line, formatLineInfo(linestr, line, column), err.err)
	}
	return fmt.Sprintf("invalid query: %s\n    %s\n    %*c  %s",
		err.contents, linestr, column+1, '^', err.err)
}

// ExitCode returns exitCodeCompileErr (3).
func (*queryParseError) ExitCode() int {
	return exitCodeCompileErr
}

// jsonParseError represents a syntax error encountered while decoding JSON input.
type jsonParseError struct {
	fname, contents string
	line            int
	err             error
}

// Error formats the JSON syntax error with file, line, and caret pointer context.
func (err *jsonParseError) Error() string {
	var offset int
	if err.err == io.ErrUnexpectedEOF {
		offset = len(err.contents) + 1
	} else if e, ok := err.err.(*json.SyntaxError); ok {
		offset = int(e.Offset)
	}
	linestr, line, column := getLineByOffset(err.contents, offset)
	if line += err.line; line > 1 {
		return fmt.Sprintf("invalid json: %s:%d\n%s  %s",
			err.fname, line, formatLineInfo(linestr, line, column), err.err)
	}
	return fmt.Sprintf("invalid json: %s\n    %s\n    %*c  %s",
		err.fname, linestr, column+1, '^', err.err)
}

// yamlParseError represents a syntax or unmarshaling error encountered while decoding YAML input.
type yamlParseError struct {
	fname, contents string
	err             error
}

// Error formats the YAML parse error with file, line, and caret pointer context.
func (err *yamlParseError) Error() string {
	var index int
	var message string
	var pe *yaml.ParserError
	var te *yaml.TypeError
	if errors.As(err.err, &pe) {
		index, message = pe.Index, pe.Message
	} else if errors.As(err.err, &te) {
		var ue *yaml.UnmarshalError
		for _, e := range te.Errors {
			if errors.As(e, &ue) {
				index, message = ue.Index, ue.Err.Error()
				break
			}
		}
	}
	linestr, line, column := getLineByOffset(err.contents, index+1)
	return fmt.Sprintf("invalid yaml: %s:%d\n%s  %s",
		err.fname, line, formatLineInfo(linestr, line, column), message)
}

// getLineByOffset extracts the relevant line snippet, 1-based line number, and display column for a byte offset.
// Parameters:
//   - str: The source text content.
//   - offset: The 1-based byte offset into str.
//
// Returns the truncated line snippet, 1-based line number, and display column width.
func getLineByOffset(str string, offset int) (linestr string, line, column int) {
	ss := &stringScanner{str, 0}
	for {
		str, start, ok := ss.next()
		if !ok {
			offset -= start
			break
		}
		line++
		linestr = str
		if ss.offset >= offset {
			offset -= start
			break
		}
	}
	offset = min(max(offset-1, 0), len(linestr))
	if offset > 48 {
		skip := len(trimLastInvalidRune(linestr[:offset-48]))
		linestr = linestr[skip:]
		offset -= skip
	}
	linestr = trimLastInvalidRune(linestr[:min(64, len(linestr))])
	if offset < len(linestr) {
		offset = len(trimLastInvalidRune(linestr[:offset]))
	} else {
		offset = len(linestr)
	}
	column = runewidth.StringWidth(linestr[:offset])
	return
}

// trimLastInvalidRune strips any trailing incomplete or invalid UTF-8 rune bytes from s.
// Parameters:
//   - s: The string to trim.
//
// Returns the valid UTF-8 prefix of s.
func trimLastInvalidRune(s string) string {
	for i := len(s) - 1; i >= 0 && i > len(s)-utf8.UTFMax; i-- {
		if b := s[i]; b < utf8.RuneSelf {
			return s[:i+1]
		} else if utf8.RuneStart(b) {
			if r, _ := utf8.DecodeRuneInString(s[i:]); r == utf8.RuneError {
				return s[:i]
			}
			break
		}
	}
	return s
}

// formatLineInfo formats a numbered source line and an aligned caret indicator beneath the target column.
// Parameters:
//   - linestr: The source line text.
//   - line: The 1-based line number.
//   - column: The visual column offset for the caret.
//
// Returns the formatted two-line snippet.
func formatLineInfo(linestr string, line, column int) string {
	l := strconv.Itoa(line)
	return fmt.Sprintf("    %s | %s\n    %*c", l, linestr, column+len(l)+4, '^')
}

// stringScanner iterates over lines in a string while tracking byte offsets.
type stringScanner struct {
	str    string
	offset int
}

// next advances the scanner to the next line and returns the line text, start offset, and whether a line was read.
func (ss *stringScanner) next() (line string, start int, ok bool) {
	if ss.offset == len(ss.str) {
		return
	}
	start, ok = ss.offset, true
	line = ss.str[start:]
	i := indexNewline(line)
	if i < 0 {
		ss.offset = len(ss.str)
		return
	}
	line = line[:i]
	if strings.HasPrefix(ss.str[start+i:], "\r\n") {
		i++
	}
	ss.offset += i + 1
	return
}

// containsNewline reports whether str contains either '\n' or '\r'.
// Parameters:
//   - str: The string to inspect.
//
// Returns true if a newline character is present.
func containsNewline(str string) bool {
	return strings.IndexByte(str, '\n') >= 0 ||
		strings.IndexByte(str, '\r') >= 0
}

// indexNewline returns the byte index of the first '\n' or '\r' in str, or -1 if none is present.
// Parameters:
//   - str: The string to search.
//
// Returns the byte index of the first newline character.
func indexNewline(str string) (i int) {
	if i = strings.IndexByte(str, '\n'); i >= 0 {
		str = str[:i]
	}
	if j := strings.IndexByte(str, '\r'); j >= 0 {
		i = j
	}
	return
}
