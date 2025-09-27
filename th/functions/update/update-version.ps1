# Function to update the current version in the cache
function update_current_version {
    param([string]$NewVersion)

    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $versionCacheFile = Join-Path $userProfile ".th\version"

    # Create .th directory if it doesn't exist
    $thDir = Split-Path -Parent $versionCacheFile
    if (-not (Test-Path $thDir)) {
        New-Item -ItemType Directory -Path $thDir -Force | Out-Null
        # Make directory hidden
        try {
            $dir = Get-Item $thDir -Force
            $dir.Attributes = $dir.Attributes -bor [System.IO.FileAttributes]::Hidden
        } catch {
            # Ignore if can't set hidden
        }
    }

    # Read existing suppression setting
    $suppressionHours = ""
    if (Test-Path $versionCacheFile) {
        try {
            $existingLines = Get-Content $versionCacheFile
            foreach ($line in $existingLines) {
                if ($line -match "^UPDATE_SUPPRESSION_HOURS:\s*(.+)$") {
                    $suppressionHours = "`nUPDATE_SUPPRESSION_HOURS:$($matches[1].Trim())"
                    break
                }
            }
        } catch {
            # Ignore read errors
        }
    }

    $versionContent = @"
CURRENT_VERSION:$NewVersion
LATEST_VERSION:$NewVersion
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:UP_TO_DATE$suppressionHours
"@

    Set-Content -Path $versionCacheFile -Value $versionContent
}