# TH (Teleport Helper) Remote Installer
# Usage:   iwr -useb https://raw.githubusercontent.com/YouLend/windows-tools/main/th/install.ps1 -OutFile "$env:TEMP\th-install.ps1"; & "$env:TEMP\th-install.ps1"; Remove-Item "$env:TEMP\th-install.ps1" -ErrorAction SilentlyContinue
# Fix Unicode display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'
$Version="latest"
$moduleName = "th"
$indent = "  "

# Define user programs directory for all installations
$userProgramsPath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) "Programs"
if (-not (Test-Path $userProgramsPath)) {
    New-Item -ItemType Directory -Path $userProgramsPath -Force | Out-Null
}
function create_header {
    param (
        [string]$HeaderText,
        [string]$indent
    )

    $headerLength = $HeaderText.Length
    $totalDashCount = 52
    $availableDashCount = $totalDashCount - ($headerLength - 5)

    if ($availableDashCount -lt 2) {
        $availableDashCount = 2
    }

    $leftDashes = [math]::Floor($availableDashCount / 2)
    $rightDashes = $availableDashCount - $leftDashes

    $leftDashStr = ('━' * $leftDashes)
    $rightDashStr = ('━' * $rightDashes)

    # Top border
    Write-Host ""
    Write-Host "$indent" -NoNewline
    Write-Host "    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀████████▀" -ForegroundColor DarkGray
    Write-Host "$indent" -NoNewline
    Write-Host "  $leftDashStr " -NoNewLine
    Write-Host "$HeaderText" -NoNewLine -ForegroundColor White
    Write-Host " $rightDashStr" -ForegroundColor White
    Write-Host "$indent" -NoNewline
    Write-Host "▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀" -ForegroundColor DarkGray
    Write-Host ""
}

# Create header
Clear-Host
create_header "🚀 TH (Teleport Helper) Installer" $indent

# Get latest version if not specified
if ($Version -eq "latest") {
    Write-Host "$indent📡 Fetching latest version from GitHub...`n"
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/YouLend/windows-tools/releases/latest"
        $Version = $response.tag_name -replace '^(th-)?v?', ''
        Write-Host "$indent✅ Latest version found: " -NoNewLine
        Write-Host "$Version`n" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to fetch latest version: $($_.Exception.Message)"
    }
}

# Use user directory to avoid permission issues
$userModulePath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'WindowsPowerShell\Modules'
$installPath = Join-Path $userModulePath $moduleName

# Create user module directory if it doesn't exist
if (-not (Test-Path $userModulePath)) {
    Write-Host "$indent📂 Creating user module directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $userModulePath -Force | Out-Null
}

# Initialize flag to track if we should skip main installation
$skipMainInstall = $false

# Check for existing installation
    if (Test-Path $installPath) {
        if (-not $Force) {
            Write-Host "$indent⚠️ TH is already installed at: " -NoNewLine
            Write-Host "$installPath`n" -ForegroundColor Yellow

            do {
                Write-Host "${indent}Overwrite existing installation? (y/N): " -NoNewLine
                $response = Read-Host

                if ($response -notin @("y", "Y", "n", "N", "")) {
                    Write-Host "$indent❌ Invalid choice. Please enter y for Yes or n/Enter for No." -ForegroundColor Red
                }
            } while ($response -notin @("y", "Y", "n", "N", ""))

            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "$indent⚠️  Skipping TH installation - proceeding to dependency check..." -ForegroundColor Yellow
                # Set a flag to skip the main installation but continue to dependencies
                $skipMainInstall = $true
            } else {
                Write-Host "`n$indent🗑️ Removing existing installation..."
                Remove-Item -Path $installPath -Recurse -Force
            }
        } else {
            # Force flag is set, remove without asking
            Write-Host "`n$indent🗑️ Removing existing installation..."
            Remove-Item -Path $installPath -Recurse -Force
        }
    } else {
        Write-Host "$indent📦 Installing to user directory: " -NoNewLine
        Write-Host "$installPath" -ForegroundColor Cyan
    }



