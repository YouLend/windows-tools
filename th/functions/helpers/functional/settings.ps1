function th_config {
    param([string[]]$Arguments = @())

    $thDir = Join-Path $HOME ".th"
    $activityFile = Join-Path $thDir "activity"
    $versionFile = Join-Path $thDir "version"

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

    # Read existing activity data
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

    # Read existing version data
    $versionData = @{}
    if (Test-Path $versionFile) {
        try {
            $lines = Get-Content $versionFile
            foreach ($line in $lines) {
                if ($line -match "^([^:]+):\s*(.+)$") {
                    $versionData[$matches[1]] = $matches[2]
                }
            }
        } catch {
            # Ignore read errors
        }
    }

    # If no arguments, show all current config
    if ($Arguments.Count -eq 0) {
        Clear-Host
        create_header "th config"

        Write-Host "Current configuration:" -ForegroundColor White
        Write-Host ""

        # Show inactivity timeout
        $currentTimeout = if ($activityData.ContainsKey("INACTIVITY_TIMEOUT_MINUTES")) { $activityData["INACTIVITY_TIMEOUT_MINUTES"] } else { "30" }
        Write-Host "• inactivity timeout (" -NoNewLine
        Write-Host "timeout" -ForegroundColor White -NoNewLine
        Write-Host "): " -NoNewLine
        if ($currentTimeout -eq "OFF") {
            Write-Host "disabled" -ForegroundColor Red
        } else {
            Write-Host "$currentTimeout minutes" -ForegroundColor Green
        }

        # Show update suppression
        $currentSuppression = if ($versionData.ContainsKey("UPDATE_SUPPRESSION_HOURS")) { $versionData["UPDATE_SUPPRESSION_HOURS"] } else { "24" }
        Write-Host "• update notification suppression (" -NoNewLine
        Write-Host "update" -NoNewLine -ForegroundColor White
        Write-Host "): " -NoNewLine
        Write-Host "$currentSuppression hours" -ForegroundColor Green

        Write-Host ""
        return
    }

    $option = $Arguments[0].ToLower()
    $value = if ($Arguments.Count -gt 1) { $Arguments[1] } else { "" }

    switch ($option) {
        { $_ -in @("inactivity-timeout", "timeout") } {
            if (-not $value) {
                Write-Host "❌ Missing value for inactivity-timeout. Usage: th config inactivity-timeout <minutes|off>" -ForegroundColor Red
                return
            }

            # Check if user wants to turn off monitoring
            if ($value.ToLower() -eq "off") {
                # Update activity data to OFF
                $activityData["INACTIVITY_TIMEOUT_MINUTES"] = "OFF"

                # Preserve last activity if it exists
                if (-not $activityData.ContainsKey("LAST_ACTIVITY")) {
                    $activityData["LAST_ACTIVITY"] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }

                # Write back to activity file
                $output = @()
                foreach ($key in $activityData.Keys) {
                    $output += "${key}: $($activityData[$key])"
                }
                $output | Out-File -FilePath $activityFile -Force

                # Stop the inactivity monitor
                stop_th_inactivity_monitor

                Clear-Host
                create_header "th config"
                Write-Host "✅ Inactivity timeout " -NoNewLine
                Write-Host "disabled`n" -ForegroundColor Green
            } else {
                # Validate input as number
                $timeoutValue = 0
                if (-not [int]::TryParse($value, [ref]$timeoutValue) -or $timeoutValue -le 0) {
                    Write-Host "❌ Invalid timeout value. Please enter a positive number or 'off'." -ForegroundColor Red
                    return
                }

                # Update activity data with new timeout
                $activityData["INACTIVITY_TIMEOUT_MINUTES"] = $timeoutValue.ToString()

                # Preserve last activity if it exists
                if (-not $activityData.ContainsKey("LAST_ACTIVITY")) {
                    $activityData["LAST_ACTIVITY"] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }

                # Write back to activity file
                $output = @()
                foreach ($key in $activityData.Keys) {
                    $output += "${key}: $($activityData[$key])"
                }
                $output | Out-File -FilePath $activityFile -Force
                Clear-Host
                create_header "th config"
                Write-Host "✅ Inactivity timeout updated to " -NoNewLine
                Write-Host "$timeoutValue minutes`n" -ForegroundColor Green

                # Restart the inactivity monitor with new timeout
                start_th_inactivity_monitor
            }
        }
        { $_ -in @("update-suppression", "update") } {
            if (-not $value) {
                Write-Host "❌ Missing value for update-suppression. Usage: th config update-suppression <hours>" -ForegroundColor Red
                return
            }

            # Validate input
            $suppressionValue = 0
            if (-not [int]::TryParse($value, [ref]$suppressionValue) -or $suppressionValue -le 0) {
                Write-Host "❌ Invalid suppression value. Please enter a positive number." -ForegroundColor Red
                return
            }

            # Update version data with new suppression
            $versionData["UPDATE_SUPPRESSION_HOURS"] = $suppressionValue.ToString()

            # Write back to version file
            $output = @()
            foreach ($key in $versionData.Keys) {
                $output += "${key}: $($versionData[$key])"
            }
            $output | Out-File -FilePath $versionFile -Force

            Clear-Host
            create_header "th config"
            Write-Host "✅ Update suppression updated to " -NoNewLine
            Write-Host "$suppressionValue hour/s`n" -ForegroundColor Green
        }
        default {
            Clear-Host
            create_header "th config"
            Write-Host "❌ Unknown configuration option: $option" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available options:" -ForegroundColor White
            Write-Host "• inactivity timeout (timeout) <minutes>   - Set inactivity timeout in minutes." -ForegroundColor Gray
            Write-Host "• update suppression (update) <hours> - Set update check suppression in hours." -ForegroundColor Gray
            Write-Host ""
        }
    }
}