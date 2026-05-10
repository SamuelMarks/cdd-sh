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
	err.ExitCode()

	exitErr := &exitCodeError{code: 42}
	exitErr.isEmptyError()
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
	getLineByOffset(str, 150)
	getLineByOffset(str, 5)

	getLineByOffset("abcdef", 10) // offset out of bounds

	// Contains/IndexNewline
	containsNewline("abc\rdef")
	indexNewline("abc\rdef")
	indexNewline("abc\r\ndef")

	trimLastInvalidRune("a\xffb")
	trimLastInvalidRune("\xff")
	trimLastInvalidRune(string([]byte{0xe2, 0x82, 0xac})) // euro sign
}
