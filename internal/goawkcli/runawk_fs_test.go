package goawkcli

import "testing"

func TestResolveAwkPath(t *testing.T) {
	oldResolve := ResolvePath
	defer func() { ResolvePath = oldResolve }()

	SetResolvePath(nil)
	if resolveAwkPath("test") != "test" {
		t.Errorf("expected 'test'")
	}

	SetResolvePath(func(p string) string { return "resolved" })
	if resolveAwkPath("test") != "resolved" {
		t.Errorf("expected 'resolved'")
	}
}
