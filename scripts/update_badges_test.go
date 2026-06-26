package main

import (
	"os"
	"testing"
)

func TestGetColor(t *testing.T) {
	if getColor(95) != "brightgreen" {
		t.Error("failed 95")
	}
	if getColor(85) != "green" {
		t.Error("failed 85")
	}
	if getColor(75) != "yellowgreen" {
		t.Error("failed 75")
	}
	if getColor(65) != "yellow" {
		t.Error("failed 65")
	}
	if getColor(55) != "orange" {
		t.Error("failed 55")
	}
	if getColor(45) != "red" {
		t.Error("failed 45")
	}
}

func TestMainFunc_Normal(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	orig, _ := os.Getwd()
	os.Chdir("..")
	defer os.Chdir(orig)
	main()
}

func TestMainFunc_NoReadmeReturn(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)
	main()
}

func TestMainFunc_NoReadme(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()

	// create a README.md in tmp
	os.WriteFile(tmp+"/README.md", []byte(""), 0644)

	subdir := tmp + "/subdir"
	os.MkdirAll(subdir, 0755)

	orig, _ := os.Getwd()
	os.Chdir(subdir)
	defer os.Chdir(orig)
	main()
}

func TestMainFunc_WithTypes(t *testing.T) {
	os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)

	os.WriteFile("README.md", []byte(""), 0644)
	os.WriteFile("go.mod", []byte("module testmod\ngo 1.20\n"), 0644)
	os.WriteFile("dummy.go", []byte("package main\n// dummyType\ntype Dummy int\n"), 0644)

	main()
}

func TestMainFunc_IrregularFile(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()

	os.WriteFile(tmp+"/README.md", []byte(""), 0644)
	os.Symlink(tmp+"/README.md", tmp+"/symlink")

	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)
	main()
}
