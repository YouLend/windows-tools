function embedded_horizontal_menu {
    param(
        [string]$center_spaces,
        [int]$box_width
    )
    
    $option1 = "Yes"
    $option2 = "No"
    $selected = 0
    $confirmCount = 0
    $firstDraw = $true
    
    # Hide cursor (PowerShell compatible)
    [Console]::CursorVisible = $false
    
    function Draw-EmbeddedMenu {
        # Move cursor up to overwrite previous menu if not first draw
        if (-not $firstDraw) {
            # Move cursor up 2 lines to overwrite previous menu and instruction
            [Console]::SetCursorPosition(0, [Console]::CursorTop - 3)
        }
        Set-Variable -Name "firstDraw" -Value $false -Scope 1
        
        # Calculate fixed positions for consistent spacing
        $option1Width = 8  # Fixed width for "Yes" + padding
        $option2Width = 8  # Fixed width for "No" + padding
        $separator = "                           "  # Fixed separator with tripled spacing
        $totalMenuWidth = $option1Width + $separator.Length + $option2Width
        $menuPadding = [math]::Floor(($box_width - $totalMenuWidth) / 2)
        $menuSpaces = " " * $menuPadding
        
        # Output the menu line with proper colors
        Write-Host "$center_spaces$menuSpaces" -NoNewline
        
        # Option 1 with fixed width and colors
        if ($selected -eq 0) {
            Write-Host " ▄" -NoNewline -ForegroundColor White
            Write-Host " $option1 " -BackgroundColor White -ForegroundColor Black -NoNewline
            Write-Host "▀" -NoNewline -ForegroundColor White
        } else {
            Write-Host "   $option1  " -NoNewline
        }
        
        # Fixed separator
        Write-Host $separator -NoNewline
        
        # Option 2 with fixed width and colors
        if ($selected -eq 1) {
            Write-Host " ▄" -NoNewline -ForegroundColor White
            Write-Host " $option2 " -BackgroundColor White -ForegroundColor Black -NoNewline
            Write-Host "▀" -NoNewline -ForegroundColor White
        } else {
            Write-Host "   $option2  " -NoNewline
        }
        
        # Pad the rest of the line to console width
        $consoleWidth = [Console]::WindowWidth
        $usedWidth = $center_spaces.Length + $menuSpaces.Length + 8 + $separator.Length + 8
        if ($usedWidth -lt $consoleWidth) {
            Write-Host (" " * ($consoleWidth - $usedWidth))
        } else {
            Write-Host ""
        }
        
        Write-Host
        # Instructions line centered relative to notification box
        $instructionText = if ($confirmCount -eq 0) {
            "Use ←→ arrows to navigate, press twice to confirm"
        } else {
            "Press again to confirm selection"
        }
        $instWidth = $instructionText.Length
        $instPadding = [math]::Floor(($box_width - $instWidth) / 2)
        $instSpaces = " " * $instPadding
        $instructionLine = "$center_spaces$instSpaces$instructionText"
        
        # Pad instruction line to console width
        if ($instructionLine.Length -lt $consoleWidth) {
            $instructionLine += " " * ($consoleWidth - $instructionLine.Length)
        }
        
        Write-Host $instructionLine
    }
    
    Draw-EmbeddedMenu
    
    # Main input loop
    while ($true) {
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            'RightArrow' {
                if ($selected -eq 0 -and $confirmCount -eq 0) {
                    $selected = 1
                    $confirmCount = 0
                    Draw-EmbeddedMenu
                } elseif ($selected -eq 1 -and $confirmCount -eq 0) {
                    # First press on right option
                    $confirmCount = 1
                    Draw-EmbeddedMenu
                } elseif ($selected -eq 1 -and $confirmCount -eq 1) {
                    # Second press - confirm selection
                    [Console]::CursorVisible = $true
                    return 1
                } elseif ($selected -eq 0 -and $confirmCount -eq 1) {
                    # In confirmation mode on left, but pressed right - move to right and reset
                    $selected = 1
                    $confirmCount = 0
                    Draw-EmbeddedMenu
                }
            }
            'LeftArrow' {
                if ($selected -eq 1 -and $confirmCount -eq 0) {
                    $selected = 0
                    $confirmCount = 0
                    Draw-EmbeddedMenu
                } elseif ($selected -eq 0 -and $confirmCount -eq 0) {
                    # First press on left option
                    $confirmCount = 1
                    Draw-EmbeddedMenu
                } elseif ($selected -eq 0 -and $confirmCount -eq 1) {
                    # Second press - confirm selection
                    [Console]::CursorVisible = $true
                    return 0
                } elseif ($selected -eq 1 -and $confirmCount -eq 1) {
                    # In confirmation mode on right, but pressed left - move to left and reset
                    $selected = 0
                    $confirmCount = 0
                    Draw-EmbeddedMenu
                }
            }
            { $_ -in @('Q', 'Escape') } {  # Quit
                [Console]::CursorVisible = $true
                return 255
            }
        }
    }
}