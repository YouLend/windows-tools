function create_notification {
    param(
        [string]$current_version,
        [string]$latest_version,
        [string]$Changelog = ""
    )
    
    $title = "📦 Update Available!"
    $titleLen = $title.Length
    
    # Use pre-captured terminal output (captured before command execution)
    $savedOutput = @()
    $savedCursorPos = $null
    if ($global:PreCommandOutput) {
        $savedOutput = $global:PreCommandOutput
        $savedCursorPos = $global:PreCommandCursorPos
    }
    
    # Clear screen
    Clear-Host
    
    # Simple message length for width calculation
    $messageText = "Would you like to update now? $current_version >> $latest_version"
    $maxMessageLen = $messageText.Length
    
    # Determine the width based on the longer content + padding
    $contentWidth = [Math]::Max($titleLen, $maxMessageLen)
    $boxWidth = $contentWidth + 10
    
    # Apply max width constraint of 65
    if ($boxWidth -gt 65) {
        $boxWidth = 65
    }
    
    $indent = "    "  # 4 spaces indent for alignment
    
    # Top border with block characters
    Write-Host ($indent + "    " + ([string][char]0x2581) * ($boxWidth - 2))
    Write-Host ($indent + "   " + ([string][char]0x2584) * ($boxWidth - 2)) -ForegroundColor DarkGray
    
    # Title section with centering
    $titlePadding = [Math]::Floor(($boxWidth - $titleLen - 4) / 2)
    $titlePadding = [Math]::Max(0, $titlePadding)  # Ensure padding is never negative
    Write-Host ($indent + "  ") -NoNewline
    Write-Host ((" " * $titlePadding) + $Title + (" " * ($titlePadding + 3))) -BackgroundColor DarkGray -ForegroundColor White
    
    # Message section with colored versions
    $linePadding = [Math]::Floor(($boxWidth - $maxMessageLen - 4) / 2)
    $linePadding = [Math]::Max(0, $linePadding)
    Write-Host ($indent + " ") -NoNewline
    Write-Host (" " * $linePadding) -BackgroundColor DarkGray -NoNewline
    Write-Host "Would you like to update now? " -BackgroundColor DarkGray -NoNewline
    Write-Host $current_version -BackgroundColor DarkGray -ForegroundColor Red -NoNewline
    Write-Host " >> " -BackgroundColor DarkGray -NoNewline
    Write-Host $latest_version -BackgroundColor DarkGray -ForegroundColor Green -NoNewline
    Write-Host (" " * ($linePadding + 2)) -BackgroundColor DarkGray
    
    # Bottom border
    Write-Host ($indent + ([string][char]0x2580) * ($boxWidth - 2)) -ForegroundColor DarkGray
    Write-Host ($indent + ([string][char]0x2594) * ($boxWidth - 2))

    # If changelog is provided, add it below the notification box
    if ($Changelog) {
        Write-Host ""
        Write-Host ($indent + "Recent changes:") -ForegroundColor Cyan
        # Display changelog entries as bullet points
        $changelogLines = $Changelog -split "`r?`n"
        foreach ($line in $changelogLines) {
            if ($line.Trim()) {
                Write-Host ($indent + "• " + $line)
            }
        }
    }

    $result = embedded_horizontal_menu $indent $boxWidth
    
    # Handle the update logic based on user selection
    if ($result -eq 0) {  # Yes selected
        # Clear the menu lines first
        $console = $Host.UI.RawUI
        $currentPos = $console.CursorPosition
        
        # Move cursor back and clear the menu area (3 lines: menu + blank + instructions)
        for ($i = 0; $i -lt 3; $i++) {
            [Console]::SetCursorPosition(0, $currentPos.Y - $i - 1)
            Write-Host (" " * [Console]::WindowWidth)
        }
        
        # Position cursor back to where menu started
        [Console]::SetCursorPosition(0, $currentPos.Y - 4)
        
        Write-Host ""
        Write-Host ($indent + "Updating th...") -ForegroundColor Green
        Write-Host ""
        
        try {
            $output = choco info th --version=1.5.0
            $output | ForEach-Object { 
                Write-Host ($indent + $_)
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host ($indent + "th updated successfully!") -ForegroundColor Green
                Write-Host ""
            } else {
                Write-Host ""
                Write-Host ($indent + "Update failed. Please try manually.") -ForegroundColor Red
                Write-Host ""
            }
        } catch {
            Write-Host ""
            Write-Host ($indent + "Update failed: " + $_.Exception.Message) -ForegroundColor Red
            Write-Host ""
        }
        
        Write-Host ($indent + "Press enter to continue...")
        Read-Host
        
        # Restore the saved terminal output
        Clear-Host
        if ($savedOutput.Count -gt 0) {
            foreach ($line in $savedOutput) {
                Write-Host $line
            }
            # Position cursor at the end
            if ($savedCursorPos) {
                try {
                    [Console]::SetCursorPosition(0, $savedOutput.Count)
                } catch {
                    # Ignore cursor positioning errors
                }
            }
        }
        
    } elseif ($result -eq 1) {  # No selected
        # Clear the menu lines first
        $console = $Host.UI.RawUI
        $currentPos = $console.CursorPosition
        
        # Move cursor back and clear the menu area (3 lines: menu + blank + instructions)
        for ($i = 0; $i -lt 3; $i++) {
            [Console]::SetCursorPosition(0, $currentPos.Y - $i - 1)
            Write-Host (" " * [Console]::WindowWidth)
        }
        
        # Position cursor back to where menu started
        [Console]::SetCursorPosition(0, $currentPos.Y - 3)
        
        # Mute notifications
        $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
        $cacheDir = Join-Path $userProfile ".cache"
        $dailyCacheFile = Join-Path $cacheDir "th_update_check"
        
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        Set-Content -Path $dailyCacheFile -Value "MUTED"
        
        Write-Host ($indent + "Update notifications muted until tomorrow.") -ForegroundColor White
        Start-Sleep -Seconds 2
        
        # Restore the saved terminal output
        Clear-Host
        if ($savedOutput.Count -gt 0) {
            foreach ($line in $savedOutput) {
                Write-Host $line
            }
            # Position cursor at the end
            if ($savedCursorPos) {
                try {
                    [Console]::SetCursorPosition(0, $savedOutput.Count)
                } catch {
                    # Ignore cursor positioning errors
                }
            }
        }
    }
}