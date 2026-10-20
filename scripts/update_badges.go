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

// BadgeErrorKind enumerates the structured error categories in update_badges.
type BadgeErrorKind uint8

const (
	// ErrBadgeTestFailed indicates the Go test coverage execution failed.
	ErrBadgeTestFailed BadgeErrorKind = iota
	// ErrBadgeCoverageBelow100 indicates test or documentation coverage fell below 100%.
	ErrBadgeCoverageBelow100
	// ErrBadgeIO indicates a file walk, read, or write failure.
	ErrBadgeIO
)

// BadgeError is a strongly typed error implementing error and ExitCode() for badge verification.
type BadgeError struct {
	Kind BadgeErrorKind
	Msg  string
}

// Error returns the formatted diagnostic message for BadgeError.
// Parameters:
//   - none
//
// Returns the diagnostic error string.
func (e *BadgeError) Error() string {
	return e.Msg
}

// ExitCode returns the numeric process exit code (1) for BadgeError.
// Parameters:
//   - none
//
// Returns 1.
func (e *BadgeError) ExitCode() int {
	return 1
}

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

var (
	shFuncRe      = regexp.MustCompile(`(?m)^[ \t]*(?:function[ \t]+)?([a-zA-Z_0-9]+)\(\)[ \t]*\{[ \t]*$`)
	shBodyArgRe   = regexp.MustCompile(`(?m)^[ \t]*(?:[a-zA-Z_0-9]+="\$\{?[1-9]|\bshift\b|.*\$\{?[1-9][0-9]*:-|\bfor[ \t]+[^\n]+\bin[ \t]+"\$@")`)
	awkFuncRe     = regexp.MustCompile(`(?m)^[ \t]*function[ \t]+([a-zA-Z_0-9]+)\s*\(([^)]*)\)`)
	jqDefRe       = regexp.MustCompile(`(?m)^[ \t]*def[ \t]+([a-zA-Z_0-9]+)(?:\(([^)]*)\))?:`)
	goFuncRe      = regexp.MustCompile(`(?m)^func\s+(?:\([^)]+\)\s+)?([a-zA-Z_0-9]+)\s*(?:\[[^\]]+\])?\s*\(([^)]*)\)\s*([^{\n]*)`)
	goTypeRe      = regexp.MustCompile(`(?m)^type\s+([a-zA-Z_0-9]+)\s+`)
	placeholderRe = regexp.MustCompile(`(?i)^(?://|#)\s*[a-zA-Z_0-9]+\s+is\s+a\s+(?:function|type|struct)\s*$`)
)

// extractPrecedingDocBlock returns the contiguous comment lines immediately preceding byte offset `start`.
// Parameters:
//   - content: The full file text.
//   - start: The 0-based byte offset of the symbol declaration.
//   - prefix: The comment prefix ("#" or "//").
//
// Returns the joined comment block string and whether a valid non-placeholder comment was found.
func extractPrecedingDocBlock(content string, start int, prefix string) (string, bool) {
	before := strings.Split(strings.TrimRight(content[:start], " \t"), "\n")
	if len(before) > 0 && strings.TrimSpace(before[len(before)-1]) == "" {
		before = before[:len(before)-1]
	}
	var lines []string
	for i := len(before) - 1; i >= 0; i-- {
		trimmed := strings.TrimSpace(before[i])
		if strings.HasPrefix(trimmed, prefix) && !strings.HasPrefix(trimmed, "#!") {
			lines = append([]string{trimmed}, lines...)
		} else {
			break
		}
	}
	if len(lines) == 0 {
		return "", false
	}
	lastLine := lines[len(lines)-1]
	if placeholderRe.MatchString(lastLine) {
		return "", false
	}
	return strings.Join(lines, "\n"), true
}

// auditAwkFunctions counts function and parameter documentation for AWK functions within content.
// Parameters:
//   - content: The text containing AWK function declarations.
//
// Returns the total and documented items for AWK functions.
func auditAwkFunctions(content string) (total, documented int) {
	matches := awkFuncRe.FindAllStringSubmatchIndex(content, -1)
	for _, m := range matches {
		total += 2
		docBlock, ok := extractPrecedingDocBlock(content, m[0], "#")
		if ok {
			documented++
		}
		if strings.Contains(docBlock, "@param") {
			documented++
		}
	}
	return total, documented
}

