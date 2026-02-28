BEGIN {
  while ((getline < new_file) > 0) {
    if ($0 ~ /^# @(function|class|webhook) /) {
      block_name = $3
      in_new = 1
      new_blocks[block_name] = $0 "\n"
    } else if (in_new) {
      new_blocks[block_name] = new_blocks[block_name] $0 "\n"
      if ($0 ~ /^}$/) {
        in_new = 0
      }
      if ($0 ~ /^# @required / || $0 ~ /^# @property / || $0 ~ /^# @description / || $0 ~ /^# @method /) {
      } else if ($0 == "" || $0 ~ /^$/) {
        if (block_name ~ /^[A-Z]/ || $0 ~ /^handle_webhook_/) {
          in_new = 0
        }
      }
    } else {
      new_header = new_header $0 "\n"
    }
  }
}
{
  if ($0 ~ /^# @(function|class|webhook) /) {
    block_name = $3
    in_old = 1
    deleted = 0
    if (block_name in new_blocks) {
      replaced[block_name] = 1
      printf "%s", new_blocks[block_name]
    } else {
      deleted = 0
      print $0
    }
  } else if (in_old) {
    if (!deleted && !(block_name in replaced)) {
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