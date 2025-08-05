$ErrorActionPreference = 'Stop'

$packageName = 'th'

Write-Host "Uninstalling TH (Teleport Helper)..." -ForegroundColor Yellow

# Get PowerShell module paths - check both PowerShell Core and Windows PowerShell
$possiblePaths = @()
$userModulePath = $env:PSModulePath -split ';' | Where-Object { $_ -like "*$env:USERNAME*" } | Select-Object -First 1

if ($userModulePath) {
    $possiblePaths += (Join-Path $userModulePath 'th')
}

# Also check common module locations
$possiblePaths += @(
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\th'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules\th')
)

# Try to remove the module from current session first
try {
    Remove-Module th -Force -ErrorAction SilentlyContinue
    Write-Host "Module removed from current session." -ForegroundColor Green
} catch {
    Write-Host "Module was not loaded in current session." -ForegroundColor Gray
}

# Remove the module from all possible locations
$removedCount = 0
foreach ($installPath in $possiblePaths) {
    if (Test-Path $installPath) {
        try {
            Remove-Item -Path $installPath -Recurse -Force
            Write-Host "Module files removed from: $installPath" -ForegroundColor Green
            $removedCount++
        } catch {
            Write-Warning "Could not remove files from: $installPath"
            Write-Warning "You may need to restart PowerShell and try again."
        }
    }
}

# Remove batch wrapper and PATH entry
$binPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'th\bin'
$batchFile = Join-Path $binPath 'th.bat'

if (Test-Path $batchFile) {
    Remove-Item -Path $batchFile -Force
    Write-Host "Removed batch wrapper: $batchFile" -ForegroundColor Green
}

if (Test-Path $binPath) {
    try {
        Remove-Item -Path $binPath -Recurse -Force
        Write-Host "Removed bin directory: $binPath" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove bin directory: $binPath"
    }
}

# Remove from PATH
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -like "*$binPath*") {
    $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $binPath }) -join ';'
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Removed from PATH: $binPath" -ForegroundColor Green
    Write-Host "Note: You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
}

if ($removedCount -gt 0) {
    Write-Host "TH (Teleport Helper) uninstalled successfully!" -ForegroundColor Green
} else {
    Write-Host "TH module not found in any expected locations:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host "It may have been manually removed already." -ForegroundColor Gray
}

Write-Host @"

Uninstallation Complete

Note: If you encounter any issues:
- Restart PowerShell and try the uninstall again
- Manually remove module directories if needed
- Clear PowerShell module cache if needed

"@ -ForegroundColor White