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

# Allow config to override MIN_LENGTH, FORBIDDEN_WORDS, INSULTS, etc.
MIN_LENGTH=${MIN_LENGTH:-10}
FORBIDDEN_WORDS=(${FORBIDDEN_WORDS[@]:-fix stuff wip temp})
INSULTS=(${INSULTS[@]:-${INSULTS[@]}})

# If INSULT_PACK is set, use a different insult array (Dad, Pirate, etc.)
if [ -n "$INSULT_PACK" ]; then
  case "$INSULT_PACK" in
    dad)
      INSULTS+=(
        "Why did the developer go broke? Because he used up all his cache."
        "I would explain this message, but it's above your paygrade."
        "This commit message is like a dad joke: groan-worthy and unnecessary."
      )
      ;;
    pirate)
      INSULTS+=(
        "Arrr, this message be smaller than a landlubber's courage!"
        "Ye call this a commit message? I've seen bigger tales in a cup of grog!"
      )
      ;;
    shakespeare)
      INSULTS+=(
        "Thou commit'st a message most foul and insubstantial."
        "This message, a tale told by an idiot, signifying nothing."
      )
      ;;
  esac
fi

# If CUSTOM_INSULTS is set in config, append to INSULTS
if [ -n "$CUSTOM_INSULTS" ]; then
  IFS='|' read -ra ADD_INSULTS <<< "$CUSTOM_INSULTS"
  for i in "${ADD_INSULTS[@]}"; do
    INSULTS+=("$i")
  done
fi

COMPLIMENTS=(
  "Outstanding! This commit message is poetry in motion."
  "Bravo! Your message is so clear, even future you will understand it."
  "Legendary! This is the kind of message that makes bots obsolete."
  "Your message is so good, even the linter is smiling."
  "This commit message is so perfect, it deserves a standing ovation."
)

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

# Themed insult packs
DAD_INSULTS=(
  "Why did the developer go broke? Because he used up all his cache."
  "I would explain this message, but it's above your paygrade."
  "This commit message is like a dad joke: groan-worthy and unnecessary."
  "You must be a magician, because this message disappeared!"
  "This message is so basic, it should come with a starter kit."
)
PIRATE_INSULTS=(
  "Arrr, this message be smaller than a landlubber's courage!"
  "Ye call this a commit message? I've seen bigger tales in a cup of grog!"
  "This message be so lost, even a treasure map can't find it!"
  "Shiver me timbers, this message is barely a ripple!"
)
SHAKESPEARE_INSULTS=(
  "Thou commit'st a message most foul and insubstantial."
  "This message, a tale told by an idiot, signifying nothing."
  "Would that thy prose were as robust as thy code is weak."
  "Commit, or not commit: that is the question."
)
CORPORATE_INSULTS=(
  "Let's circle back on this message after a synergy alignment."
  "This commit message needs more stakeholder buy-in."
  "Your message is so agile, it sprinted away from the requirements."
  "Let's take this offline and revisit the message in Q4."
)

# Random Git tips
RANDOM_TIPS=(
  "Did you know? You can use 'git commit --amend' to fix your last commit message."
  "Tip: Use 'git stash' to save your work-in-progress without committing."
  "Pro tip: 'git log --oneline --graph' gives you a beautiful commit tree."
  "Remember: Small, focused commits are easier to review!"
  "You can use 'git bisect' to find which commit broke your code."
  "Use 'git blame' to find out who wrote that line (and shame them in person)."
  "Tip: 'git reflog' can save you from almost any Git disaster."
  "Did you know? You can stage parts of files with 'git add -p'."
)

