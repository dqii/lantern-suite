#!/bin/bash

PG_VERSION=15

declare -a extensions=("lantern" "lantern_extras" "pg_cron" "pg_stat_statements" "vector" "zombodb")

missing_files=()
for ext in "${extensions[@]}"; do
  if ! [ -f "/usr/lib/postgresql/$PG_VERSION/lib/${ext}.so" ]; then
    missing_files+=("/usr/lib/postgresql/$PG_VERSION/lib/${ext}.so")
  fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
  echo "Shared object files missing for the following extensions:"
  for file in "${missing_files[@]}"; do
    echo "$file"
  done
  exit 1
else
  echo "All necessary shared object files are present"
fi
