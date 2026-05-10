package gojqcli

import (
	"errors"
	"github.com/itchyny/gojq"
	"testing"
)

func TestError(t *testing.T) {
	err := &emptyError{}
	if err.Error() != "" || err.ExitCode() != 5 {
		t.Errorf("emptyError failed: %d", err.ExitCode())
	}
	err.isEmptyError() // cover the method

	err2 := &exitCodeError{3}
	if err2.Error() == "" || err2.ExitCode() != 3 {
		t.Errorf("exitCodeError failed")
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
	_, errGoJq := gojq.Parse("invalid")
	err5 := &queryParseError{"<arg>", "invalid", errGoJq}
	if err5.ExitCode() != 3 {
		t.Errorf("queryParseError ExitCode failed")
	}
	if err5.Error() == "" {
		t.Errorf("queryParseError Error failed")
	}

	// test jsonParseError
	err6 := &jsonParseError{"a.json", "content", 1, errors.New("json err")}
	if err6.Error() == "" {
		t.Errorf("jsonParseError failed")
	}
}
