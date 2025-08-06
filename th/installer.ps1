#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$moduleName = "th"
$repoPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing TH (Teleport Helper)..." -ForegroundColor Green

# Use system-wide PowerShell modules to avoid OneDrive conflicts
$systemModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
$installPath = Join-Path $systemModulePath $moduleName

Write-Host "Module will be installed to: $installPath" -ForegroundColor Cyan

# Create system module directory if it doesn't exist
if (-not (Test-Path $systemModulePath)) {
    Write-Host "Creating system module directory: $systemModulePath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $systemModulePath -Force | Out-Null
}

# Remove existing installation
if (Test-Path $installPath) {
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path $installPath -Recurse -Force
}

# Copy module files
Write-Host "Copying module files to: $installPath" -ForegroundColor Cyan
Copy-Item -Path $repoPath -Destination $installPath -Recurse -Force

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

Write-Host @"

TH (Teleport Helper) installed successfully!

Quick Start:
  - Run 'th' to see all available commands
  - Run 'th k -h' for Kubernetes help
  - Run 'th a -h' for AWS help
  - Run 'th d -h' for Database help

Module installed at: $installPath
Global command available via PATH: th

Note: If 'th' command is not recognized, restart PowerShell.

"@ -ForegroundColor White