print_random_tip() {
  local idx=$((RANDOM % ${#RANDOM_TIPS[@]}))
  echo "💡 ${RANDOM_TIPS[$idx]}"
}

EASTER_EGGS=(
  "  _____ _                 _     _                 _ \n / ____| |               | |   | |               | |\n| |    | | ___  _   _  __| | __| | ___  _ __ ___ | |\n| |    | |/ _ \| | | |/ _` |/ _` |/ _ \| '_ ` _ \| |\n| |____| | (_) | |_| | (_| | (_| | (_) | | | | | | |\n \_____|_|\___/ \__,_|\__,_|\__,_|\___/|_| |_| |_|_|\nCommit-Shame Bot: You found the secret! Now go write better messages."
  "Commit-Shame Bot: This is the rarest roast. You win... nothing!"
  "Commit-Shame Bot: If you see this, buy a lottery ticket."
)

print_easter_egg() {
  local idx=$((RANDOM % ${#EASTER_EGGS[@]}))
  echo -e "${EASTER_EGGS[$idx]}"
}

detect_main_language() {
  local ext
  ext=$(find . -type f | grep -E '\.([a-zA-Z0-9]+)$' | sed -E 's/.*\.([a-zA-Z0-9]+)$/\1/' | sort | uniq -c | sort -nr | head -1 | awk '{print $2}')
  echo "$ext"
}

add_language_insults() {
  local lang_ext
  lang_ext=$(detect_main_language)
  case "$lang_ext" in
    py)
      INSULTS+=(
        "This Python code is so slow, even the GIL is bored."
        "Your Python is so unpythonic, even the snake is hissing."
      )
      ;;
    js)
      INSULTS+=(
        "This JavaScript is so loose, even 'use strict' gave up."
        "Your JS is so callback-heavy, it's stuck in 2010."
      )
      ;;
    java)
      INSULTS+=(
        "This Java code is so verbose, it needs a table of contents."
        "Your Java is so enterprisey, it needs a business card."
      )
      ;;
    c)
      INSULTS+=(
        "This C code is so unsafe, even malloc is scared."
        "Your C is so old-school, it runs on punch cards."
      )
      ;;
    cpp)
      INSULTS+=(
        "This C++ is so complex, even Bjarne can't explain it."
        "Your C++ is so templated, it's a work of abstract art."
      )
      ;;
    go)
      INSULTS+=(
        "This Go code is so simple, even a gopher could write it."
        "Your Go is so unopinionated, it can't decide on anything."
      )
      ;;
    rb)
      INSULTS+=(
        "This Ruby is so magical, even Rails can't save it."
        "Your Ruby is so dynamic, it changes shape when you look at it."
      )
      ;;
  esac
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

# Lint for conventional commits if enabled
main() {
  local msg_file="$1"
  local msg
  msg=$(head -n1 "$msg_file" | tr -d '\r\n')

  # Lint for conventional commits if enabled
  if [[ "$LINT_CONVENTIONAL" == "true" ]]; then
    if ! [[ "$msg" =~ ^(feat|fix|docs|style|refactor|perf|test|chore)(\([a-zA-Z0-9_-]+\))?:\ .+ ]]; then
      echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
      echo "   Commit message must follow Conventional Commits (e.g., 'feat(ui): Add button')."
      increment_shame_count
      print_leaderboard
      local tip_chance=$((RANDOM % 8))
      if (( tip_chance == 0 )); then
        print_random_tip
      fi
      exit 1
    fi
  fi

  # Check length
  if (( ${#msg} < MIN_LENGTH )); then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   Message too short: '${msg}'"
    exit 1
  fi

  # Check forbidden words
  for word in "${FORBIDDEN_WORDS[@]}"; do
    if [[ "${msg,,}" =~ $word ]]; then
      echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
      echo "   Forbidden word '$word' found in message."
      exit 1
    fi
  done

  # Check capitalization
  if [[ ! "$msg" =~ ^[A-Z] ]]; then
    echo "🛑 Commit-Shame Bot: \"$(get_random_insult)\""
    echo "   Message must start with a capital letter."
    exit 1
  fi

  add_language_insults

  GENTLE_INSULTS=(
    "This message is a little shy, but that's okay."
    "A small message, but every word counts!"
    "Short and sweet—sometimes less is more."
    "A modest message—at least you tried!"
  )
  SAVAGE_INSULTS=(
    "This message is so bad, even Git wants to delete itself."
    "I've seen better commit messages in ransom notes."
    "This message is the reason code reviews exist."
    "If this message were a bug, it would be a feature."
    "Your message is so cursed, Stack Overflow banned it."
  )

  case "${SHAME_LEVEL:-sarcastic}" in
    gentle)
      INSULTS=("${GENTLE_INSULTS[@]}")
      ;;
    savage)
      INSULTS=("${SAVAGE_INSULTS[@]}")
      ;;
    # sarcastic or default: use full list
  esac

  local praise_chance=$((RANDOM % 10))
  if (( ${#msg} > 30 )) && [[ "$msg" =~ ^[A-Z] ]] && ! [[ "${msg,,}" =~ (fix|stuff|wip|temp) ]] || (( praise_chance == 0 )); then
    echo "$(get_random_compliment)"
    local tip_chance=$((RANDOM % 8))
    if (( tip_chance == 0 )); then
      print_random_tip
    fi
    exit 0
  fi

  local egg_chance=$((RANDOM % 100))
  if (( egg_chance == 0 )); then
    print_easter_egg
    exit 1
  fi

  exit 0
}

main "$1" 