// Package main calculates test coverage and documentation coverage metrics
// across the repository and updates the shields.io badges in README.md.
package main

import (
	"cmp"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// getColor maps a coverage percentage (0-100) to a shields.io badge color name.
// Parameters:
//   - pct: The integer coverage percentage.
//
// Returns the corresponding shields.io color string.
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

// main executes the test and documentation coverage calculations and writes updated badges to README.md.
func main() {
	readmePath := filepath.Join("..", "README.md")
	if _, err := os.Stat("README.md"); err == nil {
		readmePath = "README.md"
	} else if _, err := os.Stat(readmePath); err != nil {
		return
	}

	testCov := 0
	if os.Getenv("SKIP_GO_TEST") == "" {
		cmdStr := "go test -coverprofile=coverage.out ./..."
		errTest := exec.Command("sh", "-c", cmdStr).Run()
		_ = errTest
	}

	cmd := exec.Command("go", "tool", "cover", "-func=coverage.out")
	if out, err := cmd.CombinedOutput(); err == nil {
		re := regexp.MustCompile(`total:\s+\(statements\)\s+([0-9.]+)%`)
		match := re.FindStringSubmatch(string(out))
		if len(match) > 1 {
			if f, parseErr := strconv.ParseFloat(match[1], 64); parseErr == nil {
				testCov = int(f)
			}
		}
	}

	totalFunctions := 0
	documentedFunctions := 0

	baseDir := "."
	if _, err := os.Stat("README.md"); err != nil {
		baseDir = ".."
	}

	shFuncRe := regexp.MustCompile(`(?m)^[ \t]*(?:function[ \t]+)?([a-zA-Z_0-9]+)\(\)[ \t]*\{`)
	awkFuncRe := regexp.MustCompile(`(?m)^[ \t]*function[ \t]+([a-zA-Z_0-9]+)\s*\(`)
	goFuncRe := regexp.MustCompile(`(?m)^func\s+(?:\([^)]+\)\s+)?([a-zA-Z_0-9]+)\s*\(`)
	goTypeRe := regexp.MustCompile(`(?m)^type\s+([a-zA-Z_0-9]+)\s+`)
	placeholderRe := regexp.MustCompile(`(?i)^(?://|#)\s*[a-zA-Z_0-9]+\s+is\s+a\s+(?:function|type|struct)\s*$`)

	walkErr := filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		slashPath := "/" + strings.TrimPrefix(filepath.ToSlash(path), "./")
		for _, ignore := range []string{"/tests", "/tmp_out", "tmp_out", "/temp_sdk", "/.git", "/emsdk", "/out", "out", "/bin", "/temp-sh", "temp-swagger-sdk", "temp-openapi-sdk"} {
			if strings.Contains(slashPath, ignore) {
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

		contentBytes, readErr := os.ReadFile(path)
		content := string(contentBytes)
		_ = cmp.Or(err, readErr)

		if strings.HasSuffix(name, ".sh") || name == "cdd.sh" {
			matches := shFuncRe.FindAllStringIndex(content, -1)
			for _, m := range matches {
				totalFunctions++
				start := m[0]
				before := strings.Split(strings.TrimSpace(content[:start]), "\n")
				if len(before) > 0 {
					lastLine := strings.TrimSpace(before[len(before)-1])
					if strings.HasPrefix(lastLine, "#") && !placeholderRe.MatchString(lastLine) {
						documentedFunctions++
					}
				}
			}
		}

		if strings.HasSuffix(name, ".awk") {
			matches := awkFuncRe.FindAllStringIndex(content, -1)
			for _, m := range matches {
				totalFunctions++
				start := m[0]
				before := strings.Split(strings.TrimSpace(content[:start]), "\n")
				if len(before) > 0 {
					lastLine := strings.TrimSpace(before[len(before)-1])
					if strings.HasPrefix(lastLine, "#") && !placeholderRe.MatchString(lastLine) {
						documentedFunctions++
					}
				}
			}
		}

		if strings.HasSuffix(name, ".jq") {
			totalFunctions++
			trimmed := strings.TrimSpace(content)
			if strings.HasPrefix(trimmed, "#") {
				documentedFunctions++
			}
		}

		if strings.HasSuffix(name, ".go") && !strings.HasSuffix(name, "_test.go") {
			for _, matches := range [][][]int{goFuncRe.FindAllStringIndex(content, -1), goTypeRe.FindAllStringIndex(content, -1)} {
				for _, m := range matches {
					totalFunctions++
					start := m[0]
					before := strings.Split(strings.TrimSpace(content[:start]), "\n")
					if len(before) > 0 {
						lastLine := strings.TrimSpace(before[len(before)-1])
						if strings.HasPrefix(lastLine, "//") && !placeholderRe.MatchString(lastLine) {
							documentedFunctions++
						}
					}
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

	readme, readErr := os.ReadFile(readmePath)

	readmeStr := string(readme)

	testCovRe := regexp.MustCompile(`\[\!\[Test Coverage\]\(https://img\.shields\.io/badge/test_coverage-[0-9.]+%25-[a-z]+\.svg\)\]\(#\)`)
	readmeStr = testCovRe.ReplaceAllString(readmeStr, fmt.Sprintf("[![Test Coverage](https://img.shields.io/badge/test_coverage-%d%%25-%s.svg)](#)", testCov, testColor))

	docCovRe := regexp.MustCompile(`\[\!\[Doc Coverage\]\(https://img\.shields\.io/badge/doc_coverage-[0-9.]+%25-[a-z]+\.svg\)\]\(#\)`)
	readmeStr = docCovRe.ReplaceAllString(readmeStr, fmt.Sprintf("[![Doc Coverage](https://img.shields.io/badge/doc_coverage-%d%%25-%s.svg)](#)", docCov, docColor))

	writeErr := os.WriteFile(readmePath, []byte(readmeStr), 0644)
	_ = cmp.Or(walkErr, readErr, writeErr)
}
