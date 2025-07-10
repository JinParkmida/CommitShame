#!/usr/bin/env bash
set -e

echo "🛠 Installing Commit-Shame Bot hooks..."

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "❌ Not a Git repository. Run this in your project root."
  exit 1
fi

hooksDir="$(git rev-parse --git-dir)/hooks"
mkdir -p "$hooksDir"

cp pre-commit.sh "$hooksDir/pre-commit"
cp commit-msg.sh "$hooksDir/commit-msg"
chmod +x "$hooksDir/pre-commit" "$hooksDir/commit-msg"

cp pre-push.sh "$hooksDir/pre-push"
chmod +x "$hooksDir/pre-push"

echo "✅ Commit-Shame Bot hooks installed in $hooksDir"
echo "   - pre-commit (diff size shaming)"
echo "   - commit-msg (message shaming)" 