# Download and extract (only if not skipping main install)
if (-not $skipMainInstall) {
    Clear-Host
    create_header "🚀 TH (Teleport Helper) Installer" $indent
    Write-Host "$indent⬇️ Downloading th " -NoNewLine
    Write-host "$Version" -NoNewLine -ForegroundColor Green
    Write-Host " from GitHub..."
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "th_install_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $downloadUrl = "https://github.com/YouLend/windows-tools/archive/refs/tags/th-v$Version.zip"
    $zipPath = Join-Path $tempDir "th-v$Version.zip"

    # Download with progress
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $zipPath)

    Write-Host "`n$indent📦" -NoNewLine -ForegroundColor Cyan
    Write-Host " Extracting files..."
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    $repoPath = Join-Path $tempDir "windows-tools-th-v$Version\th"
    if (-not (Test-Path $repoPath)) {
        throw "Expected th directory not found in downloaded archive"
    }

    # Install module files
    Write-Host "`n$indent📋" -NoNewLine -ForegroundColor Cyan
    Write-Host " Installing module files..."
    Copy-Item -Path $repoPath -Destination $installPath -Recurse -Force


} catch {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error "❌ Installation failed: $($_.Exception.Message)"
} finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Always ensure version file exists in user profile, even if installation was skipped
$userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$thConfigDir = Join-Path $userProfile ".th"
$versionFile = Join-Path $thConfigDir "version"

# Create .th directory if it doesn't exist
if (-not (Test-Path $thConfigDir)) {
    Write-Host "`n$indent📁" -ForegroundColor Cyan -NoNewLine
    Write-Host " Creating configuration directory..."
    New-Item -ItemType Directory -Path $thConfigDir -Force | Out-Null
    # Make directory hidden
    try {
        $dir = Get-Item $thConfigDir -Force
        $dir.Attributes = $dir.Attributes -bor [System.IO.FileAttributes]::Hidden
    } catch {
        # Ignore if can't set hidden attribute
    }
}

# Read existing version file to preserve settings
$existingContent = @{}
if (Test-Path $versionFile) {
    try {
        $lines = Get-Content $versionFile
        foreach ($line in $lines) {
            if ($line -match "^([^:]+):\s*(.+)$") {
                $existingContent[$matches[1]] = $matches[2]
            }
        }
    } catch {
        # Ignore read errors
    }
}

# Create version content
$versionContent = @"
CURRENT_VERSION:$Version
LATEST_VERSION:$Version
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:UP_TO_DATE
"@

Set-Content -Path $versionFile -Value $versionContent -Force

# Create batch wrapper for global access
Write-Host "`n$indent🔧" -ForegroundColor Cyan -NoNewLine
Write-Host " Setting up global command..."
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
    Write-Host "`n$indent🔗" -NoNewLine -ForegroundColor Green
    Write-Host "Added to PATH"
}
}

