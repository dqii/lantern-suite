count=$(psql -h postgresql -U postgres -t -A -c "SELECT COUNT(*) FROM pg_available_extensions WHERE name IN ('lantern', 'lantern_extras', 'pg_cron', 'pg_stat_statements');")
echo "Count: $count"
if echo "$count" | grep -q "ERROR"; then
  echo "Failed to retrieve extension count" && exit 1
elif [ "$count" -ne 4 ]; then
  echo "Extension check failed" && exit 1
else
  echo "Extension check passed"
fi