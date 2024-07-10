#!/bin/bash

# Function to run a test and check its result
run_test() {
  local test_name="$1"
  local test_command="$2"

  echo "Running $test_name..."
  if $test_command; then
    echo "$test_name PASSED"
  else
    echo "$test_name FAILED"
    return 1
  fi
}

# Initialize a variable to track overall test success
overall_success=true

# Test 1: Check PostgreSQL extension count
run_test "Check PostgreSQL extension count" ./test/extension-count.sh || overall_success=false

# Test 2: Check for .so files presence
run_test "Check .so files presence" ./test/so-files-present.sh || overall_success=false

# Exit with an error if any test failed
if [ "$overall_success" = false ]; then
  echo "One or more tests failed."
  exit 1
else
  echo "All tests passed successfully."
fi
