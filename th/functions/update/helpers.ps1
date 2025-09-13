# Background update checker
function check_th_updates_background {
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $cacheDir = Join-Path $userProfile ".cache"
    $dailyCacheFile = Join-Path $cacheDir "th_update_check"
    $sessionCacheFile = Join-Path ([System.IO.Path]::GetTempPath()) ("th_update_check_session_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    
    # Create cache directory if it doesn't exist
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    # Check if we already checked today
    if (Test-Path $dailyCacheFile) {
        $cacheTime = (Get-Item $dailyCacheFile).LastWriteTime
        $currentTime = Get-Date
        $timeDiff = ($currentTime - $cacheTime).TotalSeconds
        
        # If cache is less than 24 hours old, use cached result
        if ($timeDiff -lt 86400) {
            try {
                $cachedResult = Get-Content $dailyCacheFile -Raw -ErrorAction Stop
                # If muted, keep it muted until time passes
                if ($cachedResult.Trim() -eq "MUTED") {
                    Copy-Item $dailyCacheFile $sessionCacheFile -ErrorAction SilentlyContinue
                    return $sessionCacheFile
                } else {
                    Copy-Item $dailyCacheFile $sessionCacheFile -ErrorAction SilentlyContinue
                    return $sessionCacheFile
                }
            } catch {
                # If can't read cache, continue with fresh check
            }
        }
    }
    
    # Start background process
    $job = Start-Job -ScriptBlock {
        param($dailyCache, $sessionCache)
        
        try {
            # Use GitHub API to check for updates
            $repo = "YouLend/windows-tools"
            $apiUrl = "https://api.github.com/repos/$repo/releases/latest"
            
            # Normal update check
            $forceUpdate = $false
                
                # Get current version from the module or th.psm1
                $moduleVersion = $null
                try {
                    # First try to get from loaded module
                    $loadedModule = Get-Module th
                    if ($loadedModule) {
                        $moduleVersion = $loadedModule.Version.ToString()
                    } else {
                        # Try to get from available modules
                        $moduleInfo = Get-Module th -ListAvailable | Select-Object -First 1
                        if ($moduleInfo) {
                            $moduleVersion = $moduleInfo.Version.ToString()
                        }
                    }
                    
                    # If still null, try to read from th.psm1 file
                    if (-not $moduleVersion) {
                        $scriptDir = Split-Path -Parent $PSScriptRoot
                        $thmPsm1 = Join-Path $scriptDir "th.psm1"
                        if (Test-Path $thmPsm1) {
                            $content = Get-Content $thmPsm1 -Raw
                            if ($content -match '\$version\s*=\s*"([^"]+)"') {
                                $moduleVersion = $matches[1]
                            }
                        }
                    }
                } catch {
                    # Ignore errors
                }
                
                # Final fallback to hardcoded version
                if (-not $moduleVersion) {
                    $moduleVersion = "1.6.0"
                }
                
                # Get latest release from GitHub
                try {
                    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                    $latestVersion = $response.tag_name -replace '^v', ''  # Remove 'v' prefix if present
                    
                    # Compare versions
                    if ($moduleVersion -ne $latestVersion) {
                        $result = "UPDATE_AVAILABLE:" + $moduleVersion + ":" + $latestVersion
                    } else {
                        $result = "UP_TO_DATE"
                    }
                } catch {
                    $result = "ERROR_CHECKING_UPDATES"
                }
            
            # Write to both cache files
            Set-Content -Path $dailyCache -Value $result -ErrorAction SilentlyContinue
            Set-Content -Path $sessionCache -Value $result -ErrorAction SilentlyContinue
        } catch {
            $errorResult = "ERROR_CHECKING_UPDATES"
            Set-Content -Path $dailyCache -Value $errorResult -ErrorAction SilentlyContinue
            Set-Content -Path $sessionCache -Value $errorResult -ErrorAction SilentlyContinue
        }
    } -ArgumentList $dailyCacheFile, $sessionCacheFile
    
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
                
                create_notification -Title "Update Available!" -Message "Would you like to update now? $currentVersion to $latestVersion" -ShowPrompt $true -Changelog $changelog
            }
        }
    }
    
    # Clean up cache file
    if (Test-Path $UpdateCacheFile) {
        Remove-Item $UpdateCacheFile -Force -ErrorAction SilentlyContinue
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


