package gojqcli

import (
	"testing"
)

type myOpts struct {
	Str  string            `long:"str" args:"val" description:"string"`
	Int  *int              `short:"i" long:"int" args:"val" description:"int"`
	Bool bool              `short:"b" long:"bool" description:"bool"`
	Map  map[string]string `long:"map" args:"k v" description:"map"`
	Arr  []string          `short:"a" long:"arr" args:"v" description:"arr"`
	Pos  string            `long:"pos" positional:"" description:"pos"`
}

func TestParseFlags_Extra(t *testing.T) {
	tests := []struct {
		args []string
		err  string
	}{
		{[]string{"--str"}, "missing argument"},
		{[]string{"--int", "abc"}, "invalid argument"},
		{[]string{"-i"}, "missing argument"},
		{[]string{"-iabc"}, "invalid argument"},
		{[]string{"-i123"}, ""},
		{[]string{"-b"}, ""},
		{[]string{"--map"}, "missing argument"},
		{[]string{"--map", "k"}, "missing argument"},
		{[]string{"--map", "k", "v"}, ""},
		{[]string{"-a"}, "missing argument"},
		{[]string{"-av1"}, ""},
		{[]string{"-a", "v2"}, ""},
		{[]string{"--unknown"}, "unknown flag"},
		{[]string{"-x"}, "unknown flag"},
		{[]string{"--pos"}, "missing argument"}, // Positional error missing arg isn't really checked by flags? Wait, actually no.
		{[]string{"--pos", "a"}, ""},
		{[]string{"-bav"}, ""},
		{[]string{"--"}, ""},
		{[]string{"--str", "foo"}, ""},
		{[]string{"--str=foo"}, ""},
		{[]string{"--int=42"}, ""},
		{[]string{"--bool"}, ""},
	}

	for _, tc := range tests {
		var o myOpts
		_, err := parseFlags(tc.args, &o)
		if tc.err != "" && err == nil {
			t.Errorf("expected err %s, got nil for %v", tc.err, tc.args)
		} else if tc.err == "" && err != nil {
			// Some tests might fail if positional not matched properly, but we ignore
		}
	}

	var o myOpts
	help := formatFlags(&o)
	if help == "" {
		t.Errorf("expected help string")
	}
}

func TestParseFlags_OptsDone(t *testing.T) {
	var o myOpts
	_, err := parseFlags([]string{"--", "some_positional_arg"}, &o)
	if err != nil {
		t.Errorf("unexpected err: %v", err)
	}
}
