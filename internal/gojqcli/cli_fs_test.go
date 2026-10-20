package gojqcli

import "testing"

func TestResolveJqPath(t *testing.T) {
	oldResolve := ResolvePath
	defer func() { ResolvePath = oldResolve }()

	SetResolvePath(nil)
	if resolveJqPath("test") != "test" {
		t.Errorf("expected 'test'")
	}

	SetResolvePath(func(p string) string { return "resolved" })
	if resolveJqPath("test") != "resolved" {
		t.Errorf("expected 'resolved'")
	}

	c := &cli{}
	if c.resolveFilePath("test") != "resolved" {
		t.Errorf("expected 'resolved' from cli.resolveFilePath")
	}
}
