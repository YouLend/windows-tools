function start_th_inactivity_monitor {
    # Kill any existing monitor
    Get-Job -Name "th_inactivity_monitor" -ErrorAction SilentlyContinue | Remove-Job -Force

    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $thDir = Join-Path $userProfile ".th"
    $activityFile = Join-Path $thDir "activity"

    # Read timeout from activity file, default to 30 minutes
    $timeoutMinutes = 30
    if (Test-Path $activityFile) {
        try {
            $lines = Get-Content $activityFile
            foreach ($line in $lines) {
                if ($line -match "^INACTIVITY_TIMEOUT_MINUTES:\s*(.+)$") {
                    $timeoutMinutes = [int]$matches[1].Trim()
                    break
                }
            }
        } catch {
            # Use default if can't read
        }
    }

    Start-Job -Name "th_inactivity_monitor" -ScriptBlock {
        param($timeout, $userProfile)
        $activityFile = Join-Path $userProfile ".th\activity"

        while ($true) {
            Start-Sleep 60  # Check every minute

            if (Test-Path $activityFile) {
                try {
                    $lines = Get-Content $activityFile
                    $lastActivityString = ""
                    foreach ($line in $lines) {
                        if ($line -match "^LAST_ACTIVITY:\s*(.+)$") {
                            $lastActivityString = $matches[1].Trim()
                            break
                        }
                    }

                    if ($lastActivityString) {
                        $lastActivity = Get-Date $lastActivityString
                        $inactiveMinutes = (Get-Date) - $lastActivity | Select-Object -ExpandProperty TotalMinutes

                        if ($inactiveMinutes -gt $timeout) {
                            # Run cleanup using th command
                            powershell.exe -Command "th cleanup"
                            break
                        }
                    }
                } catch {
                    # Ignore parsing errors
                }
            }
        }
    } -ArgumentList $timeoutMinutes, $userProfile | Out-Null
}

function stop_th_inactivity_monitor {
    Get-Job -Name "th_inactivity_monitor" -ErrorAction SilentlyContinue | Remove-Job -Force
}
