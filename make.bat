@echo off
setlocal

if "%~1"=="" goto help
if "%~1"=="help" goto help
if "%~1"=="all" goto help
if "%~1"=="docs" goto docs
if "%~1"=="build" goto build
if "%~1"=="test" goto test
if "%~1"=="clean" goto clean
if "%~1"=="build_wasm" goto build_wasm

echo Unknown command: %~1
goto help

:help
echo Available tasks:
echo   docs           Generate API documentation with Doxygen and symlink to docs\html
echo   build          Build the CLI binary
echo   test           Run tests locally
echo   clean          Clean build artifacts
echo   build_wasm     Build WASM binary
echo   all            Show help text
goto :EOF

:docs
echo Generating API docs with Doxygen...
if not exist "build\api_docs" mkdir "build\api_docs"
(
echo PROJECT_NAME = cdd-sh
echo INPUT = src lib internal cdd.sh main.go
echo OUTPUT_DIRECTORY = build/api_docs
echo RECURSIVE = YES
echo GENERATE_LATEX = NO
echo GENERATE_HTML = YES
echo HTML_OUTPUT = html
) | doxygen -
if not exist "docs" mkdir "docs"
if exist "docs\html" rmdir /s /q "docs\html"
cd docs
mklink /J html ..\build\api_docs\html
cd ..
goto :EOF

:build
if not exist "bin" mkdir "bin"
copy cdd.sh bin\cdd-sh
goto :EOF

:test
call :build
go test -coverprofile=coverage.out .\...
sh .\test.sh
sh .\tests\test.sh
goto :EOF

:clean
if exist "bin" rmdir /s /q "bin"
if exist "wasm_build" rmdir /s /q "wasm_build"
goto :EOF

:build_wasm
if not exist "wasm_build" mkdir "wasm_build"
set GOOS=wasip1
set GOARCH=wasm
go build -o wasm_build\cdd-sh.wasm main.go
goto :EOF
