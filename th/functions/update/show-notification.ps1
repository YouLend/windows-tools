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
