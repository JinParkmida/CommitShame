#!/usr/bin/env bash
# Test coverage plugin for Commit-Shame Bot
# This plugin checks if staged files have adequate test coverage

set -e

# Check if test coverage is enabled
if [ "${ENABLE_TEST_COVERAGE:-false}" != "true" ] && [ "${TEST_COVERAGE_ENABLED:-false}" != "true" ]; then
  exit 0
fi

# Get staged files
STAGED_FILES=$(git diff --cached --name-only)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Check for test files
TEST_FILES=()
SOURCE_FILES=()

for file in $STAGED_FILES; do
  # Skip binary files
  if git diff --cached --numstat "$file" | awk '{if ($1 == "-" || $2 == "-") exit 1}'; then
    continue
  fi
  
  # Identify test files
  if [[ "$file" =~ test|spec|_test\.|\.test\. ]]; then
    TEST_FILES+=("$file")
  else
    # Identify source files (basic detection)
    if [[ "$file" =~ \.(js|ts|py|java|c|cpp|go|rb|php)$ ]]; then
      SOURCE_FILES+=("$file")
    fi
  fi
done

# Check if we have source files but no test files
if [ ${#SOURCE_FILES[@]} -gt 0 ] && [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "🛑 Commit-Shame Bot: \"Your code is so untested, even a QA engineer would cry!\""
  echo "   Source files without tests:"
  for file in "${SOURCE_FILES[@]}"; do
    echo "   - $file"
  done
  echo "   Tip: Write tests for your code to avoid bugs"
  exit 1
fi

# Check test to source ratio (basic heuristic)
if [ ${#SOURCE_FILES[@]} -gt 0 ] && [ ${#TEST_FILES[@]} -gt 0 ]; then
  RATIO=$(echo "scale=2; ${#TEST_FILES[@]} / ${#SOURCE_FILES[@]}" | bc 2>/dev/null || echo "0")
  if (( $(echo "$RATIO < 0.5" | bc -l 2>/dev/null || echo "1") )); then
    echo "🛑 Commit-Shame Bot: \"Your test coverage is so low, even a broken clock has better accuracy!\""
    echo "   Test to source ratio: $RATIO (recommended: >= 0.5)"
    echo "   Source files: ${#SOURCE_FILES[@]}, Test files: ${#TEST_FILES[@]}"
    echo "   Tip: Aim for at least one test file per source file"
    exit 1
  fi
fi

exit 0 