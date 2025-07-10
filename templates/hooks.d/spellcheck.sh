#!/usr/bin/env bash
# Spellcheck plugin for Commit-Shame Bot
# This plugin checks commit messages for spelling errors

set -e

# Check if spellcheck is enabled
if [ "${ENABLE_SPELLCHECK:-false}" != "true" ] && [ "${SPELLCHECK_ENABLED:-false}" != "true" ]; then
  exit 0
fi

# Get commit message from file
COMMIT_FILE="$1"
if [ -z "$COMMIT_FILE" ]; then
  echo "❌ Spellcheck plugin: No commit message file provided"
  exit 1
fi

MESSAGE=$(cat "$COMMIT_FILE")

# Check if aspell is available
if ! command -v aspell >/dev/null 2>&1; then
  echo "⚠️  Spellcheck plugin: aspell not found, skipping spellcheck"
  exit 0
fi

# Check spelling
MISSPELLED=$(echo "$MESSAGE" | aspell list --personal=./.git-spellcheck-dict 2>/dev/null || echo "$MESSAGE" | aspell list 2>/dev/null)

if [ -n "$MISSPELLED" ]; then
  echo "🛑 Commit-Shame Bot: \"Your commit message has more typos than a cat walking on a keyboard!\""
  echo "   Misspelled words: $MISSPELLED"
  echo "   Tip: Create a .git-spellcheck-dict file to add custom words"
  exit 1
fi

exit 0 