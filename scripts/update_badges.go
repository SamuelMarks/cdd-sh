package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// getColor is a function
func getColor(pct int) string {
	if pct >= 90 {
		return "brightgreen"
	}
	if pct >= 80 {
		return "green"
	}
	if pct >= 70 {
		return "yellowgreen"
	}
	if pct >= 60 {
		return "yellow"
	}
	if pct >= 50 {
		return "orange"
	}
	return "red"
}

// main is a function
func main() {
	readmePath := filepath.Join("..", "README.md")
	if _, err := os.Stat("README.md"); err == nil {
		readmePath = "README.md"
	} else if _, err := os.Stat(readmePath); err != nil {
		return
	}

	testCov := 0
	errTest := exec.Command("go", "test", "-coverprofile=coverage.out", "./...").Run()
	_ = errTest

	cmd := exec.Command("go", "tool", "cover", "-func=coverage.out")
	if out, err := cmd.CombinedOutput(); err == nil {
		re := regexp.MustCompile(`total:\s+\(statements\)\s+([0-9.]+)%`)
		match := re.FindStringSubmatch(string(out))
		if len(match) > 1 {
			f, _ := strconv.ParseFloat(match[1], 64)
			testCov = int(f)
		}
	}

	totalFunctions := 0
	documentedFunctions := 0

	baseDir := "."
	if _, err := os.Stat("README.md"); err != nil {
		baseDir = ".."
	}

	shFuncRe := regexp.MustCompile(`(?m)^[ \t]*([a-zA-Z_0-9]+)\(\)[ \t]*\{`)
	goFuncRe := regexp.MustCompile(`(?m)^[ \t]*func\s+([A-Z][a-zA-Z0-9_]*)\s*\(`)
	goTypeRe := regexp.MustCompile(`(?m)^[ \t]*type\s+([A-Z][a-zA-Z0-9_]*)\s+`)

	filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {

		for _, ignore := range []string{"/tests", "/tmp_out", "tmp_out", "/temp_sdk", "/.git", "/emsdk", "/out", "out", "/bin", "/temp-sh", "temp-swagger-sdk", "temp-openapi-sdk"} {
			if strings.Contains(filepath.ToSlash(path), ignore) {
				if info.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}
		}
		if info.IsDir() {
			return nil
		}

		name := info.Name()
		if !info.Mode().IsRegular() {
			return nil
		}
		if strings.HasPrefix(name, "emitted_") || strings.HasPrefix(name, "test_") {
			return nil
		}

		contentBytes, _ := os.ReadFile(path)
		content := string(contentBytes)

		if strings.HasSuffix(name, ".sh") || name == "cdd.sh" {
			matches := shFuncRe.FindAllStringIndex(content, -1)
			for _, m := range matches {
				totalFunctions++
				start := m[0]
				before := strings.Split(strings.TrimSpace(content[:start]), "\n")
				if len(before) > 0 && strings.HasPrefix(strings.TrimSpace(before[len(before)-1]), "#") {
					documentedFunctions++
				}
			}
		}

		if strings.HasSuffix(name, ".go") && !strings.HasSuffix(name, "_test.go") {
			matches := goFuncRe.FindAllStringIndex(content, -1)
			for _, m := range matches {
				totalFunctions++
				start := m[0]
				before := strings.Split(strings.TrimSpace(content[:start]), "\n")
				if len(before) > 0 && strings.HasPrefix(strings.TrimSpace(before[len(before)-1]), "//") {
					documentedFunctions++
				}
			}

			matches = goTypeRe.FindAllStringIndex(content, -1)
			for _, m := range matches {
				totalFunctions++
				start := m[0]
				before := strings.Split(strings.TrimSpace(content[:start]), "\n")
				if len(before) > 0 && strings.HasPrefix(strings.TrimSpace(before[len(before)-1]), "//") {
					documentedFunctions++
				}
			}
		}
		return nil
	})

	docCov := 100
	if totalFunctions > 0 {
		docCov = int((float64(documentedFunctions) / float64(totalFunctions)) * 100)
	}

	testColor := getColor(testCov)
	docColor := getColor(docCov)

	readme, _ := os.ReadFile(readmePath)

	readmeStr := string(readme)

	testCovRe := regexp.MustCompile(`\[\!\[Test Coverage\]\(https://img\.shields\.io/badge/test_coverage-[0-9.]+%25-[a-z]+\.svg\)\]\(#\)`)
	readmeStr = testCovRe.ReplaceAllString(readmeStr, fmt.Sprintf("[![Test Coverage](https://img.shields.io/badge/test_coverage-%d%%25-%s.svg)](#)", testCov, testColor))

	docCovRe := regexp.MustCompile(`\[\!\[Doc Coverage\]\(https://img\.shields\.io/badge/doc_coverage-[0-9.]+%25-[a-z]+\.svg\)\]\(#\)`)
	readmeStr = docCovRe.ReplaceAllString(readmeStr, fmt.Sprintf("[![Doc Coverage](https://img.shields.io/badge/doc_coverage-%d%%25-%s.svg)](#)", docCov, docColor))

	os.WriteFile(readmePath, []byte(readmeStr), 0644)
}
