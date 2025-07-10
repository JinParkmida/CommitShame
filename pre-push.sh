#!/usr/bin/env bash
set -e

# YAML config auto-detection/merging
parse_yaml() {
  # Only supports simple key: value pairs (no nesting)
  local yaml_file="$1"
  while IFS= read -r line; do
    if [[ $line =~ ^([a-zA-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Remove quotes
      value="${value%\"}"
      value="${value#\"}"
      export "${key^^}=$value"
    fi
  done < "$yaml_file"
}

if [ -f .shamerc ]; then
  if command -v yq >/dev/null 2>&1; then
    # Use yq for full YAML parsing
    eval "$(yq eval '. as $cfg ireduce ({}; . *+ $cfg) | to_entries | .[] | "export \(.key | ascii_upcase)=\(.value)"' .shamerc)"
  else
    # Fallback to minimal Bash parser
    parse_yaml .shamerc
  fi
elif [ -f .commit-shame-config ]; then
  # shellcheck disable=SC1090
  source .commit-shame-config
fi

# Plugin auto-discovery/loader
run_plugins() {
  if [ -d hooks.d ]; then
    for plugin in hooks.d/*.sh; do
      [ -x "$plugin" ] || continue
      plugin_name=$(basename "$plugin" .sh)
      # Check if plugin is enabled via ENABLE_<PLUGIN>=true or plugins: in config
      enabled_var="ENABLE_${plugin_name^^}"
      if [ "${!enabled_var}" = "true" ]; then
        "$plugin" || exit 1
      fi
      # Also check for YAML plugins: list (PLUGIN_ENABLED)
      if [ "$(eval echo \${plugin_name}_ENABLED)" = "true" ]; then
        "$plugin" || exit 1
      fi
    done
  fi
}

get_author_name() {
  git config user.name || echo "Developer"
}

INSULTS=(
  "Pushing to main? Bold move, let's see if it pays off."
  "This push is so reckless, even Git is sweating."
  "Direct to master? That's one way to live dangerously."
  "This many commits at once? Are you trying to break CI?"
  "Your push is so big, it needs a warning label."
)

STATS_FILE="$(git rev-parse --git-dir)/commit-shame-stats"
increment_shame_count() {
  local author
  author=$(get_author_name)
  mkdir -p "$(dirname "$STATS_FILE")"
  if grep -q "^$author:" "$STATS_FILE" 2>/dev/null; then
    awk -v name="$author" -F: '{if ($1==name) {$2+=1} print $1":"$2}' "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"
  else
    echo "$author:1" >> "$STATS_FILE"
  fi
}

print_leaderboard() {
  echo "\n🏆 Hall of Shame (Top 5):"
  sort -t: -k2 -nr "$STATS_FILE" 2>/dev/null | head -5 | nl -w1 -s'. '
}

RANDOM_TIPS=(
  "Did you know? You can use 'git push --force-with-lease' instead of --force for safety."
  "Tip: Protect your main branch with branch protection rules!"
  "Pro tip: Push small, frequent commits for easier rollbacks."
  "Remember: Review your changes before pushing!"
)
print_random_tip() {
  local idx=$((RANDOM % ${#RANDOM_TIPS[@]}))
  echo "💡 ${RANDOM_TIPS[$idx]}"
}

main() {
  local ref branch commit_count=0
  while read -r local_ref local_sha remote_ref remote_sha; do
    ref=${remote_ref##refs/heads/}
    branch=$ref
    if [[ "$branch" =~ ^(main|master)$ ]]; then
      echo "🛑 Commit-Shame Bot: Hey $(get_author_name), ${INSULTS[0]}"
      increment_shame_count
      print_leaderboard
      (( RANDOM % 8 == 0 )) && print_random_tip
      exit 1
    fi
    # Count commits being pushed
    if [ "$remote_sha" = "0000000000000000000000000000000000000000" ]; then
      # New branch, count all commits
      commit_count=$(git rev-list --count "$local_sha")
    else
      commit_count=$(git rev-list --count "$local_sha" --not "$remote_sha")
    fi
    if (( commit_count > 10 )); then
      echo "🛑 Commit-Shame Bot: Hey $(get_author_name), ${INSULTS[3]} ($commit_count commits)"
      increment_shame_count
      print_leaderboard
      (( RANDOM % 8 == 0 )) && print_random_tip
      exit 1
    fi
  done
  exit 0
}

run_plugins
main 