# Background update checker
function check_th_updates_background {
    # Use th module directory for cache
    $moduleDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $versionCacheFile = Join-Path $moduleDir ".th_version_cache"
    $sessionCacheFile = Join-Path ([System.IO.Path]::GetTempPath()) ("th_update_check_session_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    
    # Check if we already checked today
    if (Test-Path $versionCacheFile) {
        $cacheTime = (Get-Item $versionCacheFile -Force).LastWriteTime
        $currentTime = Get-Date
        $timeDiff = ($currentTime - $cacheTime).TotalSeconds
        
        # If cache is less than 24 hours old, use cached result
        if ($timeDiff -lt 10) {
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
                
                # If no version in cache, set default and save it
                if (-not $moduleVersion) {
                    $moduleVersion = "1.6.0"
                    $versionContent = "CURRENT_VERSION:$moduleVersion`nLAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                    
                    # Make cache file hidden
                    if (Test-Path $versionCache) {
                        try {
                            $file = Get-Item $versionCache -Force
                            $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden
                        } catch {
                            # Ignore if can't set hidden attribute
                        }
                    }
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
                    
                    # Update version cache with comprehensive info
                    $versionContent = @"
CURRENT_VERSION:$moduleVersion
LATEST_VERSION:$latestVersion
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:$($result.Split(':')[0])
"@
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                    
                } catch {
                    $result = "ERROR_CHECKING_UPDATES"
                    
                    # Still update cache with current version and error status
                    $versionContent = @"
CURRENT_VERSION:$moduleVersion
LATEST_VERSION:UNKNOWN
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:ERROR_CHECKING_UPDATES
"@
                    Set-Content -Path $versionCache -Value $versionContent -ErrorAction SilentlyContinue
                }
            
            # Write to session cache for immediate use
            Set-Content -Path $sessionCache -Value $result -ErrorAction SilentlyContinue
            
            # Make version cache file hidden
            if (Test-Path $versionCache) {
                try {
                    $file = Get-Item $versionCache -Force
                    $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden
                } catch {
                    # Ignore if can't set hidden attribute
                }
            }
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

                # Get recent changes from git (if available) - quick check only
                $changelog = ""
                try {
                    $scriptDir = Split-Path -Parent $PSScriptRoot
                    if (Test-Path (Join-Path $scriptDir ".git")) {
                        $gitPath = Get-Command git -ErrorAction SilentlyContinue
                        if ($gitPath) {
                            $gitOutput = git -C $scriptDir log --oneline -3 --pretty=format:"%s" 2>$null
                            if ($gitOutput) {
                                $changelog = $gitOutput -join "`n"
                            }
                        }
                    }
                } catch {
                    # Ignore git errors
                }
                
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
    
    $moduleDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $versionCacheFile = Join-Path $moduleDir ".th_version_cache"
    
    $versionContent = @"
CURRENT_VERSION:$NewVersion
LATEST_VERSION:$NewVersion
LAST_CHECK:$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
STATUS:UP_TO_DATE
"@
    
    Set-Content -Path $versionCacheFile -Value $versionContent
    
    # Make cache file hidden
    if (Test-Path $versionCacheFile) {
        try {
            $file = Get-Item $versionCacheFile -Force
            $file.Attributes = $file.Attributes -bor [System.IO.FileAttributes]::Hidden
        } catch {
            # Ignore if can't set hidden attribute
        }
    }
    
    Write-Host "Version updated to $NewVersion" -ForegroundColor Green
}

# Function to download and install update from GitHub
function install_th_update {
    param(
        [string]$Version,
        [string]$Indent = ""
    )
    
    Write-Host ($Indent + "Installing TH version $Version...") -ForegroundColor Green
    
    try {
        $moduleDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "th_update_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download and extract
        $downloadUrl = "https://github.com/YouLend/windows-tools/archive/refs/tags/th-v$Version.zip"
        $zipPath = Join-Path $tempDir "th-v$Version.zip"
        
        Write-Host ($Indent + "Downloading from GitHub...") -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
        
        Write-Host ($Indent + "Extracting files...") -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Backup version cache
        $versionCacheFile = Join-Path $moduleDir ".th_version_cache"
        $versionCacheBackup = $null
        if (Test-Path $versionCacheFile) {
            $versionCacheBackup = Get-Content $versionCacheFile -Raw
        }
        
        # Replace files
        Write-Host ($Indent + "Installing new files...") -ForegroundColor Cyan
        Get-ChildItem -Path $moduleDir -Exclude ".th_version_cache" | Remove-Item -Recurse -Force
        Copy-Item -Path "$tempDir\windows-tools-th-v$Version\th\*" -Destination $moduleDir -Recurse -Force
        
        # Update version cache
        update_current_version $Version
        
        # Cleanup
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host ($Indent + "✅ Update completed!") -ForegroundColor Green
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


