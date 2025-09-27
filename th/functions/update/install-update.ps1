# Function to download and install update from GitHub
function install_th_update {
    param(
        [string]$Version,
        [string]$Indent = ""
    )

    Write-Host ($Indent + "Installing th version ") -NoNewLine
    Write-Host $version -ForegroundColor Green -NoNewLine
    Write-Host "...`n"

    try {
        # Detect current installation location
        $moduleDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

        # Check if we're in Program Files (old system-wide install) or user directory
        $programFilesPath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\th'
        $userModulesPath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)) 'WindowsPowerShell\Modules\th'

        # Determine target installation directory
        $targetDir = $moduleDir
        if ($moduleDir -eq $programFilesPath) {
            # Migrate from Program Files to user directory to avoid permission issues
            Write-Host ($Indent + "Migrating from Program Files to user directory...`n") -ForegroundColor Yellow
            $targetDir = $userModulesPath

            # Create user modules directory if it doesn't exist
            $userModulesBase = Split-Path -Parent $userModulesPath
            if (-not (Test-Path $userModulesBase)) {
                New-Item -ItemType Directory -Path $userModulesBase -Force | Out-Null
            }
        }
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "th_update_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download and extract
        $downloadUrl = "https://github.com/YouLend/windows-tools/archive/refs/tags/th-v$Version.zip"
        $zipPath = Join-Path $tempDir "th-v$Version.zip"
        
        Write-Host ($Indent + "Downloading from GitHub...`n") -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
        
        Write-Host ($Indent + "Extracting files...`n")
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Backup version cache from user profile
        $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
        $versionCacheFile = Join-Path $userProfile ".th\version"
        $versionCacheBackup = $null
        if (Test-Path $versionCacheFile) {
            $versionCacheBackup = Get-Content $versionCacheFile -Raw
        }

        # Replace files in target directory
        Write-Host ($Indent + "Installing new files...`n")
        if (Test-Path $targetDir) {
            Get-ChildItem -Path $targetDir | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -Path "$tempDir\windows-tools-th-v$Version\th\*" -Destination $targetDir -Recurse -Force

        # If we migrated from Program Files, try to clean up the old location (best effort)
        if ($moduleDir -eq $programFilesPath -and $targetDir -ne $moduleDir) {
            Write-Host ($Indent + "Cleaning up old Program Files installation...`n") -ForegroundColor Gray
            try {
                Remove-Item -Path $moduleDir -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore cleanup errors - user can manually remove later if needed
            }
        }
        
        # Update version cache
        update_current_version $Version
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        return $true
        
    } catch {
        Write-Host ($Indent + "❌ Update failed: $($_.Exception.Message)") -ForegroundColor Red
        return $false
    }
}
