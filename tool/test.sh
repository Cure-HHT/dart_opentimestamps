#!/bin/bash

# Test script for dart_opentimestamps

set -e  # Exit on any error

# Parse command line arguments
CONCURRENCY="8"

while [[ $# -gt 0 ]]; do
  case $1 in
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--concurrency N]"
      echo "  --concurrency N    Set test concurrency (default: 8)"
      exit 1
      ;;
  esac
done

# Build dart test command
TEST_CMD="dart test"

if [ -n "$CONCURRENCY" ]; then
  TEST_CMD="$TEST_CMD --concurrency=$CONCURRENCY"
  echo "Setting concurrency to: $CONCURRENCY"
fi

# Run all tests
echo "Running all tests..."
$TEST_CMD

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
