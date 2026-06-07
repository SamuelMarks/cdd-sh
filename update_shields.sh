#!/bin/sh
set -eu

echo "Running tests..."
tests/test.sh

echo "Updating badges..."
go run scripts/update_badges.go

echo "Updated README.md with dynamically calculated test coverage and doc coverage shields."
