package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const sampleReadme = `# Test Project
[![Test Coverage](https://img.shields.io/badge/test_coverage-0%25-red.svg)](#)
[![Doc Coverage](https://img.shields.io/badge/doc_coverage-0%25-red.svg)](#)
`

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

func TestBadgeError(t *testing.T) {
	be := &BadgeError{Kind: ErrBadgeCoverageBelow100, Msg: "cov error"}
	if be.Error() != "cov error" || be.ExitCode() != 1 {
		t.Errorf("unexpected BadgeError behavior: %v / %d", be.Error(), be.ExitCode())
	}
}

func TestExtractPrecedingDocBlock(t *testing.T) {
	if _, ok := extractPrecedingDocBlock("", 0, "#"); ok {
		t.Error("expected empty content to return false")
	}
	if _, ok := extractPrecedingDocBlock("foo() {}", 0, "#"); ok {
		t.Error("expected no preceding comment to return false")
	}
	if _, ok := extractPrecedingDocBlock("# foo is a function\nfoo() {}", 20, "#"); ok {
		t.Error("expected placeholder comment to return false")
	}
	block, ok := extractPrecedingDocBlock("# line 1\n# @param $1\nfoo() {}", 21, "#")
	if !ok || !strings.Contains(block, "@param") {
		t.Errorf("expected multi-line doc block, got %q (ok=%v)", block, ok)
	}
}

func TestAuditFileDocCoverage(t *testing.T) {
	shContent := "#!/bin/sh\n# @file s.sh\n# @description d\n# fn doc\n# @param $1\nfn() {\n :\n}\n"
	tot, doc := auditFileDocCoverage("s.sh", shContent)
	if tot != 3 || doc != 3 {
		t.Errorf("expected 3/3 for sh, got %d/%d", doc, tot)
	}

	awkContent := "# @file a.awk\n# @description d\n# fn doc\n# @param x\nfunction fn(x) { return x }\n"
	tot, doc = auditFileDocCoverage("a.awk", awkContent)
	if tot != 3 || doc != 3 {
		t.Errorf("expected 3/3 for awk, got %d/%d", doc, tot)
	}

	jqContent := "# @file f.jq\n# @description d\n# fn doc\n# @param $x\ndef fn($x): $x;\n"
	tot, doc = auditFileDocCoverage("f.jq", jqContent)
	if tot != 3 || doc != 3 {
		t.Errorf("expected 3/3 for jq, got %d/%d", doc, tot)
	}

	goContent := "// Package p docs\npackage p\n// T docs\ntype T int\n// F docs\n// Parameters:\n// - x: int\nfunc F(x int) {}\n"
	tot, doc = auditFileDocCoverage("f.go", goContent)
	if tot != 4 || doc != 4 {
		t.Errorf("expected 4/4 for go, got %d/%d", doc, tot)
	}
}

func TestMainFunc_Normal(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)

	if err := os.WriteFile("README.md", []byte(sampleReadme), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("coverage.out", []byte("mode: set\ncdd-sh/main.go:1.1,2.2 1 1\ntotal:\t(statements)\t100.0%\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("script.sh", []byte("#!/bin/sh\n# @file script.sh\n# @description desc\n# my_func docs\n# @param none\nmy_func() {\n  echo ok\n}\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("helper.awk", []byte("# @file helper.awk\n# @description desc\n# my_awk_func docs\n# @param none\nfunction my_awk_func() {\n  return 1\n}\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("filter.jq", []byte("# @file filter.jq\n# @description desc\n.\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile("emitted_skip.sh", []byte("undoc() {\n echo skip\n}\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(tmp, "tests"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmp, "tests", "inner.sh"), []byte("undoc2() {\n echo skip\n}\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(tmp, "out"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmp, "out", "file.txt"), []byte("skip"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmp, "temp-swagger-sdk.sh"), []byte("skip() {\n :\n}\n"), 0644); err != nil {
		t.Fatal(err)
	}

	main()

	updated, err := os.ReadFile("README.md")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(updated), "doc_coverage-100%25-brightgreen.svg") {
		t.Errorf("expected 100%% doc coverage badge, got:\n%s", string(updated))
	}
}

