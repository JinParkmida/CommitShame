#!/usr/bin/env bash
# Security scan plugin for Commit-Shame Bot
# This plugin scans staged files for common security issues

set -e

# Check if security scan is enabled
if [ "${ENABLE_SECURITY_SCAN:-false}" != "true" ] && [ "${SECURITY_SCAN_ENABLED:-false}" != "true" ]; then
  exit 0
fi

# Get staged files
STAGED_FILES=$(git diff --cached --name-only)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Check for common security issues
SECURITY_ISSUES=()

for file in $STAGED_FILES; do
  # Skip binary files
  if git diff --cached --numstat "$file" | awk '{if ($1 == "-" || $2 == "-") exit 1}'; then
    continue
  fi
  
  # Check for hardcoded passwords
  if git diff --cached "$file" | grep -i "password.*=.*['\"][^'\"]*['\"]" >/dev/null; then
    SECURITY_ISSUES+=("Hardcoded password in $file")
  fi
  
  # Check for API keys
  if git diff --cached "$file" | grep -i "api.*key.*=.*['\"][^'\"]*['\"]" >/dev/null; then
    SECURITY_ISSUES+=("API key in $file")
  fi
  
  # Check for private keys
  if git diff --cached "$file" | grep -i "private.*key.*=.*['\"][^'\"]*['\"]" >/dev/null; then
    SECURITY_ISSUES+=("Private key in $file")
  fi
  
  # Check for database credentials
  if git diff --cached "$file" | grep -i "database.*password.*=.*['\"][^'\"]*['\"]" >/dev/null; then
    SECURITY_ISSUES+=("Database password in $file")
  fi
done

if [ ${#SECURITY_ISSUES[@]} -gt 0 ]; then
  echo "🛑 Commit-Shame Bot: \"Your code is so insecure, even a script kiddie could hack it!\""
  echo "   Security issues found:"
  for issue in "${SECURITY_ISSUES[@]}"; do
    echo "   - $issue"
  done
  echo "   Tip: Use environment variables for sensitive data"
  exit 1
fi

exit 0 