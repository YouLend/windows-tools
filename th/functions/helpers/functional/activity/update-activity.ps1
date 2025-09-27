function update_th_activity {
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $thDir = Join-Path $userProfile ".th"
    $activityFile = Join-Path $thDir "activity"

    # Create .th directory if it doesn't exist
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

    # Read existing activity data or create new
    $activityData = @{}
    if (Test-Path $activityFile) {
        try {
            $lines = Get-Content $activityFile
            foreach ($line in $lines) {
                if ($line -match "^([^:]+):\s*(.+)$") {
                    $activityData[$matches[1]] = $matches[2]
                }
            }
        } catch {
            # Ignore read errors
        }
    }

    # Update activity data
    $activityData["LAST_ACTIVITY"] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    # Set default timeout if not configured
    if (-not $activityData.ContainsKey("INACTIVITY_TIMEOUT_MINUTES")) {
        $activityData["INACTIVITY_TIMEOUT_MINUTES"] = "30"
    }

    # Write back to activity file
    $output = @()
    foreach ($key in $activityData.Keys) {
        $output += "${key}: $($activityData[$key])"
    }
    $output | Out-File -FilePath $activityFile -Force

    # Start/restart the inactivity monitor
    start_th_inactivity_monitor
}