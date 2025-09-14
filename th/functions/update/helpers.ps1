# Background update checker
function check_th_updates_background {
    # Use user profile directory for cache
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $versionCacheFile = Join-Path $userProfile ".th\version"
    $sessionCacheFile = Join-Path ([System.IO.Path]::GetTempPath()) ("th_update_check_session_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    
    # Read update suppression config from version file
    $suppressionHours = 1
    if (Test-Path $versionCacheFile) {
        try {
            $lines = Get-Content $versionCacheFile
            foreach ($line in $lines) {
                if ($line -match "^UPDATE_SUPPRESSION_HOURS:\s*(.+)$") {
                    $suppressionHours = [int]$matches[1].Trim()
                    break
                }
            }
        } catch {
            # Use default if can't read
        }
    }

    # Check if we already checked recently
    if (Test-Path $versionCacheFile) {
        $cacheTime = (Get-Item $versionCacheFile -Force).LastWriteTime
        $currentTime = Get-Date
        $timeDiff = ($currentTime - $cacheTime).TotalHours

        # If cache is less than suppression time old, use cached result
        if ($timeDiff -lt $suppressionHours) {
            try {
                $cachedResult = Get-Content $versionCacheFile -Raw -ErrorAction Stop
                # If muted, keep it muted until time passes
                if ($cachedResult.Trim() -eq "MUTED") {
                    Copy-Item $versionCacheFile $sessionCacheFile -ErrorAction SilentlyContinue
                    return $sessionCacheFile
                } else {
                    Copy-Item $versionCacheFile $sessionCacheFile -ErrorAction SilentlyContinue
                    return $sessionCacheFile
                }
            } catch {
                # If can't read cache, continue with fresh check
            }
        }
    }
    
    # Start background process
    $job = Start-Job -ScriptBlock {
        param($versionCache, $sessionCache)
        
        try {
            # Use GitHub API to check for updates
            $repo = "YouLend/windows-tools"
            $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
            
            # Normal update check
            $forceUpdate = $false
                
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
                    $moduleVersion = "1.6.0"

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
                    
                    # Compare versions
                    if ($moduleVersion -ne $latestVersion) {
                        $result = "UPDATE_AVAILABLE:" + $moduleVersion + ":" + $latestVersion
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
STATUS:$($result.Split(':')[0])$suppressionHours
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
            
            # Write to session cache for immediate use
            Set-Content -Path $sessionCache -Value $result -ErrorAction SilentlyContinue
            
        } catch {
            $errorResult = "ERROR_CHECKING_UPDATES"
            Set-Content -Path $sessionCache -Value $errorResult -ErrorAction SilentlyContinue
        }
    } -ArgumentList $versionCacheFile, $sessionCacheFile
    
    # Don't wait for job to complete, just return the session cache file path
    return $sessionCacheFile
}

# Check for update results and display notification (non-blocking)
function show_update_notification {
    param([string]$UpdateCacheFile)
    
    # Quick check - don't wait or block
    $result = $null
    
    # Only check if cache file exists, don't wait
    if (Test-Path $UpdateCacheFile) {
        try {
            $result = Get-Content $UpdateCacheFile -Raw -ErrorAction SilentlyContinue
        } catch {
            # Ignore file read errors
        }
    }
    
    # Clean up any completed jobs immediately
    Get-Job | Where-Object { $_.State -eq 'Completed' } | Remove-Job -Force -ErrorAction SilentlyContinue
    
    if ($result) {
        $result = $result.Trim()
        
        # Check if notifications are muted
        if ($result -eq "MUTED") {
            return  # Skip notification silently
        } elseif ($result -like "UPDATE_AVAILABLE:*") {
            $parts = $result -split ":"
            if ($parts.Length -ge 3) {
                $currentVersion = $parts[1].Trim()
                $latestVersion = $parts[2].Trim()

                # Get changelog from GitHub API
                $changelog = get_changelog $latestVersion

                create_notification $currentVersion $latestVersion $changelog
            }
        }
    }
    
    # Clean up cache file
    if (Test-Path $UpdateCacheFile) {
        Remove-Item $UpdateCacheFile -Force -ErrorAction SilentlyContinue
    }
}

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


function get_changelog {
    param([string]$version)
    
    $repo = "YouLend/windows-tools"
    
    try {
        # Check if curl is available (Windows usually has Invoke-RestMethod)
        $uri = "https://api.github.com/repos/$repo/releases/tags/th-v$version"
        $response = Invoke-RestMethod -Uri $uri -ErrorAction SilentlyContinue
        
        if ($response -and $response.body) {
            # Extract content after "Summary:" header
            $lines = $response.body -split "`r?`n"
            $inSummary = $false
            $changelog = @()
            
            foreach ($line in $lines) {
                if ($line -match "^#.*Summary") {
                    $inSummary = $true
                    continue
                }
                if ($inSummary) {
                    if ($line -match "^-") {
                        $changelog += $line
                    }
                    if ($changelog.Count -ge 10) {
                        break
                    }
                }
            }
            
            return ($changelog -join "`n")
        } else {
            return "No changelog available for version $version"
        }
    } catch {
        return "Unable to fetch changelog - API unavailable"
    }
}


