function check_th_updates_background {
    $versionCacheFile = Join-Path $HOME ".th\version"

    # Create .th directory and version file if they don't exist
    $thDir = Join-Path $HOME ".th"
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

    if (-not (Test-Path $versionCacheFile)) {
        # Create initial version file
        $currentVersion = get_th_version
        $versionContent = @"
CURRENT_VERSION:$currentVersion
LATEST_VERSION:$currentVersion
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:UP_TO_DATE
UPDATE_SUPPRESSION_HOURS:1
"@
        Set-Content -Path $versionCacheFile -Value $versionContent -Force
    }

    # Read update suppression config from version file
    $suppressionHours = 1
    if (Test-Path $versionCacheFile) {
        try {
            $content = Get-Content $versionCacheFile -Raw
            if ($content -match "UPDATE_SUPPRESSION_HOURS:\s*(\d+)") {
                $suppressionHours = [int]$matches[1]
            } else {
                # Add default suppression hours to existing file
                Add-Content $versionCacheFile "`nUPDATE_SUPPRESSION_HOURS:1" -ErrorAction SilentlyContinue
            }
        } catch {
            # Use default if can't read
        }
    }

    # Check if we already checked recently or if update is muted
    if (Test-Path $versionCacheFile) {
        try {
            $content = Get-Content $versionCacheFile -Raw
            $lines = $content -split "`n"
            $versionData = @{}
            foreach ($line in $lines) {
                if ($line -match "^([^:]+):\s*(.+)$") {
                    $versionData[$matches[1]] = $matches[2].Trim()
                }
            }

            # Check LAST_CHECK timestamp with suppression
            if ($versionData.ContainsKey("LAST_CHECK")) {
                try {
                    $lastCheck = Get-Date $versionData["LAST_CHECK"]
                    
                    $hoursSinceCheck = ((Get-Date) - $lastCheck).TotalHours
                    if ($hoursSinceCheck -lt $suppressionHours) {
                        # Within suppression window, don't check for updates
                        return $null
                    }
                } catch {
                    # If can't parse date, proceed with check
                }
            }
        } catch {
            # If can't read file, proceed with check
        }
    }
    
    # Start background process
    Write-Host "Starting background job"
    $job = Start-Job -ScriptBlock {
        param($versionCache)

        try {
            Write-Host "Background job started, versionCache: $versionCache"
            # Use GitHub API to check for updates
            $repo = "YouLend/windows-tools"
            $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
                
                # Get current version from version cache file
                $moduleVersion = $null
                
                # Try to read current version from cache file
                if (Test-Path $versionCache) {
                    try {
                        $cacheContent = Get-Content $versionCache -Raw -ErrorAction Stop
                        $lines = $cacheContent -split "`n"
                        foreach ($line in $lines) {
                            if ($line -match "^CURRENT_VERSION:(.+)$") {
                                $moduleVersion = $matches[1].Trim()
                                break
                            }
                        }
                    } catch {
                        # Ignore errors reading cache
                    }
                }
                
                # If no version in cache, set default and save it preserving existing config
                if (-not $moduleVersion) {
                    $moduleVersion = get_th_version

                    # Create .th directory if it doesn't exist
                    $thDir = Split-Path -Parent $versionCache
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

                    $versionContent = "CURRENT_VERSION:$moduleVersion`nLAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                }
                
                # Get latest release from GitHub
                try {
                    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                    $latestVersion = $response.tag_name -replace '^(th-)?v?', ''  # Remove 'th-v' or 'v' prefix if present
                    Write-Host "here"
                    Write-Host $latestVersion
                    # Compare versions
                    if ($moduleVersion -ne $latestVersion) {
                        $result = "SHOW_UPDATE"  # Show notification to user
                    } else {
                        $result = "UP_TO_DATE"
                    }

                    # Read existing suppression setting
                    $suppressionHours = ""
                    if (Test-Path $versionCache) {
                        try {
                            $existingLines = Get-Content $versionCache
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

                    # Update version cache with comprehensive info
                    $versionContent = @"
CURRENT_VERSION:$moduleVersion
LATEST_VERSION:$latestVersion
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:$result$suppressionHours
"@
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                    
                } catch {
                    $result = "ERROR_CHECKING_UPDATES"
                    
                    # Read existing suppression setting for error case too
                    $suppressionHours = ""
                    if (Test-Path $versionCache) {
                        try {
                            $existingLines = Get-Content $versionCache
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

                    # Still update cache with current version and error status
                    $versionContent = @"
CURRENT_VERSION:$moduleVersion
LATEST_VERSION:UNKNOWN
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:ERROR_CHECKING_UPDATES$suppressionHours
"@
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                }
            
        } catch {
            $errorResult = "ERROR_CHECKING_UPDATES"

            # Read existing suppression setting for error case too
            $suppressionHours = ""
            if (Test-Path $versionCache) {
                try {
                    $existingLines = Get-Content $versionCache
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

            # Still update cache with current version and error status
            $moduleVersion = get_th_version
            $versionContent = @"
CURRENT_VERSION:$moduleVersion
LATEST_VERSION:UNKNOWN
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:ERROR_CHECKING_UPDATES$suppressionHours
"@
            Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
        }
    } -ArgumentList $versionCacheFile

    # Don't wait for job to complete, return null (notifications read directly from version file)
    return $null
}