# Fix line endings for shell scripts on Windows
# This script converts CRLF to LF for all .sh files

Write-Host "Fixing line endings for shell scripts..." -ForegroundColor Green

# Get all .sh files recursively
$shFiles = Get-ChildItem -Path . -Filter "*.sh" -Recurse

if ($shFiles.Count -eq 0) {
    Write-Host "No .sh files found." -ForegroundColor Yellow
    exit 0
}

$fixedCount = 0

foreach ($file in $shFiles) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Cyan
    
    # Read content and replace CRLF with LF
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $newContent = $content -replace "`r`n", "`n"
    
    # Write back if content changed
    if ($content -ne $newContent) {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
        $fixedCount++
        Write-Host "  ✓ Fixed line endings" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Already has correct line endings" -ForegroundColor Gray
    }
}

Write-Host "`nSummary:" -ForegroundColor Green
Write-Host "  Total .sh files found: $($shFiles.Count)" -ForegroundColor White
Write-Host "  Files fixed: $fixedCount" -ForegroundColor White

if ($fixedCount -gt 0) {
    Write-Host "`nLine endings have been fixed! You can now commit and push." -ForegroundColor Green
} else {
    Write-Host "`nAll files already have correct line endings." -ForegroundColor Green
} 