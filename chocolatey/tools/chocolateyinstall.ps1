$ErrorActionPreference = 'Stop'

$packageName = 'th'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Download from GitHub releases
$version = $env:ChocolateyPackageVersion
$releaseUrl = "https://github.com/YouLend/windows-tools/releases/download/th-v$version/th-$version.zip"
$downloadPath = Join-Path $toolsDir "th-$version.zip"

Write-Host "Installing TH (Teleport Helper) v$version..." -ForegroundColor Green
Write-Host "Downloading from: $releaseUrl" -ForegroundColor Cyan

# Download and extract
Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $downloadPath -Url $releaseUrl
Get-ChocolateyUnzip -FileFullPath $downloadPath -Destination $toolsDir

$moduleDir = Join-Path $toolsDir 'th'

# Use system-wide PowerShell modules to avoid OneDrive conflicts
$systemModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
$installPath = Join-Path $systemModulePath 'th'

Write-Host "Module will be installed to: $installPath" -ForegroundColor Cyan

# Create system module directory if it doesn't exist
if (-not (Test-Path $systemModulePath)) {
    Write-Host "Creating system module directory: $systemModulePath" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $systemModulePath -Force -ErrorAction Stop | Out-Null
        Write-Host "Successfully created directory: $systemModulePath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create system directory: $systemModulePath. Error: $($_.Exception.Message)"
        Write-Error "Make sure you're running as Administrator"
        throw
    }
}

# Remove existing installation
if (Test-Path $installPath) {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path $installPath -Recurse -Force
}

# Copy module files
Write-Host "Copying module files to: $installPath" -ForegroundColor Cyan
Copy-Item -Path $moduleDir -Destination $installPath -Recurse -Force

# Cleanup download files
Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $moduleDir -Recurse -Force -ErrorAction SilentlyContinue

# Config file is already included in the module structure at config/th.config.json

# Create a batch file wrapper for global access
$binPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'th\bin'
if (-not (Test-Path $binPath)) {
    New-Item -ItemType Directory -Path $binPath -Force | Out-Null
}

$batchFile = Join-Path $binPath 'th.bat'
$batchContent = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module '$installPath' -Force; th %*"
"@

Set-Content -Path $batchFile -Value $batchContent -Force
Write-Host "Created batch wrapper at: $batchFile" -ForegroundColor Cyan

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -notlike "*$binPath*") {
    $newPath = if ($currentPath) { "$currentPath;$binPath" } else { $binPath }
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "Added to PATH: $binPath" -ForegroundColor Green
    Write-Host "Note: You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
} else {
    Write-Host "PATH already contains: $binPath" -ForegroundColor Green
}

# Also try to import the module for immediate use
try {
    Import-Module $installPath -Force -Global
    Write-Host "Module imported successfully!" -ForegroundColor Green
} catch {
    Write-Warning "Could not import module automatically. You may need to restart PowerShell."
}

Write-Host @"

TH (Teleport Helper) installed successfully!

Quick Start:
  - Run 'th' to see all available commands
  - Run 'th k -h' for Kubernetes help
  - Run 'th a -h' for AWS help
  - Run 'th d -h' for Database help

Configuration:
  - Edit th.config.json in the module directory to customize environments
  - Module installed at: $installPath

Prerequisites:
  - Teleport CLI (tsh) must be installed and configured
  - kubectl for Kubernetes operations
  - PSQL or DB GUI for RDS operations

Note: If 'th' command is not recognized, restart PowerShell or run:
   Import-Module th

"@ -ForegroundColor White