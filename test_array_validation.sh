#!/bin/sh
# @file test_array_validation.sh
# @description Tests nested array reference schema validation from the repository root.
# shellcheck disable=SC1091
. "${LIBSCRIPT_ROOT_DIR:-.}/lib/env.sh"

# shellcheck disable=SC1091
. ./emitted_classes_array.sh
payload='{"books": [{"title": "1984"}, {"title": "Brave New World"}]}'
if validate_Library "$payload"; then
	echo "Valid library passed!"
else
	echo "FAIL valid library"
	exit 1
fi

bad_payload='{"books": [{"title": "1984"}, {}]}'
if validate_Library "$bad_payload"; then
	echo "FAIL - bad library should fail"
	exit 1
else
	echo "Bad library correctly failed!"
fi
