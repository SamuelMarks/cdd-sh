# @file lib/_common/arazzo_expr.jq
# @description JQ helper functions for evaluating Arazzo 1.1.0 runtime expressions, JSONPath selectors, and simple/jsonpath criteria.

# parse_subpath($s) splits a dot-separated or JSON Pointer subpath into a jq path array.
# @param $s - Subpath string (dot-separated or JSON Pointer).
# @return Array of path segments.
def parse_subpath($s):
  if $s == "" or $s == null then []
  elif ($s | startswith("#/")) then
    ($s | ltrimstr("#/") | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .)))
  elif ($s | contains("#/")) then
    ($s | split("#/")) as $halves |
    (($halves[0] | ltrimstr(".") | if . == "" then [] else split(".") end) +
     ($halves[1] | split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))))
  else
    ($s | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end)
  end;

# lookup_ci($obj; $k) performs a case-insensitive key lookup on a JSON object.
# @param $obj - JSON object to query.
# @param $k - Key name to look up case-insensitively.
# @return Matched property value or null.
def lookup_ci($obj; $k):
  if ($obj | type) != "object" then null
  elif ($obj | has($k)) then $obj[$k]
  else
    ($k | ascii_downcase) as $lk |
    ([ $obj | to_entries[] | select((.key | ascii_downcase) == $lk) | .value ][0] // null)
  end;

# eval_path($root; $p) traverses $root along path array $p using case-insensitive object lookup.
# @param $root - Root JSON value to traverse.
# @param $p - Array of path segments.
# @return Traversed value or null.
def eval_path($root; $p):
  reduce $p[] as $seg ($root;
    if . == null then null
    elif (. | type) == "object" then lookup_ci(.; ($seg | tostring))
    elif (. | type) == "array" and ($seg | type) == "number" then .[$seg]
    else null end
  );

# eval_runtime_expr($expr) evaluates an Arazzo 1.1.0 runtime expression against the workflow state object.
# @param $expr - Runtime expression string.
# @return Evaluated scalar or JSON-serialized string.
def eval_runtime_expr($expr):
  if $expr == "$url" then (.current.url // "")
  elif $expr == "$method" then (.current.method // "")
  elif $expr == "$statusCode" then (.current.statusCode // 200)
  elif $expr == "$self" then (.self // "")
  elif ($expr | startswith("$request.header.")) then
    lookup_ci(.current.request.header // {}; ($expr | ltrimstr("$request.header.")))
  elif ($expr | startswith("$request.query.")) then
    lookup_ci(.current.request.query // {}; ($expr | ltrimstr("$request.query.")))
  elif ($expr | startswith("$request.path.")) then
    lookup_ci(.current.request.path // {}; ($expr | ltrimstr("$request.path.")))
  elif $expr == "$request.body" then (.current.request.body // {})
  elif ($expr | startswith("$request.body")) then
    eval_path(.current.request.body; parse_subpath($expr | ltrimstr("$request.body")))
  elif ($expr | startswith("$response.header.")) then
    lookup_ci(.current.response.header // {}; ($expr | ltrimstr("$response.header.")))
  elif $expr == "$response.body" then (.current.response.body // {})
  elif ($expr | startswith("$response.body")) then
    eval_path(.current.response.body; parse_subpath($expr | ltrimstr("$response.body")))
  elif ($expr | startswith("$message.header.")) then
    lookup_ci(.current.message.header // {}; ($expr | ltrimstr("$message.header.")))
  elif $expr == "$message.payload" then (.current.message.payload // {})
  elif ($expr | startswith("$message.payload")) then
    eval_path(.current.message.payload; parse_subpath($expr | ltrimstr("$message.payload")))
  elif ($expr | startswith("$inputs.")) then
    eval_path(.inputs; parse_subpath($expr | ltrimstr("$inputs.")))
  elif $expr == "$inputs" then (.inputs // {})
  elif ($expr | startswith("$outputs.")) then
    eval_path(.outputs; parse_subpath($expr | ltrimstr("$outputs.")))
  elif $expr == "$outputs" then (.outputs // {})
  elif ($expr | startswith("$steps.")) then
    eval_path(.steps; parse_subpath($expr | ltrimstr("$steps.")))
  elif ($expr | startswith("$workflows.")) then
    eval_path(.workflows; parse_subpath($expr | ltrimstr("$workflows.")))
  elif ($expr | startswith("$sourceDescriptions.")) then
    eval_path(.sourceDescriptions; parse_subpath($expr | ltrimstr("$sourceDescriptions.")))
  elif ($expr | startswith("$components.")) then
    eval_path(.components; parse_subpath($expr | ltrimstr("$components.")))
  else
    $expr
  end |
  if . == null then ""
  elif (type == "object" or type == "array") then tojson
  else tostring end;

# eval_jsonpointer_selector($ptr) extracts a value from input JSON using an RFC 6901 JSON Pointer.
# @param $ptr - RFC 6901 JSON Pointer string.
# @return Extracted value as string or JSON string.
def eval_jsonpointer_selector($ptr):
  ($ptr | ltrimstr("#") | ltrimstr("/") | if . == "" then [] else (split("/") | map(gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))) end) as $p |
  getpath($p) | if . == null then "" elif (type == "object" or type == "array") then tojson else tostring end;

# eval_jsonpath_selector($jp) extracts a value from input JSON using an RFC 9535 JSONPath expression.
# @param $jp - JSONPath selector string.
# @return Extracted value as string or JSON string.
def eval_jsonpath_selector($jp):
  if ($jp | startswith("$..")) then
    ($jp | ltrimstr("$..")) as $key |
    ([ .. | objects | select(has($key)) | .[$key] ][0] // "")
  else
    ($jp | ltrimstr("$") | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end) as $p |
    getpath($p)
  end |
  if . == null then "" elif (type == "object" or type == "array") then tojson else tostring end;

# eval_jsonpath_criterion($jp) evaluates a JSONPath filter or path existence check on input JSON.
# @param $jp - JSONPath condition string.
# @return Boolean true if the JSONPath condition matches, false otherwise.
def eval_jsonpath_criterion($jp):
  if ($jp | contains("[?(")) then
    if ($jp | contains("==")) then
      ($jp | split("@.")[1] | split(")")[0] | split("==")) as $parts |
      ($parts[0] | gsub(" "; "")) as $k |
      ($parts[1] | gsub(" "; "") | gsub("'"; "")) as $v |
      ([ .. | objects | select(.[$k] == $v) ] | length) > 0
    else
      (. != null and . != "" and . != [] and . != {})
    end
  else
    ($jp | ltrimstr("$") | ltrimstr(".") | split("[") | join(".") | split("]") | join("") | if . == "" then [] else (split(".") | map(select(. != "") | (tonumber? // .))) end) as $p |
    getpath($p) != null and getpath($p) != false
  end;

# trim_ws($s) strips leading and trailing whitespace and single quotes from a string.
# @param $s - String to trim.
# @return Trimmed string.
def trim_ws($s):
  $s | sub("^[ 	]+"; "") | sub("[ 	]+$"; "") | ltrimstr("'") | rtrimstr("'");

# eval_simple_atom($a) evaluates an atomic comparison expression (==, !=, >=, <=, >, <).
# @param $a - Atomic comparison string.
# @return Boolean result of the comparison.
def eval_simple_atom($a):
  trim_ws($a) as $t |
  if ($t | contains("==")) then
    ($t | split("==")) as $p |
    (trim_ws($p[0]) == trim_ws($p[1]))
  elif ($t | contains("!=")) then
    ($t | split("!=")) as $p |
    (trim_ws($p[0]) != trim_ws($p[1]))
  elif ($t | contains(">=")) then
    ($t | split(">=")) as $p |
    (((trim_ws($p[0]) | tonumber?) // 0) >= ((trim_ws($p[1]) | tonumber?) // 0))
  elif ($t | contains("<=")) then
    ($t | split("<=")) as $p |
    (((trim_ws($p[0]) | tonumber?) // 0) <= ((trim_ws($p[1]) | tonumber?) // 0))
  elif ($t | contains(">")) then
    ($t | split(">")) as $p |
    (((trim_ws($p[0]) | tonumber?) // 0) > ((trim_ws($p[1]) | tonumber?) // 0))
  elif ($t | contains("<")) then
    ($t | split("<")) as $p |
    (((trim_ws($p[0]) | tonumber?) // 0) < ((trim_ws($p[1]) | tonumber?) // 0))
  else
    ($t != "" and $t != "false" and $t != "null" and $t != "0")
  end;

# eval_simple_criterion($expr) evaluates a simple boolean expression with && and || combinators.
# @param $expr - Boolean condition string.
# @return Boolean evaluation result.
def eval_simple_criterion($expr):
  if ($expr | contains("||")) then
    any($expr | split("||")[]; eval_simple_atom(.))
  elif ($expr | contains("&&")) then
    all($expr | split("&&")[]; eval_simple_atom(.))
  else
    eval_simple_atom($expr)
  end;

# apply_payload_replacement($t; $v) sets path $t to value $v inside a JSON request payload.
# @param $t - Target JSON Pointer or JSONPath string.
# @param $v - Replacement value string or JSON.
# @return Updated JSON payload object.
def apply_payload_replacement($t; $v):
  ($t | ltrimstr("$") | ltrimstr(".") | ltrimstr("#") | ltrimstr("/") | split("[") | join("/") | split("]") | join("") | split(".") | join("/") | split("/") | map(select(. != "") | gsub("~1"; "/") | gsub("~0"; "~") | (tonumber? // .))) as $path |
  setpath($path; (($v | fromjson?) // $v));
