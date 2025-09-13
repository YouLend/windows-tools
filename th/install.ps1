# TH (Teleport Helper) Remote Installer
# Usage: curl -L https://raw.githubusercontent.com/YouLend/windows-tools/main/th/install.ps1 | powershell -

param(
    [string]$Version = "latest",
    [switch]$Force,
    [switch]$SkipDependencies
)

$ErrorActionPreference = 'Stop'
$moduleName = "th"

Write-Host "🚀 TH (Teleport Helper) Remote Installer" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Get latest version if not specified
if ($Version -eq "latest") {
    Write-Host "📡 Fetching latest version from GitHub..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/YouLend/windows-tools/releases/latest"
        $Version = $response.tag_name -replace '^(th-)?v?', ''
        Write-Host "✅ Latest version found: $Version" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to fetch latest version: $($_.Exception.Message)"
    }
}

# Choose installation location based on admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    # System-wide installation (requires admin)
    $systemModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    $installPath = Join-Path $systemModulePath $moduleName
    Write-Host "📦 Installing system-wide to: $installPath" -ForegroundColor Cyan

    # Create system module directory if it doesn't exist
    if (-not (Test-Path $systemModulePath)) {
        Write-Host "📂 Creating system module directory..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $systemModulePath -Force | Out-Null
    }
} else {
    # User-specific installation
    $userModulePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'
    $installPath = Join-Path $userModulePath $moduleName
    Write-Host "📦 Installing for current user to: $installPath" -ForegroundColor Cyan

    # Create user module directory if it doesn't exist
    if (-not (Test-Path $userModulePath)) {
        Write-Host "📂 Creating user module directory..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $userModulePath -Force | Out-Null
    }
}

# Check for existing installation
if (Test-Path $installPath) {
    if (-not $Force) {
        Write-Host "⚠️  TH is already installed at: $installPath" -ForegroundColor Yellow
        $response = Read-Host "Overwrite existing installation? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "❌ Installation cancelled." -ForegroundColor Red
            exit 0
        }
    }
    Write-Host "🗑️  Removing existing installation..." -ForegroundColor Yellow
    Remove-Item -Path $installPath -Recurse -Force
}

# Download and extract
Write-Host "⬇️  Downloading TH v$Version from GitHub..." -ForegroundColor Cyan
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "th_install_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $downloadUrl = "https://github.com/YouLend/windows-tools/archive/refs/tags/th-v$Version.zip"
    $zipPath = Join-Path $tempDir "th-v$Version.zip"

    # Download with progress
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $zipPath)

    Write-Host "📦 Extracting files..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    $repoPath = Join-Path $tempDir "windows-tools-th-v$Version\th"
    if (-not (Test-Path $repoPath)) {
        throw "Expected th directory not found in downloaded archive"
    }

    # Install module files
    Write-Host "📋 Installing module files..." -ForegroundColor Cyan
    Copy-Item -Path $repoPath -Destination $installPath -Recurse -Force

    # Create version cache
    $versionCacheFile = Join-Path $installPath ".th_version_cache"
    $versionCacheContent = @"
CURRENT_VERSION: $Version
LAST_CHECK: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
INSTALL_METHOD: curl
"@
    Set-Content -Path $versionCacheFile -Value $versionCacheContent -Force

} catch {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "❌ Installation failed: $($_.Exception.Message)"
} finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Create batch wrapper for global access
Write-Host "🔧 Setting up global command..." -ForegroundColor Cyan
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

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($currentPath -notlike "*$binPath*") {
    $newPath = if ($currentPath) { "$currentPath;$binPath" } else { $binPath }
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    Write-Host "🔗 Added to PATH: $binPath" -ForegroundColor Green
}

