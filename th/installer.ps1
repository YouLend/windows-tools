$moduleName = "th"
$repoPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleInstallPath = Join-Path $HOME "Documents\PowerShell\Modules\$moduleName"

# Ensure the target directory exists
if (-not (Test-Path $moduleInstallPath)) {
    New-Item -ItemType Directory -Path $moduleInstallPath -Force | Out-Null
}

# Check if the module is already installed
if (Test-Path $moduleInstallPath) {
    Write-Host "`n'$moduleName' is already installed on this machine."
} else {
    # First-time install
    Copy-Item -Path (Join-Path $repoPath '*') -Destination $moduleInstallPath -Recurse -Force
    Write-Host "`nInstalled '$moduleName' to $moduleInstallPath"
}

# Add Import-Module to the user's PowerShell profile if not present
$profileLine = "Import-Module $moduleInstallPath"
$profileFile = $PROFILE

if (-not (Test-Path $profileFile)) {
    New-Item -ItemType File -Path $profileFile -Force | Out-Null
}

$profileContents = ""
if ((Get-Item $profileFile).Length -gt 0) {
    $profileContents = Get-Content $profileFile -Raw
}
$profileContents = $profileContents -as [string]

if ($profileContents -notmatch [regex]::Escape($profileLine)) {
    Add-Content -Path $profileFile -Value "`n$profileLine"
    Write-Host "`nAdded '$profileLine' to profile: $profileFile"
    Write-Host "`nth installed successfully. Restart your shell to start using." -ForegroundColor Green
} else {
    Write-Host "`n'Import-Module' line already exists in profile profile."
}
