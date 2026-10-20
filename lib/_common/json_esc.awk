# @file lib/_common/json_esc.awk
# @description Shared AWK string escaping helper for safe JSON serialization.

# json_esc escapes backslashes, double quotes, tabs, carriage returns, and newlines.
# @param s - The raw input string to escape.
# @return The JSON-escaped string.
function json_esc(s) {
	gsub(/\\/, "\\\\", s)
	gsub(/"/, "\\\"", s)
	gsub(/\t/, "\\t", s)
	gsub(/\r/, "\\r", s)
	gsub(/\n/, "\\n", s)
	return s
}
