function create_notification {
    param(
        [string]$current_version,
        [string]$latest_version,
        [string]$Changelog = ""
    )
    
    $title = "📦 Update Available!"
    $titleLen = $title.Length
    
    # Capture current terminal state before clearing
    $savedOutput = @()
    $savedCursorPos = $null
    
    try {
        $console = $Host.UI.RawUI
        $cursorPos = $console.CursorPosition
        $savedCursorPos = $cursorPos
        
        # Calculate rectangle coordinates for buffer capture
        $left = 0
        $top = 0
        $right = $console.BufferSize.Width - 1
        $bottom = $cursorPos.Y
        
        # Only capture if there's content to capture
        if ($bottom -ge $top -and $bottom -lt $console.BufferSize.Height) {
            $rect = New-Object System.Management.Automation.Host.Rectangle($left, $top, $right, $bottom)
            $buffer = $console.GetBufferContents($rect)
            
            # Convert buffer to objects preserving both characters and colors
            for ($y = 0; $y -lt $buffer.GetLength(0); $y++) {
                $lineData = @()
                for ($x = 0; $x -lt $buffer.GetLength(1); $x++) {
                    $char = $buffer[$y, $x].Character
                    # Handle Unicode/emoji characters properly
                    if ([char]::IsControl($char) -and $char -ne "`t" -and $char -ne "`n" -and $char -ne "`r") {
                        $char = " "  # Replace control chars with space except tab/newline
                    }
                    $lineData += @{
                        Character = $char
                        ForegroundColor = $buffer[$y, $x].ForegroundColor
                        BackgroundColor = $buffer[$y, $x].BackgroundColor
                    }
                }
                $savedOutput += @{
                    LineData = $lineData
                    IsColoredLine = $true
                }
            }
        }
    } catch {
        # If buffer reading fails, just continue without restoration
        $savedOutput = @()
        $savedCursorPos = $null
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

    # Track changelog line count for clearing later
    $script:changelogRenderedLines = 0

    # If changelog is provided, add it below the notification box
    if ($Changelog) {
        
        # First pass: find the longest changelog line
        $changelogLines = $Changelog -split "`r?`n"
        $maxChangelogLen = 0
        foreach ($line in $changelogLines) {
            if ($line.Trim()) {
                # Remove markdown dashes and convert to bullet
                $cleanLine = $line -replace '^- ', ''
                $changelogLine = "• $cleanLine"
                $changelogLen = $changelogLine.Length
                if ($changelogLen -gt $maxChangelogLen) {
                    $maxChangelogLen = $changelogLen
                }
            }
        }
        
        $padding = [Math]::Floor($boxWidth / 7)

        $changelogSpaces = " " * $padding
        
        # Second pass: display all lines with wrapping
        $maxLineWidth = $boxWidth - $changelogSpaces.Length - 4
        foreach ($line in $changelogLines) {
            if ($line.Trim()) {
                # Remove markdown dashes and convert to bullet
                $cleanLine = $line -replace '^- ', ''
                $changelogLine = "• $cleanLine"
                
                # Wrap long lines preserving words
                if ($changelogLine.Length -gt $maxLineWidth) {
                    $remaining = $cleanLine
                    $firstLine = $true
                    while ($remaining.Length -gt 0) {
                        if ($firstLine) {
                            $prefix = "• "
                            $available = $maxLineWidth - 2
                            $firstLine = $false
                        } else {
                            $prefix = "  "
                            $available = $maxLineWidth - 2
                        }
                        
                        if ($remaining.Length -le $available) {
                            Write-Host ($indent + $changelogSpaces + $prefix + $remaining)
                            $script:changelogRenderedLines++
                            break
                        }
                        
                        # Find last space within available length
                        $chunk = $remaining.Substring(0, $available)
                        $lastSpaceIndex = $chunk.LastIndexOf(' ')
                        if ($lastSpaceIndex -gt 0) {
                            $chunk = $chunk.Substring(0, $lastSpaceIndex)
                        }
                        
                        Write-Host ($indent + $changelogSpaces + $prefix + $chunk)
                        $script:changelogRenderedLines++
                        $remaining = $remaining.Substring($chunk.Length + 1)
                    }
                } else {
                    Write-Host ($indent + $changelogSpaces + $changelogLine)
                    $script:changelogRenderedLines++
                }
            }
        }
        Write-Host ""
        $script:changelogRenderedLines++  # Count the blank line
    }

    $result = embedded_horizontal_menu $indent $boxWidth
    
    # Handle the update logic based on user selection
    if ($result -eq 0) {  # Yes selected
        # Clear the menu and changelog lines
        $console = $Host.UI.RawUI
        $currentPos = $console.CursorPosition
        
        # Calculate total lines to clear (menu + changelog)
        $linesToClear = 3  # menu + blank + instructions
        if ($Changelog) {
            $linesToClear += $script:changelogRenderedLines
        }
        
        # Move cursor back and clear all lines
        for ($i = 0; $i -lt $linesToClear; $i++) {
            [Console]::SetCursorPosition(0, $currentPos.Y - $i - 1)
            Write-Host (" " * [Console]::WindowWidth)
        }
        
        # Position cursor back to where menu started
        [Console]::SetCursorPosition(0, $currentPos.Y - $linesToClear - 1)
        
        Write-Host ""
        
        $updateResult = install_th_update $latest_version $indent
        
        if ($updateResult) {
            Write-Host ($indent + "✅ th updated successfully to version ") -NoNewLine
            Write-Host "$latest_version" -NoNewLine -ForegroundColor Green
            Write-Host "!`n"
        } else {
            Write-Host ""
            Write-Host ($indent + "❌ Update failed. Please try again later.") -ForegroundColor Red
            Write-Host ""
        }
        
        Write-Host ($indent + "Press enter to continue...")
        Read-Host
        
        # Restore the saved terminal output with colors
        Clear-Host
        if ($savedOutput.Count -gt 0) {
            foreach ($lineObj in $savedOutput) {
                if ($lineObj.IsColoredLine) {
                    # Reconstruct the line with colors
                    $lineText = ""
                    $currentFg = $null
                    $currentBg = $null
                    
                    foreach ($charObj in $lineObj.LineData) {
                        # If colors changed, output what we have and start fresh
                        if ($charObj.ForegroundColor -ne $currentFg -or $charObj.BackgroundColor -ne $currentBg) {
                            if ($lineText) {
                                if ($currentFg -ne $null -and $currentBg -ne $null) {
                                    Write-Host $lineText -NoNewline -ForegroundColor $currentFg -BackgroundColor $currentBg
                                } elseif ($currentFg -ne $null) {
                                    Write-Host $lineText -NoNewline -ForegroundColor $currentFg
                                } else {
                                    Write-Host $lineText -NoNewline
                                }
                                $lineText = ""
                            }
                            $currentFg = $charObj.ForegroundColor
                            $currentBg = $charObj.BackgroundColor
                        }
                        $lineText += $charObj.Character
                    }
                    
                    # Output remaining text
                    if ($lineText) {
                        if ($currentFg -ne $null -and $currentBg -ne $null) {
                            Write-Host $lineText -ForegroundColor $currentFg -BackgroundColor $currentBg
                        } elseif ($currentFg -ne $null) {
                            Write-Host $lineText -ForegroundColor $currentFg
                        } else {
                            Write-Host $lineText
                        }
                    } else {
                        Write-Host ""  # Empty line
                    }
                } else {
                    Write-Host $lineObj
                }
            }
            
            # Position cursor at the end (accounting for the line we moved up)
            if ($savedCursorPos) {
                try {
                    [Console]::SetCursorPosition(0, $savedOutput.Count - 1)
                } catch {
                    # Ignore cursor positioning errors
                }
            }
        }
        
    } elseif ($result -eq 1) {  # No selected
        # Clear the menu and changelog lines
        $console = $Host.UI.RawUI
        $currentPos = $console.CursorPosition
        
        # Calculate total lines to clear (menu + changelog)
        $linesToClear = 3  # menu + blank + instructions
        if ($Changelog) {
            $linesToClear += $script:changelogRenderedLines
        }
        
        # Move cursor back and clear all lines
        for ($i = 0; $i -lt $linesToClear; $i++) {
            [Console]::SetCursorPosition(0, $currentPos.Y - $i - 1)
            Write-Host (" " * [Console]::WindowWidth)
        }
        
        # Position cursor back to where menu started
        [Console]::SetCursorPosition(0, $currentPos.Y - $linesToClear)
        
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
        
        # Restore the saved terminal output with colors
        Clear-Host
        if ($savedOutput.Count -gt 0) {
            foreach ($lineObj in $savedOutput) {
                if ($lineObj.IsColoredLine) {
                    # Reconstruct the line with colors
                    $lineText = ""
                    $currentFg = $null
                    $currentBg = $null
                    
                    foreach ($charObj in $lineObj.LineData) {
                        # If colors changed, output what we have and start fresh
                        if ($charObj.ForegroundColor -ne $currentFg -or $charObj.BackgroundColor -ne $currentBg) {
                            if ($lineText) {
                                if ($currentFg -ne $null -and $currentBg -ne $null) {
                                    Write-Host $lineText -NoNewline -ForegroundColor $currentFg -BackgroundColor $currentBg
                                } elseif ($currentFg -ne $null) {
                                    Write-Host $lineText -NoNewline -ForegroundColor $currentFg
                                } else {
                                    Write-Host $lineText -NoNewline
                                }
                                $lineText = ""
                            }
                            $currentFg = $charObj.ForegroundColor
                            $currentBg = $charObj.BackgroundColor
                        }
                        $lineText += $charObj.Character
                    }
                    
                    # Output remaining text
                    if ($lineText) {
                        if ($currentFg -ne $null -and $currentBg -ne $null) {
                            Write-Host $lineText -ForegroundColor $currentFg -BackgroundColor $currentBg
                        } elseif ($currentFg -ne $null) {
                            Write-Host $lineText -ForegroundColor $currentFg
                        } else {
                            Write-Host $lineText
                        }
                    } else {
                        Write-Host ""  # Empty line
                    }
                } else {
                    Write-Host $lineObj
                }
            }
            
            # Position cursor at the end (accounting for the line we moved up)
            if ($savedCursorPos) {
                try {
                    [Console]::SetCursorPosition(0, $savedOutput.Count - 1)
                } catch {
                    # Ignore cursor positioning errors
                }
            }
        }
    }
}