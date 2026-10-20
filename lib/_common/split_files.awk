# @file lib/_common/split_files.awk
# @description Splits a multi-file stream delimited by ###FILE###<filename> markers into individual files within `dir`.
/^###FILE###/ {
  if (out_file != "") {
    close(out_file)
  }
  file_name = substr($0, 11)
  out_file = dir "/" file_name
  printf "" > out_file
  next
}
{
  if (out_file != "") {
    print $0 >> out_file
  }
}
END {
  if (out_file != "") {
    close(out_file)
  }
}
