#!/bin/bash
# Coverage script for dart_opentimestamps

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

echo "Starting test coverage collection..."
echo "Concurrency: $CONCURRENCY"

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
dart test --chain-stack-traces --coverage=coverage --concurrency="$CONCURRENCY"

# Generate LCOV coverage report
echo "Generating LCOV report..."
dart run coverage:format_coverage --in=./coverage --package=./ --report-on=lib/ --lcov --out=coverage/lcov.info --check-ignore

# Generate HTML report
echo "Generating HTML report..."
genhtml coverage/lcov.info -o coverage/html

echo "Coverage report generated at coverage/html/index.html"
echo "Coverage process completed successfully"
exit 0
