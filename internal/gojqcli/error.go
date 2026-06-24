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

// emptyError is a type
type emptyError struct {
	err error
}

// Error is a function
func (*emptyError) Error() string {
	return ""
}

// isEmptyError is a function
func (*emptyError) isEmptyError() { _ = 1 }

// ExitCode is a function
func (err *emptyError) ExitCode() int {
	if err, ok := err.err.(interface{ ExitCode() int }); ok {
		return err.ExitCode()
	}
	return exitCodeDefaultErr
}

// exitCodeError is a type
type exitCodeError struct {
	code int
}

// Error is a function
func (err *exitCodeError) Error() string {
	return "exit code: " + strconv.Itoa(err.code)
}

// isEmptyError is a function
func (*exitCodeError) isEmptyError() { _ = 1 }

// ExitCode is a function
func (err *exitCodeError) ExitCode() int {
	return err.code
}

// flagParseError is a type
type flagParseError struct {
	err error
}

// Error is a function
func (err *flagParseError) Error() string {
	return err.err.Error()
}

// ExitCode is a function
func (*flagParseError) ExitCode() int {
	return exitCodeFlagParseErr
}

// compileError is a type
type compileError struct {
	err error
}

// Error is a function
func (err *compileError) Error() string {
	return "compile error: " + err.err.Error()
}

// ExitCode is a function
func (*compileError) ExitCode() int {
	return exitCodeCompileErr
}

// queryParseError is a type
type queryParseError struct {
	fname, contents string
	err             error
}

// Error is a function
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

// ExitCode is a function
func (*queryParseError) ExitCode() int {
	return exitCodeCompileErr
}

// jsonParseError is a type
type jsonParseError struct {
	fname, contents string
	line            int
	err             error
}

// Error is a function
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

// yamlParseError is a type
type yamlParseError struct {
	fname, contents string
	err             error
}

// Error is a function
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

// getLineByOffset is a function
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

// trimLastInvalidRune is a function
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

// formatLineInfo is a function
func formatLineInfo(linestr string, line, column int) string {
	l := strconv.Itoa(line)
	return fmt.Sprintf("    %s | %s\n    %*c", l, linestr, column+len(l)+4, '^')
}

// stringScanner is a type
type stringScanner struct {
	str    string
	offset int
}

// next is a function
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

// Faster than strings.ContainsAny(str, "\r\n").
// containsNewline is a function
func containsNewline(str string) bool {
	return strings.IndexByte(str, '\n') >= 0 ||
		strings.IndexByte(str, '\r') >= 0
}

// Faster than strings.IndexAny(str, "\r\n").
// indexNewline is a function
func indexNewline(str string) (i int) {
	if i = strings.IndexByte(str, '\n'); i >= 0 {
		str = str[:i]
	}
	if j := strings.IndexByte(str, '\r'); j >= 0 {
		i = j
	}
	return
}