func TestMainFunc_CheckFailure(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)

	os.WriteFile("README.md", []byte(sampleReadme), 0644)
	os.WriteFile("undoc.sh", []byte("#!/bin/sh\n\nundoc_fn() {\n :\n}\n"), 0644)

	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"update_badges", "--check"}

	oldExit := badgeOsExit
	defer func() { badgeOsExit = oldExit }()
	exitCode := 0
	badgeOsExit = func(c int) { exitCode = c }

	main()
	if exitCode != 1 {
		t.Errorf("expected exitCode 1 when doc coverage < 100%% in --check mode, got %d", exitCode)
	}
}

func TestRunUpdateBadges_Errors(t *testing.T) {
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)

	os.WriteFile("README.md", []byte(sampleReadme), 0644)

	// Test failing go test in check mode
	os.Unsetenv("SKIP_GO_TEST")
	if err := runUpdateBadges([]string{"--check"}); err == nil {
		t.Error("expected error when go test fails in --check mode")
	}

	// Test read-only README write error in check mode
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	os.Chmod("README.md", 0400)
	defer os.Chmod("README.md", 0644)
	if err := runUpdateBadges([]string{"--check"}); err == nil {
		t.Error("expected IO error when README.md is read-only in --check mode")
	}
}

func TestMainFunc_NoReadmeReturn(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	subdir := filepath.Join(tmp, "empty_sub")
	if err := os.MkdirAll(subdir, 0755); err != nil {
		t.Fatal(err)
	}
	orig, _ := os.Getwd()
	os.Chdir(subdir)
	defer os.Chdir(orig)

	main()

	if _, err := os.Stat("README.md"); !os.IsNotExist(err) {
		t.Errorf("expected no README.md to be created when none existed")
	}
}

func TestMainFunc_NoReadme(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()

	if err := os.WriteFile(filepath.Join(tmp, "README.md"), []byte(sampleReadme), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(tmp, "code.go"), []byte("// Package main docs\npackage main\n// ExportedFunc docs\nfunc ExportedFunc() {}\n"), 0644); err != nil {
		t.Fatal(err)
	}

	subdir := filepath.Join(tmp, "subdir")
	if err := os.MkdirAll(subdir, 0755); err != nil {
		t.Fatal(err)
	}

	orig, _ := os.Getwd()
	os.Chdir(subdir)
	defer os.Chdir(orig)
	main()

	updated, err := os.ReadFile(filepath.Join(tmp, "README.md"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(updated), "doc_coverage-100%25-brightgreen.svg") {
		t.Errorf("expected parent README.md to be updated with 100%% doc coverage, got:\n%s", string(updated))
	}
}

func TestMainFunc_WithTypes(t *testing.T) {
	os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()
	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)

	os.WriteFile("README.md", []byte(sampleReadme), 0644)
	os.WriteFile("go.mod", []byte("module testmod\n\ngo 1.21\n"), 0644)
	os.WriteFile("dummy.go", []byte("// Package main docs\npackage main\n// Dummy type docs\ntype Dummy int\n// GetDummy docs\nfunc GetDummy() Dummy { return 1 }\n"), 0644)
	os.WriteFile("dummy_test.go", []byte("package main\nimport \"testing\"\nfunc TestGetDummy(t *testing.T) { if GetDummy() != 1 { t.Fail() } }\n"), 0644)

	main()

	updated, err := os.ReadFile("README.md")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(updated), "test_coverage-100%25-brightgreen.svg") {
		t.Errorf("expected 100%% test coverage badge, got:\n%s", string(updated))
	}
	if !strings.Contains(string(updated), "doc_coverage-100%25-brightgreen.svg") {
		t.Errorf("expected 100%% doc coverage badge, got:\n%s", string(updated))
	}
}

func TestMainFunc_IrregularFile(t *testing.T) {
	os.Setenv("SKIP_GO_TEST", "1")
	defer os.Unsetenv("SKIP_GO_TEST")
	tmp := t.TempDir()

	os.WriteFile(tmp+"/README.md", []byte(sampleReadme), 0644)
	os.Symlink(tmp+"/README.md", tmp+"/symlink")

	orig, _ := os.Getwd()
	os.Chdir(tmp)
	defer os.Chdir(orig)
	main()

	updated, err := os.ReadFile(filepath.Join(tmp, "README.md"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(updated), "doc_coverage-100%25-brightgreen.svg") {
		t.Errorf("expected 100%% doc coverage badge with irregular file skipped, got:\n%s", string(updated))
	}
}
