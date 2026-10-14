package gojqcli

import (
	"encoding/json"
	"errors"
	"github.com/itchyny/go-yaml"
	"github.com/itchyny/gojq"
	"io"
	"strings"
	"testing"
)

func TestError_EmptyExitCode(t *testing.T) {
	err := &emptyError{}
	err.isEmptyError()
	var emptyIface any = err
	if _, ok := emptyIface.(interface{ isEmptyError() }); !ok {
		t.Errorf("expected emptyError to implement isEmptyError()")
	}
	if err.ExitCode() != exitCodeDefaultErr {
		t.Errorf("expected %d, got %d", exitCodeDefaultErr, err.ExitCode())
	}

	exitErr := &exitCodeError{code: 42}
	exitErr.isEmptyError()
	var exitIface any = exitErr
	if _, ok := exitIface.(interface{ isEmptyError() }); !ok {
		t.Errorf("expected exitCodeError to implement isEmptyError()")
	}
	if exitErr.ExitCode() != 42 {
		t.Errorf("expected 42")
	}
	if exitErr.Error() != "exit code: 42" {
		t.Errorf("expected 'exit code: 42'")
	}
}

func TestError_QueryParseError(t *testing.T) {
	qe := &queryParseError{
		fname:    "<arg>",
		contents: "test\ntest",
		err:      errors.New("test err"),
	}
	if !strings.Contains(qe.Error(), "invalid query:") {
		t.Errorf("missing string")
	}

	pe := &gojq.ParseError{Offset: 5, Token: "tok"}
	qe2 := &queryParseError{
		fname:    "file.jq",
		contents: "test token test",
		err:      pe,
	}
	if !strings.Contains(qe2.Error(), "invalid query: file.jq") {
		t.Errorf("missing string")
	}
}

func TestError_JsonParseError(t *testing.T) {
	je := &jsonParseError{
		fname:    "file.json",
		contents: "{\"a\":}",
		err:      io.ErrUnexpectedEOF,
	}
	if !strings.Contains(je.Error(), "invalid json:") {
		t.Errorf("missing string")
	}

	je2 := &jsonParseError{
		fname:    "file.json",
		contents: "{\"a\":}",
		err:      &json.SyntaxError{Offset: 2},
		line:     2,
	}
	if !strings.Contains(je2.Error(), "invalid json: file.json") {
		t.Errorf("missing string")
	}
}

func TestError_YamlParseError(t *testing.T) {
	ye := &yamlParseError{
		fname:    "file.yaml",
		contents: "a: b\n c: d",
		err:      &yaml.ParserError{Index: 2, Message: "test message"},
	}
	if !strings.Contains(ye.Error(), "invalid yaml:") {
		t.Errorf("missing string")
	}

	ue := &yaml.UnmarshalError{Index: 1, Err: errors.New("unmarshal err")}
	ye2 := &yamlParseError{
		fname:    "file.yaml",
		contents: "a: b\n c: d",
		err:      &yaml.TypeError{Errors: []*yaml.UnmarshalError{ue}},
	}
	if !strings.Contains(ye2.Error(), "invalid yaml:") {
		t.Errorf("missing string")
	}
}

func TestError_StringScannerAndGetLine(t *testing.T) {
	// Trigger the different paths in trimLastInvalidRune and getLineByOffset
	str := strings.Repeat("a", 100) + "\n" + strings.Repeat("b", 100)
	linestr, line, col := getLineByOffset(str, 150)
	if line != 2 || len(linestr) != 64 || col != 48 {
		t.Errorf("unexpected getLineByOffset(150): line=%d len=%d col=%d", line, len(linestr), col)
	}
	linestr2, line2, col2 := getLineByOffset(str, 5)
	if line2 != 1 || len(linestr2) != 64 || col2 != 4 {
		t.Errorf("unexpected getLineByOffset(5): line=%d len=%d col=%d", line2, len(linestr2), col2)
	}

	linestr3, line3, col3 := getLineByOffset("abcdef", 10) // offset out of bounds
	if line3 != 1 || linestr3 != "abcdef" || col3 != 6 {
		t.Errorf("unexpected getLineByOffset(out of bounds): line=%d str=%q col=%d", line3, linestr3, col3)
	}

	// Contains/IndexNewline
	if !containsNewline("abc\rdef") {
		t.Errorf("expected containsNewline to be true for \\r")
	}
	if idx := indexNewline("abc\rdef"); idx != 3 {
		t.Errorf("expected indexNewline 3, got %d", idx)
	}
	if idx := indexNewline("abc\r\ndef"); idx != 3 {
		t.Errorf("expected indexNewline 3 for \\r\\n, got %d", idx)
	}

	if got := trimLastInvalidRune("a\xffb"); got != "a\xffb" {
		t.Errorf("expected 'a\\xffb', got %q", got)
	}
	if got := trimLastInvalidRune("\xff"); got != "" {
		t.Errorf("expected empty string, got %q", got)
	}
	euro := string([]byte{0xe2, 0x82, 0xac})
	if got := trimLastInvalidRune(euro); got != euro {
		t.Errorf("expected euro sign %q, got %q", euro, got)
	}
}