// auditFileDocCoverage counts total and documented file headers, functions, parameters, returns, and types for a single file.
// Parameters:
//   - name: The base filename.
//   - content: The file text content.
//
// Returns the total doc items and documented items count.
func auditFileDocCoverage(name, content string) (total, documented int) {
	trimmed := strings.TrimSpace(content)
	if strings.HasSuffix(name, ".sh") || name == "cdd.sh" {
		total++
		if strings.Contains(content, "# @file") && strings.Contains(content, "# @description") {
			documented++
		}
		matches := shFuncRe.FindAllStringSubmatchIndex(content, -1)
		for idx, m := range matches {
			total += 2
			docBlock, ok := extractPrecedingDocBlock(content, m[0], "#")
			if ok {
				documented++
			}
			bodyEnd := len(content)
			if idx+1 < len(matches) {
				bodyEnd = matches[idx+1][0]
			}
			fnBody := content[m[1]:bodyEnd]
			if closeIdx := strings.Index(fnBody, "\n}"); closeIdx >= 0 {
				fnBody = fnBody[:closeIdx]
			}
			usesArgs := shBodyArgRe.MatchString(fnBody)
			if strings.Contains(docBlock, "@param") && (!usesArgs || !strings.Contains(docBlock, "@param none")) {
				documented++
			}
		}
		awkTot, awkDoc := auditAwkFunctions(content)
		total += awkTot
		documented += awkDoc
	}

	if strings.HasSuffix(name, ".awk") {
		total++
		if strings.Contains(content, "# @file") && strings.Contains(content, "# @description") {
			documented++
		}
		awkTot, awkDoc := auditAwkFunctions(content)
		total += awkTot
		documented += awkDoc
	}

	if strings.HasSuffix(name, ".jq") {
		total++
		if strings.Contains(content, "# @file") && strings.Contains(content, "# @description") {
			documented++
		}
		matches := jqDefRe.FindAllStringSubmatchIndex(content, -1)
		for _, m := range matches {
			total += 3
			docBlock, ok := extractPrecedingDocBlock(content, m[0], "#")
			if ok {
				documented++
			}
			if strings.Contains(docBlock, "@param") {
				documented++
			}
			if strings.Contains(docBlock, "@return") {
				documented++
			}
		}
	}

	if strings.HasSuffix(name, ".go") && !strings.HasSuffix(name, "_test.go") {
		total++
		if strings.HasPrefix(trimmed, "// Package ") {
			documented++
		}
		for _, m := range goFuncRe.FindAllStringSubmatchIndex(content, -1) {
			total += 2
			docBlock, ok := extractPrecedingDocBlock(content, m[0], "//")
			if ok {
				documented++
			}
			if strings.Contains(docBlock, "Parameters:") {
				documented++
			}
			retSig := strings.TrimSpace(content[m[6]:m[7]])
			if retSig != "" {
				total++
				if strings.Contains(docBlock, "Returns ") {
					documented++
				}
			}
		}
		for _, m := range goTypeRe.FindAllStringIndex(content, -1) {
			total++
			if _, ok := extractPrecedingDocBlock(content, m[0], "//"); ok {
				documented++
			}
		}
	}
	return total, documented
}

// runUpdateBadges calculates test and doc coverage, updates README.md, and enforces 100% when checkMode is true.
// Parameters:
//   - args: Command-line arguments (supports "--check").
//
// Returns any BadgeError encountered.
func runUpdateBadges(args []string) error {
	checkMode := false
	for _, a := range args {
		if a == "--check" {
			checkMode = true
		}
	}

	readmePath := filepath.Join("..", "README.md")
	if _, err := os.Stat("README.md"); err == nil {
		readmePath = "README.md"
	} else if _, err := os.Stat(readmePath); err != nil {
		return nil
	}

	testCov := 0
	testCovFloat := 0.0
	if os.Getenv("SKIP_GO_TEST") == "" {
		cmdStr := "go test -coverprofile=coverage.out ./..."
		if errTest := exec.Command("sh", "-c", cmdStr).Run(); errTest != nil && checkMode {
			return &BadgeError{Kind: ErrBadgeTestFailed, Msg: fmt.Sprintf("go test failed: %v", errTest)}
		}
	}

	cmd := exec.Command("go", "tool", "cover", "-func=coverage.out")
	if out, err := cmd.CombinedOutput(); err == nil {
		re := regexp.MustCompile(`total:\s+\(statements\)\s+([0-9.]+)%`)
		match := re.FindStringSubmatch(string(out))
		if len(match) > 1 {
			if f, parseErr := strconv.ParseFloat(match[1], 64); parseErr == nil {
				testCovFloat = f
				testCov = int(f)
			}
		}
	}

	totalItems := 0
	documentedItems := 0

	baseDir := "."
	if _, err := os.Stat("README.md"); err != nil {
		baseDir = ".."
	}

	walkErr := filepath.Walk(baseDir, func(path string, info os.FileInfo, err error) error {
		slashPath := "/" + strings.TrimPrefix(filepath.ToSlash(path), "./")
		for _, ignore := range []string{"/tests", "/tmp_out", "/temp_sdk", "/.git", "/emsdk", "/out", "/bin", "/temp-sh", "temp-swagger-sdk", "temp-openapi-sdk"} {
			if path != baseDir && strings.Contains(slashPath, ignore) {
				if info != nil && info.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}
		}
		if info == nil || info.IsDir() || !info.Mode().IsRegular() {
			return nil
		}

		name := info.Name()
		if strings.HasPrefix(name, "emitted_") || strings.HasPrefix(name, "test_") {
			return nil
		}

		contentBytes, readErr := os.ReadFile(path)
		_ = cmp.Or(err, readErr)
		t, d := auditFileDocCoverage(name, string(contentBytes))
		totalItems += t
		documentedItems += d
		return nil
	})

	docCov := 100
	if totalItems > 0 {
		docCov = int((float64(documentedItems) / float64(totalItems)) * 100)
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
	if ioErr := cmp.Or(walkErr, readErr, writeErr); ioErr != nil && checkMode {
		return &BadgeError{Kind: ErrBadgeIO, Msg: ioErr.Error()}
	}
	if checkMode && (documentedItems < totalItems || docCov < 100 || (os.Getenv("SKIP_GO_TEST") == "" && testCovFloat < 100.0)) {
		return &BadgeError{
			Kind: ErrBadgeCoverageBelow100,
			Msg:  fmt.Sprintf("coverage below 100%% (test=%.1f%%, doc=%d%% [%d/%d])", testCovFloat, docCov, documentedItems, totalItems),
		}
	}
	return nil
}

// badgeOsExit holds os.Exit to allow interception in tests.
var badgeOsExit = os.Exit

// main executes the test and documentation coverage calculations and writes updated badges to README.md.
// Parameters:
//   - none
//
// Returns nothing.
func main() {
	if err := runUpdateBadges(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		if ec, ok := err.(interface{ ExitCode() int }); ok {
			badgeOsExit(ec.ExitCode())
		}
	}
}
