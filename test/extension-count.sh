#!/bin/bash

available_extensions=$(PGPASSWORD=postgres psql -U postgres -t -A -c "SELECT name FROM pg_available_extensions WHERE name IN ('lantern', 'lantern_extras', 'pg_cron', 'pg_stat_statements', 'vector', 'zombodb');")

required_extensions=("lantern" "lantern_extras" "pg_cron" "pg_stat_statements" "vector" "zombodb")
missing_extensions=()
for ext in "${required_extensions[@]}"; do
  if ! echo "$available_extensions" | grep -q "^${ext}$"; then
    missing_extensions+=("$ext")
  fi
done

if [ ${#missing_extensions[@]} -ne 0 ]; then
  echo "Extension check failed. Missing extensions: ${missing_extensions[*]}"
  exit 1
else
  echo "Extension check passed"
fi