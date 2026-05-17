#!/bin/sh
set -eu

echo "Running tests..."
tests/test.sh

echo "Updating badges..."
python3 scripts/update_badges.py

echo "Updated README.md with dynamically calculated test coverage and doc coverage shields."
