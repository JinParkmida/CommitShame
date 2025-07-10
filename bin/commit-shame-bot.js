#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const HOOKS = ['pre-commit', 'commit-msg', 'pre-push'];

function isGitRepo() {
  try {
    execSync('git rev-parse --git-dir', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function getGitHooksDir() {
  try {
    return execSync('git rev-parse --git-dir', { encoding: 'utf8' }).trim() + '/hooks';
  } catch {
    throw new Error('Not a Git repository. Run this in your project root.');
  }
}

function copyHook(hooksDir, hookName) {
  const sourcePath = path.join(__dirname, '..', 'hooks', hookName + '.sh');
  const destPath = path.join(hooksDir, hookName);
  
  if (!fs.existsSync(sourcePath)) {
    console.error(`❌ Hook file not found: ${sourcePath}`);
    return false;
  }
  
  try {
    fs.copyFileSync(sourcePath, destPath);
    fs.chmodSync(destPath, '755');
    return true;
  } catch (error) {
    console.error(`❌ Failed to copy ${hookName}: ${error.message}`);
    return false;
  }
}

function init() {
  console.log('🛠 Installing Commit-Shame Bot hooks...');
  
  if (!isGitRepo()) {
    console.error('❌ Not a Git repository. Run this in your project root.');
    process.exit(1);
  }
  
  const hooksDir = getGitHooksDir();
  
  // Create hooks directory if it doesn't exist
  if (!fs.existsSync(hooksDir)) {
    fs.mkdirSync(hooksDir, { recursive: true });
  }
  
  let successCount = 0;
  
  for (const hook of HOOKS) {
    if (copyHook(hooksDir, hook)) {
      successCount++;
      console.log(`✅ Installed ${hook} hook`);
    }
  }
  
  if (successCount === HOOKS.length) {
    console.log(`\n🎉 Successfully installed ${successCount} hooks in ${hooksDir}`);
    console.log('   - pre-commit (diff size shaming)');
    console.log('   - commit-msg (message shaming)');
    console.log('   - pre-push (push shaming)');
    console.log('\n💡 Create a .shamerc or .commit-shame-config file to customize behavior!');
  } else {
    console.error(`\n⚠️  Only ${successCount}/${HOOKS.length} hooks were installed successfully.`);
    process.exit(1);
  }
}

function showHelp() {
  console.log(`
Commit-Shame Bot - The Ultimate Git Productivity Solution (That Roasts You)

Usage:
  commit-shame-bot init    Install hooks in current repository
  commit-shame-bot --help  Show this help message

Examples:
  commit-shame-bot init    # Install all hooks
  cd /path/to/repo && commit-shame-bot init  # Install in specific repo

Configuration:
  Create .shamerc (YAML) or .commit-shame-config (Bash) to customize:
  - min_lines, max_lines
  - insult_pack (dad, pirate, shakespeare, corporate)
  - shame_level (gentle, sarcastic, savage)
  - plugins in hooks.d/

For more info: https://github.com/yourusername/CommitShame
`);
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    showHelp();
    return;
  }
  
  if (args[0] === 'init') {
    init();
  } else {
    console.error('❌ Unknown command. Use --help for usage information.');
    process.exit(1);
  }
}

if (require.main === module) {
  main();
} 