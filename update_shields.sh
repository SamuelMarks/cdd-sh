#!/bin/sh
# @file update_shields.sh
# @description Runs the test suite and updates the README.md coverage badges.
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

echo "Running tests..."
tests/test.sh

echo "Updating badges..."
go run scripts/update_badges.go

echo "Updated README.md with dynamically calculated test coverage and doc coverage shields."
