# @file lib/_common/merge.awk
# @description Merges newly generated annotated shell blocks (@function, @class, @webhook)
# into an existing shell script while preserving custom user functions and edits.
BEGIN {
  while ((getline < new_file) > 0) {
    if ($0 ~ /^# @(function|class|webhook|workflow) /) {
      block_name = $3
      in_new = 1
      new_blocks[block_name] = $0 "\n"
    } else if (in_new) {
      new_blocks[block_name] = new_blocks[block_name] $0 "\n"
      if ($0 ~ /^}$/) {
        in_new = 0
      } else if ($0 == "" && block_name ~ /^[A-Z]/) {
        in_new = 0
      }
    }
  }
}
{
  if ($0 ~ /^# @(function|class|webhook|workflow) /) {
    block_name = $3
    in_old = 1
    if (block_name in new_blocks) {
      replaced[block_name] = 1
      printf "%s", new_blocks[block_name]
    } else {
      print $0
    }
  } else if (in_old) {
    if (!(block_name in replaced)) {
      print $0
    }
    if ($0 ~ /^}$/ || $0 ~ /^$/) {
      in_old = 0
    }
  } else {
    print $0
  }
}
END {
  for (f in new_blocks) {
    if (!(f in replaced)) {
      printf "\n%s", new_blocks[f]
    }
  }
}
