. ./emitted_classes_array.sh
payload='{"books": [{"title": "1984"}, {"title": "Brave New World"}]}'
if validate_Library "$payload"; then echo "Valid library passed!"; else echo "FAIL valid library"; fi

bad_payload='{"books": [{"title": "1984"}, {}]}'
if validate_Library "$bad_payload"; then echo "FAIL - bad library should fail"; else echo "Bad library correctly failed!"; fi
