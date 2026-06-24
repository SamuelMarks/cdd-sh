.PHONY: test build build_wasm clean docs

test: build
	go test -coverprofile=coverage.out $$(go list ./... | grep -v /scripts)
	./test.sh
	./tests/test.sh

build:
	mkdir -p bin
	cp cdd.sh bin/cdd-sh
	chmod +x bin/cdd-sh

build_wasm:
	mkdir -p wasm_build
	GOOS=wasip1 GOARCH=wasm go build -o wasm_build/cdd-sh.wasm main.go

clean:
	rm -rf bin wasm_build

docs:
	@echo "Generating API docs with Doxygen..."
	@mkdir -p build/api_docs
	@( echo "PROJECT_NAME = cdd-sh" ; \
	   echo "INPUT = src lib internal cdd.sh main.go" ; \
	   echo "OUTPUT_DIRECTORY = build/api_docs" ; \
	   echo "RECURSIVE = YES" ; \
	   echo "GENERATE_LATEX = NO" ; \
	   echo "GENERATE_HTML = YES" ; \
	   echo "HTML_OUTPUT = html" ) | doxygen -
	@mkdir -p docs
	@rm -rf docs/html
	@cd docs && ln -s ../build/api_docs/html html

