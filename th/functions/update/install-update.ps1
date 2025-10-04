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
        # Target installation directory is always $HOME\th
        $targetDir = Join-Path $HOME "th"

        # Create th directory if it doesn't exist
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
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
        $versionCacheFile = Join-Path $HOME ".th\version"
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
        # Copy contents excluding th_install.ps1
        Get-ChildItem -Path "$tempDir\windows-tools-th-v$Version\th" | Where-Object { $_.Name -ne 'th_install.ps1' } | Copy-Item -Destination $targetDir -Recurse -Force
        
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
