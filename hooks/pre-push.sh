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

# Allow config to override DANGEROUS_BRANCHES, FORCE_PUSH_WARNING, etc.
DANGEROUS_BRANCHES=(${DANGEROUS_BRANCHES[@]:-${DANGEROUS_BRANCHES[@]}})
FORCE_PUSH_WARNING=${FORCE_PUSH_WARNING:-true}

# Default dangerous branches
DEFAULT_DANGEROUS_BRANCHES=(
  "main"
  "master"
  "develop"
  "production"
  "staging"
  "release"
)

# If DANGEROUS_BRANCHES is not set in config, use defaults
if [ ${#DANGEROUS_BRANCHES[@]} -eq 0 ]; then
  DANGEROUS_BRANCHES=("${DEFAULT_DANGEROUS_BRANCHES[@]}")
fi

# If CUSTOM_DANGEROUS_BRANCHES is set in config, append to DANGEROUS_BRANCHES
if [ -n "$CUSTOM_DANGEROUS_BRANCHES" ]; then
  IFS='|' read -ra ADD_DANGEROUS_BRANCHES <<< "$CUSTOM_DANGEROUS_BRANCHES"
  for i in "${ADD_DANGEROUS_BRANCHES[@]}"; do
    DANGEROUS_BRANCHES+=("$i")
  done
fi

# Themed insult packs for dangerous pushes
DAD_INSULTS=(
  "Why did the developer push to main? Because he couldn't find the branch!"
  "I would explain why this is dangerous, but it's above your paygrade."
  "This push is like a dad joke: groan-worthy and potentially disastrous."
  "You must be a magician, because you're about to make the code disappear!"
  "This push is so reckless, it should come with a warning label."
)
PIRATE_INSULTS=(
  "Arrr, ye be pushing to dangerous waters, matey!"
  "Ye call this safe? I've seen safer treasure hunts!"
  "This push be so reckless, even the Kraken is scared!"
  "Shiver me timbers, this push is heading for disaster!"
)
SHAKESPEARE_INSULTS=(
  "Thou push'st to branches most foul and dangerous."
  "This push, a tale told by a fool, leading to destruction."
  "Would that thy judgment were as robust as thy courage is weak."
  "To push, or not to push: that is the question of life and death."
)
CORPORATE_INSULTS=(
  "Let's circle back on this push after a risk assessment."
  "This push needs more stakeholder approval."
  "Your push is so agile, it sprinted past all safety protocols."
  "Let's take this offline and revisit the push strategy in Q4."
)

# If INSULT_PACK is set, use a different insult array
if [ -n "$INSULT_PACK" ]; then
  case "$INSULT_PACK" in
    dad)
      INSULTS+=("${DAD_INSULTS[@]}") ;;
    pirate)
      INSULTS+=("${PIRATE_INSULTS[@]}") ;;
    shakespeare)
      INSULTS+=("${SHAKESPEARE_INSULTS[@]}") ;;
    corporate)
      INSULTS+=("${CORPORATE_INSULTS[@]}") ;;
  esac
fi

COMPLIMENTS=(
  "Impressive! This push is so safe, even a safety inspector approves."
  "Wow! This push is the Goldilocks of deployments—just right."
  "Legendary! This is the kind of push that makes DevOps teams proud."
  "Your push is so good, even the CI/CD pipeline is smiling."
  "This push is so perfect, it deserves a standing ovation."
)

get_current_branch() {
  git branch --show-current
}

get_author_name() {
  git config user.name || echo "Developer"
}

