$moduleName = "th"
$repoPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$profileFile = $PROFILE
$importLine = "Import-Module `"$repoPath\$moduleName`""

# Create profile file if it doesn't exist
if (-not (Test-Path $profileFile)) {
    New-Item -ItemType File -Path $profileFile -Force | Out-Null
}

# Read profile contents
$profileContents = Get-Content $profileFile -Raw -ErrorAction SilentlyContinue
$profileContents = $profileContents -as [string]

# Add import line if not already present
if ($profileContents -notmatch [regex]::Escape($importLine)) {
    Add-Content -Path $profileFile -Value "`n$importLine"
    Write-Host "`nAdded module import to $profileFile"
} else {
    Write-Host "`nModule import already exists in profile."
}

# Attempt to import now
. $PROFILE
Write-Host "`nth installed successfully." -ForegroundColor Green