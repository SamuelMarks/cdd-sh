.PHONY: test build build_wasm clean

test: build
	go test -coverprofile=coverage.out ./...
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