# Success message
Write-Host ""
Write-Host "🎉 SUCCESS! TH (Teleport Helper) v$Version installed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "📍 Installation Details:" -ForegroundColor White
Write-Host "   📁 Module: $installPath" -ForegroundColor Gray
Write-Host "   🔧 Command: th (available globally)" -ForegroundColor Gray
Write-Host "   💾 Version: $Version" -ForegroundColor Gray
Write-Host ""
Write-Host "🚀 Quick Start:" -ForegroundColor White
Write-Host "   th          - Show all commands" -ForegroundColor Gray
Write-Host "   th k -h     - Kubernetes help" -ForegroundColor Gray
Write-Host "   th a -h     - AWS help" -ForegroundColor Gray
Write-Host "   th d -h     - Database help" -ForegroundColor Gray
Write-Host "   th u        - Check for updates" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  Note: Restart PowerShell if 'th' command is not recognized." -ForegroundColor Yellow
Write-Host ""

# Dependency Management
if (-not $SkipDependencies) {
    Write-Host "🔍 Checking dependencies..." -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan

    # Function to check if command exists
    function Test-Command {
        param([string]$CommandName)
        try {
            Get-Command $CommandName -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    # Function to get latest GitHub release
    function Get-LatestGitHubRelease {
        param([string]$Repo)
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
            return $response
        } catch {
            return $null
        }
    }

    # Function to download and install tsh
    function Install-Tsh {
        Write-Host "📥 Installing tsh (Teleport CLI)..." -ForegroundColor Cyan

        $release = Get-LatestGitHubRelease "gravitational/teleport"
        if (-not $release) {
            Write-Host "❌ Failed to get latest tsh release" -ForegroundColor Red
            return $false
        }

        # Find Windows AMD64 asset
        $asset = $release.assets | Where-Object { $_.name -like "*windows-amd64*" -and $_.name -like "*.zip" } | Select-Object -First 1
        if (-not $asset) {
            Write-Host "❌ Windows tsh binary not found in release" -ForegroundColor Red
            return $false
        }

        try {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "tsh_install"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            $zipPath = Join-Path $tempDir "tsh.zip"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

            # Find tsh.exe in extracted files
            $tshExe = Get-ChildItem -Path $tempDir -Name "tsh.exe" -Recurse | Select-Object -First 1
            if (-not $tshExe) {
                throw "tsh.exe not found in downloaded archive"
            }

            $tshPath = Join-Path $tempDir $tshExe
            $binDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'th\bin'
            Copy-Item -Path $tshPath -Destination (Join-Path $binDir 'tsh.exe') -Force

            Remove-Item -Path $tempDir -Recurse -Force
            Write-Host "✅ tsh installed successfully" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "❌ Failed to install tsh: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Check mandatory dependency: tsh
    if (-not (Test-Command "tsh")) {
        Write-Host "❌ tsh (Teleport CLI) is required but not installed" -ForegroundColor Red
        Write-Host "   tsh is mandatory for TH to function" -ForegroundColor Yellow
        $installTsh = Read-Host "Install tsh automatically? (Y/n)"
        if ($installTsh -ne 'n' -and $installTsh -ne 'N') {
            if (-not (Install-Tsh)) {
                Write-Host "⚠️  You'll need to install tsh manually from: https://github.com/gravitational/teleport/releases" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  TH will not work without tsh. Install from: https://github.com/gravitational/teleport/releases" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ tsh found" -ForegroundColor Green
    }

    # Define optional dependencies
    $optionalDeps = @(
        @{
            Command = "psql"
            Name = "PostgreSQL CLI (psql)"
            Description = "Required for PostgreSQL database connections"
            Impact = "Cannot connect to PostgreSQL databases"
            Url = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1259681"
            AutoInstall = $false  # Manual download required
        },
        @{
            Command = "kubectl"
            Name = "Kubernetes CLI (kubectl)"
            Description = "Required for Kubernetes cluster management"
            Impact = "Cannot manage Kubernetes clusters"
            Url = "https://dl.k8s.io/release/v1.34.0/bin/windows/amd64/kubectl.exe"
            AutoInstall = $true
        },
        @{
            Command = "mongosh"
            Name = "MongoDB Shell"
            Description = "Required for MongoDB database connections"
            Impact = "Cannot connect to MongoDB databases"
            Url = "https://downloads.mongodb.com/compass/mongosh-2.5.8-win32-x64.zip"
            AutoInstall = $true
        }
    )

    # Check optional dependencies
    $missingDeps = @()
    foreach ($dep in $optionalDeps) {
        if (Test-Command $dep.Command) {
            Write-Host "✅ $($dep.Name) found" -ForegroundColor Green
        } else {
            Write-Host "❌ $($dep.Name) not found" -ForegroundColor Yellow
            $missingDeps += $dep
        }
    }

    # Prompt for optional dependencies
    if ($missingDeps.Count -gt 0) {
        Write-Host ""
        Write-Host "📋 Missing Optional Dependencies:" -ForegroundColor Yellow
        Write-Host "=================================" -ForegroundColor Yellow

        for ($i = 0; $i -lt $missingDeps.Count; $i++) {
            $dep = $missingDeps[$i]
            Write-Host "$($i + 1). $($dep.Name)" -ForegroundColor White
            Write-Host "   📝 $($dep.Description)" -ForegroundColor Gray
            Write-Host "   ⚠️  Without this: $($dep.Impact)" -ForegroundColor Red
            Write-Host ""
        }

        Write-Host "Install options:" -ForegroundColor Cyan
        Write-Host "A - Install all auto-installable dependencies" -ForegroundColor White
        Write-Host "S - Show manual installation links" -ForegroundColor White
        Write-Host "N - Skip dependency installation" -ForegroundColor White

        $choice = Read-Host "Choose option (A/S/N)"

        switch ($choice.ToUpper()) {
            "A" {
                Write-Host "📥 Installing auto-installable dependencies..." -ForegroundColor Cyan
                foreach ($dep in $missingDeps | Where-Object { $_.AutoInstall }) {
                    Install-Dependency $dep
                }

                # Show manual links for non-auto deps
                $manualDeps = $missingDeps | Where-Object { -not $_.AutoInstall }
                if ($manualDeps.Count -gt 0) {
                    Write-Host ""
                    Write-Host "📝 Manual installation required:" -ForegroundColor Yellow
                    foreach ($dep in $manualDeps) {
                        Write-Host "• $($dep.Name): $($dep.Url)" -ForegroundColor White
                    }
                }
            }
            "S" {
                Write-Host ""
                Write-Host "📝 Manual installation links:" -ForegroundColor Cyan
                foreach ($dep in $missingDeps) {
                    Write-Host "• $($dep.Name): $($dep.Url)" -ForegroundColor White
                }
            }
            "N" {
                Write-Host "⚠️  Skipping dependency installation" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "✅ All dependencies are available!" -ForegroundColor Green
    }
}

# Function to install auto-installable dependencies
function Install-Dependency {
    param($Dependency)

    Write-Host "📥 Installing $($Dependency.Name)..." -ForegroundColor Cyan

    try {
        $binDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'th\bin'

        switch ($Dependency.Command) {
            "kubectl" {
                $kubectlPath = Join-Path $binDir 'kubectl.exe'
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $kubectlPath
                Write-Host "✅ kubectl installed successfully" -ForegroundColor Green
            }
            "mongosh" {
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "mongosh_install"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                $zipPath = Join-Path $tempDir "mongosh.zip"
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $zipPath

                Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

                # Find mongosh.exe in extracted files
                $mongoshExe = Get-ChildItem -Path $tempDir -Name "mongosh.exe" -Recurse | Select-Object -First 1
                if ($mongoshExe) {
                    $mongoshPath = Join-Path $tempDir $mongoshExe
                    Copy-Item -Path $mongoshPath -Destination (Join-Path $binDir 'mongosh.exe') -Force
                    Write-Host "✅ mongosh installed successfully" -ForegroundColor Green
                } else {
                    throw "mongosh.exe not found in archive"
                }

                Remove-Item -Path $tempDir -Recurse -Force
            }
        }
    } catch {
        Write-Host "❌ Failed to install $($Dependency.Name): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   Manual installation: $($Dependency.Url)" -ForegroundColor Yellow
    }
}

Write-Host ""