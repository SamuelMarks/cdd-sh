package gojqcli

import "testing"

func TestResolveJqPath(t *testing.T) {
	oldResolve := ResolvePath
	defer func() { ResolvePath = oldResolve }()

	ResolvePath = nil
	if resolveJqPath("test") != "test" {
		t.Errorf("expected 'test'")
	}

	ResolvePath = func(p string) string { return "resolved" }
	if resolveJqPath("test") != "resolved" {
		t.Errorf("expected 'resolved'")
	}
}