# Function to install auto-installable dependencies
function Install-Dependency {
    param($Dependency)

    Write-Host "$indent📥" -NoNewLine -ForegroundColor Cyan
    Write-Host " Installing " -NoNewLine
    Write-Host "$($Dependency.Name)" -ForegroundColor Green -NoNewLine
    Write-Host "..."

    try {
        # Create install directory
        if (-not (Test-Path $Dependency.InstallPath)) {
            New-Item -ItemType Directory -Path $Dependency.InstallPath -Force | Out-Null
        }

        switch ($Dependency.Command) {
            "kubectl" {
                $kubectlPath = Join-Path $Dependency.InstallPath $Dependency.ExecutableName
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $kubectlPath
                Add-ToPath $Dependency.InstallPath
                Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green 
                Write-Host " kubectl installed successfully"
            }
            "psql" {
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "psql_install"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                $zipPath = Join-Path $tempDir "psql.zip"
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $zipPath

                Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

                # Find the PostgreSQL installation folder in extracted files
                $psqlFolder = Get-ChildItem -Path $tempDir -Directory -Recurse | Where-Object { $_.Name -match "pgsql|postgresql" } | Select-Object -First 1
                if ($psqlFolder) {
                    # Copy entire PostgreSQL folder to user's local programs
                    $targetPath = Join-Path $userProgramsPath "PostgreSQL"
                    if (Test-Path $targetPath) {
                        Remove-Item -Path $targetPath -Recurse -Force
                    }
                    Copy-Item -Path $psqlFolder.FullName -Destination $targetPath -Recurse -Force

                    # Add bin directory to PATH
                    $binPath = Join-Path $targetPath "bin"
                    if (Test-Path $binPath) {
                        Add-ToPath $binPath
                    }
                    Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
                    Write-Host " PostgreSQL installed successfully"
                } else {
                    throw "PostgreSQL folder not found in archive"
                }

                Remove-Item -Path $tempDir -Recurse -Force
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
                    Copy-Item -Path $mongoshPath -Destination (Join-Path $Dependency.InstallPath $Dependency.ExecutableName) -Force
                    Add-ToPath $Dependency.InstallPath
                    Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green 
                    Write-Host " mongosh installed successfully"
                } else {
                    throw "mongosh.exe not found in archive"
                }

                Remove-Item -Path $tempDir -Recurse -Force
            }
            "mongodb-compass" {
                # Try user-level MSI installation first, fall back to manual message
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "compass_install"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                $msiPath = Join-Path $tempDir "mongodb-compass.msi"
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $msiPath

                # Try MSI installation for current user only
                Write-Host "`n$indent🔧" -NoNewLine -ForegroundColor Cyan
                Write-Host " Installing MongoDB Compass for current user..."
                $installArgs = "/i `"$msiPath`""
                $installProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru

                if ($installProcess.ExitCode -eq 0) {
                    Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
                    Write-Host " MongoDB Compass installed successfully"
                } else {
                    Write-Host "`n$indent⚠️ MSI installation failed (exit code: $($installProcess.ExitCode))" -ForegroundColor Yellow
                    Write-Host "$indent   This usually means admin rights are required." -ForegroundColor Yellow
                    Write-Host "$indent   Please install MongoDB Compass manually from:" -ForegroundColor Yellow
                    Write-Host "$indent   $($Dependency.Url)" -ForegroundColor Cyan
                }

                Remove-Item -Path $tempDir -Recurse -Force
            }
            "dbeaver" {
                $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "dbeaver_install"
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

                $installerPath = Join-Path $tempDir "dbeaver-setup.exe"
                Invoke-WebRequest -Uri $Dependency.Url -OutFile $installerPath

                # Try user-level installation first
                Write-Host "`n$indent🔧" -NoNewLine -ForegroundColor Cyan
                Write-Host " Installing DBeaver for current user..."
                $installProcess = Start-Process -FilePath $installerPath -Wait -PassThru

                if ($installProcess.ExitCode -eq 0) {
                    Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
                    Write-Host " DBeaver installed successfully"
                } else {
                    Write-Host "`n$indent⚠️ Installer failed (exit code: $($installProcess.ExitCode))" -ForegroundColor Yellow
                    Write-Host "$indent   This usually means admin rights are required." -ForegroundColor Yellow
                    Write-Host "$indent   Please install DBeaver manually from:" -ForegroundColor Yellow
                    Write-Host "$indent   $($Dependency.Url)" -ForegroundColor Cyan
                }

                Remove-Item -Path $tempDir -Recurse -Force
            }
        }
    } catch {
        Write-Host "`n$indent❌ Failed to install $($Dependency.Name): $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`n$indent   Manual installation: $($Dependency.Url)" -ForegroundColor Yellow
    }
}

