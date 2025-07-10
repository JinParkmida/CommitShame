#!/usr/bin/env bash
# Plugin: No TODO Comments
# Shames users for committing TODO comments

check_todo_comments() {
  local has_todo=0
  
  # Check staged files for TODO comments
  while IFS= read -r -d '' file; do
    if git diff --cached "$file" | grep -qi "TODO"; then
      has_todo=1
      break
    fi
  done < <(git diff --cached --name-only -z)
  
  if (( has_todo == 1 )); then
    echo "🛑 Commit-Shame Bot: \"Hey $(git config user.name || echo 'Developer'), your code is so incomplete, even TODO comments are embarrassed!\""
    echo "   TODO comments found in staged changes. Finish your work!"
    return 1
  fi
  
  return 0
}

# Only run if plugin is enabled
if [[ "$ENABLE_NO_TODO" == "true" ]]; then
  check_todo_comments
fi 