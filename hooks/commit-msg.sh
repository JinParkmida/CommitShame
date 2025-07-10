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

# Allow config to override MIN_LENGTH, MAX_LENGTH, BAD_WORDS, etc.
MIN_LENGTH=${MIN_LENGTH:-10}
MAX_LENGTH=${MAX_LENGTH:-72}
BAD_WORDS=(${BAD_WORDS[@]:-${BAD_WORDS[@]}})

# Default bad commit message words
DEFAULT_BAD_WORDS=(
  "fix"
  "bug"
  "stuff"
  "things"
  "update"
  "change"
  "wip"
  "temp"
  "test"
  "asdf"
  "qwerty"
  "lol"
  "oops"
  "sorry"
  "broken"
  "hack"
  "quick"
  "fast"
  "small"
  "big"
  "huge"
  "tiny"
  "random"
  "whatever"
  "idk"
  "idc"
  "wtf"
  "omg"
  "lmao"
  "rofl"
)

# If BAD_WORDS is not set in config, use defaults
if [ ${#BAD_WORDS[@]} -eq 0 ]; then
  BAD_WORDS=("${DEFAULT_BAD_WORDS[@]}")
fi

# If CUSTOM_BAD_WORDS is set in config, append to BAD_WORDS
if [ -n "$CUSTOM_BAD_WORDS" ]; then
  IFS='|' read -ra ADD_BAD_WORDS <<< "$CUSTOM_BAD_WORDS"
  for i in "${ADD_BAD_WORDS[@]}"; do
    BAD_WORDS+=("$i")
  done
fi

# Themed insult packs for commit messages
DAD_INSULTS=(
  "Why did the commit message go to therapy? Because it had too many issues."
  "I would explain this commit message, but it's above your paygrade."
  "This message is like a dad joke: groan-worthy and unnecessary."
  "You must be a magician, because this message disappeared!"
  "This commit message is so basic, it should come with a starter kit."
)
PIRATE_INSULTS=(
  "Arrr, this commit message be smaller than a landlubber's courage!"
  "Ye call this a message? I've seen better writing on a treasure map!"
  "This message be so lost, even a compass can't find it!"
  "Shiver me timbers, this commit message is barely a ripple!"
)
SHAKESPEARE_INSULTS=(
  "Thou writ'st a message most foul and insubstantial."
  "This message, a tale told by an idiot, signifying nothing."
  "Would that thy prose were as robust as thy code is weak."
  "To commit, or not to commit: that is the question."
)
CORPORATE_INSULTS=(
  "Let's circle back on this commit message after a synergy alignment."
  "This message needs more stakeholder buy-in."
  "Your commit message is so agile, it sprinted away from clarity."
  "Let's take this offline and revisit the message in Q4."
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
  "Impressive! This commit message is so clear, even a junior dev understands it."
  "Wow! This message is the Goldilocks of commit descriptions—just right."
  "Legendary! This is the kind of commit message that makes documentation obsolete."
  "Your commit message is so good, even the linter is smiling."
  "This commit message is so perfect, it deserves a standing ovation."
)

get_commit_message() {
  cat "$1"
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
  "Did you know? Good commit messages start with a verb in present tense."
  "Tip: Use 'git commit --amend' to fix your last commit message."
  "Pro tip: Write commit messages as if you're explaining to your future self."
  "Remember: The first line should be under 50 characters!"
  "You can use 'git log --oneline' to see a history of commit messages."
  "Use 'git show' to see the full commit message and changes."
  "Tip: Conventional commits make your history more readable."
  "Did you know? You can use 'git commit -v' to include diff in message editor."
)

print_random_tip() {
  local idx=$((RANDOM % ${#RANDOM_TIPS[@]}))
  echo "💡 ${RANDOM_TIPS[$idx]}"
}

EASTER_EGGS=(
  "  _____ _                 _     _                 _ \n / ____| |               | |   | |               | |\n| |    | | ___  _   _  __| | __| | ___  _ __ ___ | |\n| |    | |/ _ \| | | |/ _` |/ _` |/ _ \| '_ ` _ \| |\n| |____| | (_) | |_| | (_| | (_| | (_) | | | | | | |\n \_____|_|\___/ \__,_|\__,_|\__,_|\___/|_| |_| |_|_|\nCommit-Shame Bot: You found the secret! Now go write better commit messages."
  "Commit-Shame Bot: This is the rarest roast. You win... nothing!"
  "Commit-Shame Bot: If you see this, buy a lottery ticket."
)

print_easter_egg() {
  local idx=$((RANDOM % ${#EASTER_EGGS[@]}))
  echo -e "${EASTER_EGGS[$idx]}"
}

check_bad_words() {
  local message="$1"
  local lower_message
  lower_message=$(echo "$message" | tr '[:upper:]' '[:lower:]')
  
  for word in "${BAD_WORDS[@]}"; do
    if [[ $lower_message =~ $word ]]; then
      return 0  # Found a bad word
    fi
  done
  return 1  # No bad words found
}

public_shame() {
  if [ -n "$WEBHOOK_URL" ] && command -v curl >/dev/null 2>&1; then
    local author message reason
    author=$(get_author_name)
    message="$1"
    reason="$2"
    curl -s -X POST -H "Content-Type: application/json" -d "{\"author\":\"$author\",\"insult\":\"$message\",\"reason\":\"$reason\"}" "$WEBHOOK_URL" >/dev/null || true
  fi
}

main() {
  local commit_file="$1"
  local message
  message=$(get_commit_message "$commit_file")
  local message_length=${#message}
  local praise_chance=$((RANDOM % 10))
  
  # Check if message is perfect length (between min and max)
  if (( message_length >= MIN_LENGTH && message_length <= MAX_LENGTH && praise_chance == 0 )); then
    echo "$(get_random_compliment)"
    local tip_chance=$((RANDOM % 8))
    if (( tip_chance == 0 )); then
      print_random_tip
    fi
    exit 0
  fi
  
  # Check for bad words
  if check_bad_words "$message"; then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   Your commit message contains forbidden words: ${BAD_WORDS[*]}"
    public_shame "$(get_random_insult)" "bad words in commit message"
    exit 1
  fi
  
  # Check length
  if (( message_length < MIN_LENGTH )); then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   Only $message_length characters; minimum is $MIN_LENGTH."
    public_shame "$(get_random_insult)" "commit message too short: $message_length"
    exit 1
  elif (( message_length > MAX_LENGTH )); then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   $message_length characters; maximum is $MAX_LENGTH."
    public_shame "$(get_random_insult)" "commit message too long: $message_length"
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
main "$1" 