<#!
.SYNOPSIS
  Installs Commit-Shame Bot hooks for Git (cross-platform, PowerShell).
#>
Write-Host "🛠 Installing Commit-Shame Bot hooks..." -ForegroundColor Cyan

# Check for git repo
$gitDir = git rev-parse --git-dir 2>$null
if (-not $?) {
  Write-Error "❌ Not a Git repository. Run this in your project root."
  exit 1
}
$hooksDir = Join-Path $gitDir 'hooks'
New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

# Copy hooks
Copy-Item -Path "pre-commit.sh" -Destination (Join-Path $hooksDir 'pre-commit') -Force
Copy-Item -Path "commit-msg.sh" -Destination (Join-Path $hooksDir 'commit-msg') -Force
Copy-Item -Path "pre-push.sh" -Destination (Join-Path $hooksDir 'pre-push') -Force

# Make executable (for WSL/git-bash/mac/linux)
try {
  bash -c "chmod +x '$hooksDir/pre-commit' '$hooksDir/commit-msg' '$hooksDir/pre-push'" 2>$null | Out-Null
} catch {}

Write-Host "✅ Commit-Shame Bot hooks installed in $hooksDir" -ForegroundColor Green
Write-Host "   - pre-commit (diff size shaming)" -ForegroundColor Gray
Write-Host "   - commit-msg (message shaming)" -ForegroundColor Gray 
Write-Host "   - pre-push (push shaming)" -ForegroundColor Gray 