get_random_insult() {
  local idx=$((RANDOM % ${#INSULTS[@]}))
  local author
  author=$(get_author_name)
  echo "Hey $author, ${INSULTS[$idx]}"
}

get_random_compliment() {
  local idx=$((RANDOM % ${#COMPLIMENTS[@]}))
  local author
  author=$(get_author_name)
  echo "Hey $author, ${COMPLIMENTS[$idx]}"
}

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

# Random Git tips
RANDOM_TIPS=(
  "Did you know? You can use 'git push --force-with-lease' for safer force pushes."
  "Tip: Always create a pull request before pushing to main."
  "Pro tip: Use feature branches to keep your main branch clean."
  "Remember: Force pushing to shared branches is like playing with fire!"
  "You can use 'git log --oneline' to see what you're about to push."
  "Use 'git status' to check what branch you're on before pushing."
  "Tip: Set up branch protection rules to prevent dangerous pushes."
  "Did you know? You can use 'git push --dry-run' to test your push."
)

print_random_tip() {
  local idx=$((RANDOM % ${#RANDOM_TIPS[@]}))
  echo "💡 ${RANDOM_TIPS[$idx]}"
}

EASTER_EGGS=(
  "  _____ _                 _     _                 _ \n / ____| |               | |   | |               | |\n| |    | | ___  _   _  __| | __| | ___  _ __ ___ | |\n| |    | |/ _ \| | | |/ _` |/ _` |/ _ \| '_ ` _ \| |\n| |____| | (_) | |_| | (_| | (_| | (_) | | | | | | |\n \_____|_|\___/ \__,_|\__,_|\__,_|\___/|_| |_| |_|_|\nCommit-Shame Bot: You found the secret! Now go push safely."
  "Commit-Shame Bot: This is the rarest roast. You win... nothing!"
  "Commit-Shame Bot: If you see this, buy a lottery ticket."
)

print_easter_egg() {
  local idx=$((RANDOM % ${#EASTER_EGGS[@]}))
  echo -e "${EASTER_EGGS[$idx]}"
}

is_dangerous_branch() {
  local branch="$1"
  for dangerous in "${DANGEROUS_BRANCHES[@]}"; do
    if [[ "$branch" == "$dangerous" ]]; then
      return 0  # It's dangerous
    fi
  done
  return 1  # It's safe
}

is_force_push() {
  local remote="$1"
  local branch="$2"
  # Check if this is a force push by comparing local and remote
  local local_commit
  local remote_commit
  local_commit=$(git rev-parse HEAD)
  remote_commit=$(git rev-parse "origin/$branch" 2>/dev/null || echo "")
  
  if [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
    # Check if we're rewriting history
    if ! git merge-base --is-ancestor "$remote_commit" "$local_commit" 2>/dev/null; then
      return 0  # It's a force push
    fi
  fi
  return 1  # It's not a force push
}

public_shame() {
  if [ -n "$WEBHOOK_URL" ] && command -v curl >/dev/null 2>&1; then
    local author message reason
    author=$(get_author_name)
    message="$1"
    reason="$2"
    curl -s -X POST -H "Content-Type: application/json" -d '{"author":"'$author'","insult":"'$message'","reason":"'$reason'"}' "$WEBHOOK_URL" >/dev/null || true
  fi
}

main() {
  local current_branch
  current_branch=$(get_current_branch)
  local praise_chance=$((RANDOM % 10))
  
  # Check if pushing to a safe branch
  if ! is_dangerous_branch "$current_branch" && (( praise_chance == 0 )); then
    echo "$(get_random_compliment)"
    local tip_chance=$((RANDOM % 8))
    if (( tip_chance == 0 )); then
      print_random_tip
    fi
    exit 0
  fi
  
  # Check for dangerous branch
  if is_dangerous_branch "$current_branch"; then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   You're pushing to a dangerous branch: $current_branch"
    echo "   Dangerous branches: ${DANGEROUS_BRANCHES[*]}"
    public_shame "$(get_random_insult)" "pushing to dangerous branch: $current_branch"
    exit 1
  fi
  
  # Check for force push if enabled
  if [ "$FORCE_PUSH_WARNING" = "true" ] && is_force_push "$1" "$current_branch"; then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   You're attempting a force push to $current_branch!"
    echo "   This could rewrite history and break other developers' work."
    public_shame "$(get_random_insult)" "force push to $current_branch"
    exit 1
  fi
  
  case "${SHAME_LEVEL:-sarcastic}" in
    gentle)
      INSULTS=("${GENTLE_INSULTS[@]}")
      ;;
    savage)
      INSULTS=("${SAVAGE_INSULTS[@]}")
      ;;
    # sarcastic or default: use full list
  esac
  
  increment_shame_count
  print_leaderboard
  local tip_chance=$((RANDOM % 8))
  if (( tip_chance == 0 )); then
    print_random_tip
  fi
  local egg_chance=$((RANDOM % 100))
  if (( egg_chance == 0 )); then
    print_easter_egg
    exit 1
  fi
  exit 0
}

run_plugins
main "$@" 