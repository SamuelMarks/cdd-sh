package gojqcli

import (
	"errors"
	"strings"
	"testing"

	"github.com/itchyny/gojq"
)

func TestError(t *testing.T) {
	err := &emptyError{}
	if err.Error() != "" || err.ExitCode() != 5 {
		t.Errorf("emptyError failed: %d", err.ExitCode())
	}
	err.isEmptyError() // cover the method

	err2 := &exitCodeError{3}
	if err2.Error() != "exit code: 3" || err2.ExitCode() != 3 {
		t.Errorf("exitCodeError failed: got %q (%d)", err2.Error(), err2.ExitCode())
	}
	err2.isEmptyError() // cover the method

	err3 := &flagParseError{errors.New("flag err")}
	if err3.Error() != "flag err" || err3.ExitCode() != 2 {
		t.Errorf("flagParseError failed")
	}

	err4 := &compileError{errors.New("compile err")}
	if err4.Error() != "compile error: compile err" || err4.ExitCode() != 3 {
		t.Errorf("compileError failed")
	}

	// test queryParseError
	_, errGoJq := gojq.Parse("invalid +")
	err5 := &queryParseError{"<arg>", "invalid +", errGoJq}
	if err5.ExitCode() != 3 {
		t.Errorf("queryParseError ExitCode failed")
	}
	if !strings.Contains(err5.Error(), "invalid query: invalid +") {
		t.Errorf("queryParseError Error failed: got %q", err5.Error())
	}

	// test jsonParseError
	err6 := &jsonParseError{"a.json", "content", 1, errors.New("json err")}
	if !strings.Contains(err6.Error(), "invalid json: a.json:2") || !strings.Contains(err6.Error(), "json err") {
		t.Errorf("jsonParseError failed: got %q", err6.Error())
	}
}