# Dependency Management
if (-not $SkipDependencies) {
    Clear-Host
    create_header "🚀 TH (Teleport Helper) Installer" $indent
    Write-Host "$indent🔍" -NoNewLine -ForegroundColor Cyan
    Write-Host " Checking dependencies...`n" 

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

    # Helper function to add directory to PATH
    function Add-ToPath {
        param([string]$Directory)

        $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        if ($currentPath -notlike "*$Directory*") {
            $newPath = if ($currentPath) { "$currentPath;$Directory" } else { $Directory }
            [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
            Write-Host "`n$indent🔗" -NoNewLine -ForegroundColor Green
            Write-Host " Added to PATH"
        }
    }

    # Function to download and install tsh
    function Install-Tsh {
        $tshInstallDir = Join-Path $userProgramsPath "tsh"
        $tshExePath = Join-Path $tshInstallDir 'tsh.exe'

        # Check if tsh is already installed in target directory
        if (Test-Path $tshExePath) {
            Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
            Write-Host " tsh already installed at: $tshExePath"
            # Make sure it's in PATH
            Add-ToPath $tshInstallDir
            return $true
        }

        # Get latest version from GitHub releases
        $teleportVersion = $null
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/gravitational/teleport/releases/latest"
            $teleportVersion = $response.tag_name -replace '^v?', ''
        } catch {
            Write-Host "$indent⚠️  Failed to fetch latest version, using fallback version 18.1.8" -ForegroundColor Yellow
            $teleportVersion = "18.1.8"
        }

        Write-Host "`n$indent📥" -NoNewLine -ForegroundColor Cyan
        Write-Host " Installing tsh version " -NoNewLine
        Write-Host "$teleportVersion" -ForegroundColor Green -NoNewLine
        Write-Host " (Teleport CLI)...`n"
        # Construct download URL for Windows AMD64
        $downloadUrl = "https://cdn.teleport.dev/teleport-v$teleportVersion-windows-amd64-bin.zip"

        try {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "tsh_install"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            $zipPath = Join-Path $tempDir "tsh.zip"
            Write-Host "$indent📥 Downloading from: $downloadUrl" -ForegroundColor Gray
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

            # Find tsh.exe in extracted files
            $tshExe = Get-ChildItem -Path $tempDir -Name "tsh.exe" -Recurse | Select-Object -First 1
            if (-not $tshExe) {
                throw "tsh.exe not found in downloaded archive"
            }

            $tshPath = Join-Path $tempDir $tshExe
            $tshInstallDir = Join-Path $userProgramsPath "tsh"
            if (-not (Test-Path $tshInstallDir)) {
                New-Item -ItemType Directory -Path $tshInstallDir -Force | Out-Null
            }
            Copy-Item -Path $tshPath -Destination (Join-Path $tshInstallDir 'tsh.exe') -Force

            Remove-Item -Path $tempDir -Recurse -Force
            Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
            Write-Host " tsh installed successfully"
            
            Add-ToPath $tshInstallDir
            return $true
        } catch {
            Write-Host "$indent❌ Failed to install tsh: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Check mandatory dependency: tsh
    $tshInstallDir = Join-Path $userProgramsPath "tsh"
    $tshExePath = Join-Path $tshInstallDir 'tsh.exe'
    $tshInstalled = (Test-Path $tshExePath) -or (Test-Command "tsh")

    if (-not $tshInstalled) {
        Write-Host "$indent❌ tsh (Teleport CLI) is required but not installed" -ForegroundColor Red

        do {
            Write-Host "`n${indent}Would you like to install tsh now? (Y/n): " -NoNewLine
            $installTsh = Read-Host

            if ($installTsh -notin @("y", "Y", "n", "N", "")) {
                Write-Host "$indent❌ Invalid choice. Please enter y/Enter for Yes or n for No." -ForegroundColor Red
            }
        } while ($installTsh -notin @("y", "Y", "n", "N", ""))

        if ($installTsh -ne 'n' -and $installTsh -ne 'N') {
            if (-not (Install-Tsh)) {
                Write-Host "$indent⚠️  You'll need to install tsh manually from: https://github.com/gravitational/teleport/releases" -ForegroundColor Yellow
            }
        } else {
            Write-Host "$indent⚠️  TH will not work without tsh. Install from: https://github.com/gravitational/teleport/releases" -ForegroundColor Yellow
        }
    } else {
        Write-Host "$indent✅ tsh (Teleport CLI) is already available" -ForegroundColor Green
        # Ensure PATH is set if it's in our managed location
        if (Test-Path $tshExePath) {
            Add-ToPath $tshInstallDir
        }
    }

    # Define optional dependencies
    $optionalDeps = @(
        @{
            Command = "psql"
            Name = "PostgreSQL CLI (psql)"
            Description = "Required for PostgreSQL database connections"
            Url = "https://sbp.enterprisedb.com/getfile.jsp?fileid=1259681&_gl=1*1usqs8e*_gcl_au*MTYxODMyMzkzOC4xNzU3Nzc3Njc3*_ga*R0ExLjEuMTMyMzY3MjE3Mi4xNzU3Nzc3Njc5*_ga_ND3EP1ME7G*czE3NTc3Nzc2NzgkbzEkZzEkdDE3NTc3ODE4NTYkajYwJGwwJGgxODY1ODEyNDEz"
            AutoInstall = $true
            InstallPath = (Join-Path $userProgramsPath "PostgreSQL\bin")
            ExecutableName = "psql.exe"
        },
        @{
            Command = "kubectl"
            Name = "Kubernetes CLI (kubectl)"
            Description = "Required for kubernetes connections (th k) to function correctly."
            Url = "https://dl.k8s.io/release/v1.34.0/bin/windows/amd64/kubectl.exe"
            AutoInstall = $true
            InstallPath = (Join-Path $userProgramsPath "kubectl")
            ExecutableName = "kubectl.exe"
        },
        @{
            Command = "mongosh"
            Name = "MongoDB Shell (mongosh)"
            Description = "Required for mongodb connections to function correctly"
            Url = "https://downloads.mongodb.com/compass/mongosh-2.5.8-win32-x64.zip"
            AutoInstall = $true
            InstallPath = (Join-Path $userProgramsPath "mongosh")
            ExecutableName = "mongosh.exe"
        },
        @{
            Command = "mongodb-compass"
            Name = "MongoDB Compass"
            Description = "Required for connecting to MongoDB databases via GUI"
            Url = "https://downloads.mongodb.com/compass/mongodb-compass-1.46.10-win32-x64.msi"
            AutoInstall = $true
            InstallPath = (Join-Path $userProgramsPath "MongoDB\MongoDB Compass")
            ExecutableName = "MongoDBCompass.exe"
            IsGUI = $true
        },
        @{
            Command = "dbeaver"
            Name = "DBeaver"
            Description = "Required for connecting to RDS databases via GUI"
            Url = "https://dbeaver.io/files/dbeaver-ce-latest-x86_64-setup.exe"
            AutoInstall = $true
            InstallPath = (Join-Path $userProgramsPath "DBeaver")
            ExecutableName = "dbeaver.exe"
            IsGUI = $true
        }
    )

    # Check optional dependencies
    $missingDeps = @()
    foreach ($dep in $optionalDeps) {
        $isInstalled = $false

        if ($dep.IsGUI) {
            # For GUI apps, check multiple locations and registry
            $exePath = Join-Path $dep.InstallPath $dep.ExecutableName
            $isInstalled = Test-Path $exePath

            # Also check registry for installed programs if not found at expected path
            if (-not $isInstalled) {
                $registryPaths = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )

                foreach ($regPath in $registryPaths) {
                    try {
                        $programs = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                                   Where-Object { $_.DisplayName -like "*$($dep.Name.Split(' ')[0])*" }
                        if ($programs) {
                            $isInstalled = $true
                            break
                        }
                    } catch {
                        # Ignore registry access errors
                    }
                }
            }
        } else {
            # For CLI apps, check if command is available
            $isInstalled = Test-Command $dep.Command
        }

        if (-not $isInstalled) {
            $missingDeps += $dep
        }
    }

    # Prompt for optional dependencies individually
    if ($missingDeps.Count -gt 0) {
        Clear-Host
        create_header "🚀 TH (Teleport Helper) Installer" $indent
        Write-Host "$indent📋 Found $($missingDeps.Count) missing dependencies`n" -ForegroundColor Yellow

        # Show all missing dependencies
        foreach ($dep in $missingDeps) {
            Write-Host "$indent• $($dep.Name)" -ForegroundColor White
        }

        Write-Host "`n${indent}Install options:" -ForegroundColor Cyan
        Write-Host "${indent}A - Install all auto-installable dependencies" -ForegroundColor White
        Write-Host "${indent}I - Install dependencies individually" -ForegroundColor White
        Write-Host "${indent}N - Skip dependency installation" -ForegroundColor White

        do {
            Write-Host "`n${indent}Choose option (A/I/N): " -NoNewLine
            $installChoice = Read-Host

            if ($installChoice.ToUpper() -notin @("A", "I", "N")) {
                Write-Host "$indent❌ Invalid choice. Please enter A, I, or N." -ForegroundColor Red
            }
        } while ($installChoice.ToUpper() -notin @("A", "I", "N"))

        switch ($installChoice.ToUpper()) {
            "A" {
                foreach ($dep in $missingDeps | Where-Object { $_.AutoInstall }) {
                    Clear-Host
                    create_header "🚀 TH (Teleport Helper) Installer" $indent
                    Write-Host "$indent📥" -NoNewLine -ForegroundColor Cyan
                    Write-Host " Installing dependencies...`n"
                    Install-Dependency $dep
                }

                # Show manual links for non-auto deps
                $manualDeps = $missingDeps | Where-Object { -not $_.AutoInstall }
                if ($manualDeps.Count -gt 0) {
                    Write-Host "`n$indent📝 Manual installation required:" -ForegroundColor Yellow
                    foreach ($dep in $manualDeps) {
                        Write-Host "$indent• $($dep.Name): $($dep.Url)" -ForegroundColor White
                    }
                }
            }
            "I" {
                foreach ($dep in $missingDeps) {
                    Clear-Host
                    create_header "🚀 TH (Teleport Helper) Installer" $indent
                    Write-Host "$indent📋 Going through dependencies individually...`n" -ForegroundColor Yellow

                    Write-Host "$indent❌ $($dep.Name) not found" -ForegroundColor Red
                    Write-Host "`n$indent📝 $($dep.Description)" -ForegroundColor Gray
                    Write-Host ""

                    if ($dep.AutoInstall) {
                        do {
                            Write-Host "${indent}Install " -NoNewLine
                            Write-Host "$($dep.Name)" -NoNewLine -ForegroundColor White
                            Write-Host " now? (Y/n): " -NoNewLine
                            $choice = Read-Host

                            if ($choice -notin @("y", "Y", "n", "N", "")) {
                                Write-Host "$indent❌ Invalid choice. Please enter y/Enter for Yes or n for No." -ForegroundColor Red
                            }
                        } while ($choice -notin @("y", "Y", "n", "N", ""))

                        if ($choice -ne 'n' -and $choice -ne 'N') {
                            Clear-Host
                            create_header "🚀 TH (Teleport Helper) Installer" $indent
                            Install-Dependency $dep
                        } else {
                            Write-Host "$indent⚠️  Skipped $($dep.Name)" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "$indent📝 Manual installation required: $($dep.Url)" -ForegroundColor Yellow
                        Write-Host "${indent}Press Enter to continue..." -NoNewLine
                        Read-Host
                        }
                        Write-Host ""
                }
            }
            "N" {
                Write-Host "$indent⚠️  Skipping all dependency installations" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "`n$indent✅" -NoNewLine -ForegroundColor Green
        Write-Host " All dependencies are installed!"
    }
}

# Success message
Clear-Host
create_header "🚀 TH (Teleport Helper) Installer" $indent
Write-Host "$indent🎉" -NoNewLine -ForegroundColor Green
Write-Host " TH (Teleport Helper) installed!"
Write-Host ""
Write-Host "$indent📍 Installation Details:" -ForegroundColor White
Write-Host "$indent   📁 Module: $installPath" -ForegroundColor Gray
Write-Host "$indent   🔧 Command: th (available globally)" -ForegroundColor Gray
Write-Host "$indent   💾 Version: " -NoNewLine
Write-Host "$Version" -ForegroundColor Green
Write-Host ""
Write-Host "$indent⚠️ Note: Restart PowerShell if 'th' command is not recognized." -ForegroundColor Yellow
Write-Host ""
