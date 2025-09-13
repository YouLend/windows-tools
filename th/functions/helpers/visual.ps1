# ========================================================================================================================
#                                                       Visual Helpers
# ========================================================================================================================

function wave_loader {
    param (
        [int]$JobId,
        [int]$Pid,
        [string]$Message = "Loading..."
    )


    $headerWidth = 65
    $waveLen = $headerWidth
    $blocks = @("▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
    $pos = 0
    $direction = 1

    $msgLen = $Message.Length
    $msgWithSpacesLen = $msgLen + 2
    $msgStart = [math]::Floor(($waveLen - $msgWithSpacesLen) / 2)
    $msgEnd = $msgStart + $msgWithSpacesLen

    try {
        while (($JobId -and (Get-Job -Id $JobId -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Running' })) -or ($Pid -and (Get-Process -Id $Pid -ErrorAction SilentlyContinue))) {
            $line = ""
            for ($i = 0; $i -lt $waveLen; $i++) {
                if ($i -eq $pos) {
                    $center = [math]::Floor($waveLen / 2)
                    $distance = [math]::Abs($pos - $center)
                    $maxDist = [math]::Floor($waveLen / 2)
                    $boost = 7 - [math]::Floor($distance * 7 / $maxDist)
                    if ($boost -lt 0) { $boost = 0 }
                    $line += "$($blocks[$boost])"
                }
                elseif ($i -ge $msgStart -and $i -lt $msgEnd) {
                    $charIdx = $i - $msgStart
                    if ($charIdx -eq 0 -or $charIdx -eq ($msgWithSpacesLen - 1)) {
                        $line += " "
                    }
                    else {
                        $msgCharIdx = $charIdx - 1
                        $line += $Message[$msgCharIdx]
                    }
                }
                else {
                    $line += " "
                }
            }

            Write-Host "`r$line" -NoNewline

            $pos += $direction
            if ($pos -lt 0 -or $pos -ge $waveLen) {
                $direction *= -1
                $pos += $direction
            }

            $center = [math]::Floor($waveLen / 2)
            $distance = [math]::Abs($pos - $center)
            $maxDist = [math]::Floor($waveLen / 2)

            # Speed adjustment
            if ($distance -gt $maxDist * 0.9) {
                Start-Sleep -Milliseconds 30
            }
            elseif ($distance -gt $maxDist * 0.8) {
                Start-Sleep -Milliseconds 20
            }
            elseif ($distance -gt $maxDist * 0.75) {
                Start-Sleep -Milliseconds 10
            }
            elseif ($distance -gt $maxDist / 2) {
                Start-Sleep -Milliseconds 5
            }
            else {
                Start-Sleep -Milliseconds 5
            }
        }
    }
    finally {
        # Clear the entire line and move cursor to beginning
        Write-Host "`r$(' ' * 80)`r" -NoNewline
    }
}

function center_content {
    param([int]$ContentWidth = 65)
    
    # Get terminal width and calculate centering
    $termWidth = $Host.UI.RawUI.WindowSize.Width
    $padding = [math]::Floor(($termWidth - $ContentWidth) / 2)
    
    # Create padding string
    return ' ' * [math]::Max(0, $padding)
}

function cprintf {
    param([string]$text)
    
    $centerSpaces = center_content
    Write-Host "$centerSpaces$text" -NoNewline
}

function ccode {
    param([string]$text)
    
    Write-Host "" -ForegroundColor White -NoNewLine
    Write-Host "$text" -NoNewline -BackgroundColor White -ForegroundColor Black
    Write-Host "" -ForegroundColor White -NoNewLine
}

function create_header {
    param (
        [string]$HeaderText,
        [string]$CenterSpaces
    )

    $headerLength = $HeaderText.Length
    $totalDashCount = 52
    $availableDashCount = $totalDashCount - ($headerLength - 5)

    if ($availableDashCount -lt 2) {
        $availableDashCount = 2
    }

    $leftDashes = [math]::Floor($availableDashCount / 2)
    $rightDashes = $availableDashCount - $leftDashes

    $leftDashStr = ('━' * $leftDashes)
    $rightDashStr = ('━' * $rightDashes)

    # Top ruler
    Write-Host ""
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀" -ForegroundColor DarkGray

    # Center header line
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "  $leftDashStr " -NoNewLine
    Write-Host "$HeaderText " -NoNewLine -ForegroundColor White
    Write-Host "$rightDashStr" -ForegroundColor White

    # Bottom ruler
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀" -ForegroundColor DarkGray
    Write-Host ""
}

function create_note {
    param (
        [string]$NoteText
    )
    # Print note with ANSI-style formatting using ForegroundColor
    Write-Host "`n▄██▀ $NoteText`n" -ForegroundColor DarkGray
}

function print_logo($Version, $CenterSpaces) {
    Write-Host ""
    
    Write-Host "$CenterSpaces                 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" -ForegroundColor Gray
    Write-Host "$CenterSpaces                ▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏" -ForegroundColor Gray
    Write-Host "$CenterSpaces               ▕░░░░░░░░░░░ " -NoNewline; Write-Host "████████╗ ██╗  ██╗" -ForegroundColor White -NoNewline; Write-Host " ░░░░░░░░░░░░░▏" -ForegroundColor Gray
    Write-Host "$CenterSpaces              ▕▒▒▒▒▒▒▒▒▒▒▒ " -NoNewline; Write-Host "╚══██╔══╝ ██║  ██║" -ForegroundColor White -NoNewline; Write-Host " ▒▒▒▒▒▒▒▒▒▒▒▒▒▏" 
    Write-Host "$CenterSpaces             ▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓ " -NoNewline; Write-Host "█▉║    ███████║" -ForegroundColor White -NoNewline; Write-Host " ▓▓▓▓▓▓▓▓▓▓▓▓▓▏" 
    Write-Host "$CenterSpaces            ▕██████████████ " -NoNewline; Write-Host "█▉║    ██╔══██║" -ForegroundColor White -NoNewline; Write-Host " █████████████▏"
    Write-Host "$CenterSpaces           ▕██████████████ " -NoNewline; Write-Host "██║    ██║  ██║" -ForegroundColor White -NoNewline; Write-Host " █████████████▏" 
    Write-Host "$CenterSpaces          ▕██████████████ " -NoNewline; Write-Host "██╝    ██╝  ██╝" -ForegroundColor White -NoNewline; Write-Host " █████████████▏" 
    Write-Host "$CenterSpaces         ▕██████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█████████████▏" 
    Write-Host "$CenterSpaces          ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    Write-Host "$CenterSpaces         ■■■■■■■■■" -NoNewline -ForegroundColor DarkGray; Write-Host " Teleport Helper - v$Version " -ForegroundColor White -NoNewline; Write-Host "■■■■■■■■■" -ForegroundColor DarkGray
}

function print_help($Version) {

    $centerSpaces = center_content -ContentWidth 65

    print_logo $Version -CenterSpaces $centerSpaces
    create_header -HeaderText "Usage" -CenterSpaces $centerSpaces

    # Usage commands
    Write-Host "$centerSpaces     ╚═ th aws  [options] | a   : AWS login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th db   [options] | d   : Database login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th kube [options] | k   : Kubernetes login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th terra          | t   : Quick log-in to yl-admin." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th login          | l   : Simple log in to Teleport" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th clear          | c   : Clean up Teleport session." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th version        | v   : Show the current version." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th update         | u   : Check for th updates." -ForegroundColor White
    

    # Divider line
    Write-Host "$centerSpaces     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Note
    Write-Host "$centerSpaces     For help, and " -NoNewLine
    Write-host "[options] " -ForegroundColor White -NoNewLine 
    Write-Host "info, run " -NoNewLine
    Write-Host "th a/k/d etc.. -h" -ForegroundColor White

    # Docs section
    create_header -HeaderText "Docs" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the documentation pages:"
    Write-Host "$centerSpaces     ╚═ Quickstart:       | th qs" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ Docs:             | th doc" -ForegroundColor White

    # Extras section
    create_header -HeaderText "Extras" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the extra features:"
    Write-Host "$centerSpaces     ╚═ th loader              : Run loader animation." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th animate [option]    : Run logo animation." -ForegroundColor White
    Write-Host "$centerSpaces        ╚═ yl" -ForegroundColor White
    Write-Host "$centerSpaces        ╚═ th" -ForegroundColor White

    # Mini decorative footer
    Write-Host "$centerSpaces            ▁▁▁▁▁▁▁▁▁▁▁▁▁  " -ForegroundColor DarkGray -NoNewLine
    Write-Host "▄▄▄ ▄▁▄   "  -ForegroundColor White -NoNewLine
    Write-Host "▁▁▁▁▁▁▁▁▁▁▁▁▁▁" -ForegroundColor DarkGray
    Write-Host "$centerSpaces           ▔▔▔▔▔▔▔▔▔▔▔▔▔▔" -ForegroundColor DarkGray -NoNewLine
    Write-Host "   ▀  ▀▔▀   " -ForegroundColor White -NoNewLine
    Write-Host "▔▔▔▔▔▔▔▔▔▔▔▔▔" -ForegroundColor DarkGray -NoNewLine
}

function print_db_help {
    Clear-Host
    create_header "th database | d"
    Write-Host "Connect to our databases (RDS and MongoDB)" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th database [options] | d" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th d" -NoNewline -ForegroundColor White
    Write-Host "                 : Open interactive database selection."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th d <db-env> <port>" -NoNewline -ForegroundColor White
    Write-Host " : Quick database connect, Where:"
    Write-Host "    ║"
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<db-env>" -NoNewline -ForegroundColor White
    Write-Host "   is an abbreviation for a database, using the format:" -NoNewLine
    Write-Host " dbtype-env" -ForegroundColor White
    Write-Host "    ║             e.g. " -NoNewline
    Write-Host "r-dev" -NoNewline -ForegroundColor White
    Write-Host " would connect to the " -NoNewline
    Write-Host "dev, RDS cluster." -ForegroundColor White
    Write-Host "    ╚═ " -NoNewline
    Write-Host "[opt_args]" -NoNewline -ForegroundColor White
    Write-Host " either a port number or 'c', depending on connection method:"
    Write-Host "        ║"
    Write-Host "        ╚═ " -NoNewline
    Write-Host "[port]" -NoNewLine -ForegroundColor White
    Write-Host " an integer, 10000-50000. Useful for connection re-use in GUI's."
    Write-Host "        ║"
    Write-Host "        ╚═ " -NoNewline
    Write-Host "[c]" -NoNewline -ForegroundColor White
    Write-Host " connects via CLI (psql or mongosh)." 
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th d r-dev"
    Write-Host "        : connects to " -NoNewline
    Write-Host "db-dev-aurora-postgres-1" -ForegroundColor Green -NoNewLine
    Write-Host "."
    Write-Host " ╚═ " -NoNewline
    ccode "th d m-prod c"
    Write-Host "     : connects to " -NoNewline
    Write-Host "mongodb-YLProd-Cluster-1" -ForegroundColor Green -NoNewLine
    Write-Host " via " -NoNewline
    Write-Host "mongosh" -ForegroundColor Green -NoNewLine
    Write-Host "."
    Write-Host " ╚═ " -NoNewline
    ccode "th d m-prod 43000"
    Write-Host " : Opens " -NoNewline
    Write-Host "mongodb-YLProd-Cluster-1" -NoNewline -ForegroundColor Green
    Write-Host " in " -NoNewline
    Write-Host "MongoDB Compass" -ForegroundColor Green -NoNewLine
    Write-Host " on port " -NoNewline
    Write-Host "43000" -ForegroundColor Green -NoNewLine
    Write-Host ".`n"
}

function print_aws_help {
    Clear-Host
    create_header "th aws | a"
    Write-Host "Login to our AWS accounts." -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th aws [options] | a" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th a" -NoNewline -ForegroundColor White
    Write-Host "                      : Open interactive login."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th a <account> [opt_args]" -NoNewline -ForegroundColor White
    Write-Host " : Quick aws log-in, Where:"
    Write-Host "    ║"
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<account>" -NoNewline -ForegroundColor White
    Write-Host " is an abbreviated account name e.g." -NoNewLine
    Write-Host " dev, cpg" -NoNewLine -ForegroundColor White
    Write-Host " etc..."
    Write-Host "    ║" 
    Write-Host "    ╚═ " -NoNewline
    Write-Host "[opt_args]" -NoNewline -ForegroundColor White
    Write-Host " takes a combination of s/ss and/or b;" 
    Write-Host "       ║" 
    Write-Host "       ╚═" -NoNewLine
    Write-Host " s/ss" -NoNewLine -ForegroundColor White
    Write-Host " determines whether you login with the sudo or super_sudo "
    Write-Host "       ║  role associated with the account."
    Write-Host "       ╚═" -NoNewLine
    Write-Host " b" -NoNewLine -ForegroundColor White
    Write-Host " opens the browser for the chosen account & role."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev"
    Write-Host "     : logs you into " -NoNewline
    Write-Host "yl-development" -NoNewline -ForegroundColor Green
    Write-Host " as " -NoNewline
    Write-Host "dev" -ForegroundColor Green
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev s"
    Write-Host "   : logs you into " -NoNewline
    Write-Host "yl-development" -NoNewline -ForegroundColor Green
    Write-Host " as " -NoNewline
    Write-Host "sudo_dev" -ForegroundColor Green
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev ssb"
    Write-Host " : Opens the AWS console for super_sudo in yl-development`n"
}

function print_kube_help {
    Clear-Host
    create_header "th kube | k"
    Write-Host "Login to our Kubernetes clusters." -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th kube [options] | k" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th k" -NoNewline -ForegroundColor White
    Write-Host "           : Open interactive login."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th k <cluster>" -NoNewline -ForegroundColor White
    Write-Host " : Quick kube log-in, Where:"
    Write-Host "    ║" 
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<cluster>" -NoNewline -ForegroundColor White
    Write-Host " is an abbreviated cluster name e.g. dev, cpg etc.."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th k dev"
    Write-Host " : logs you into " -NoNewline
    Write-Host "aslive-dev-eks-blue.`n" -ForegroundColor Green
}

# ========================================================================================================================
#                                                            Extras
# ========================================================================================================================

function animate_th {
    $centerSpaces = center_content
    $version = "1.3.7"
    
    Clear-Host
    Write-Host "`e[?25l" -NoNewline  # Hide cursor
    
    Write-Host "`n`e[1mTeleport Helper - Press Enter to continue...`e[0m`n"
    
    # Create a flag file for key detection
    $flagFile = "$env:TEMP\animate_stop_$PID"
    if (Test-Path $flagFile) { Remove-Item $flagFile -Force }
    
    # Smoother shimmer with more color steps
    $colors = @(232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233)
    $frame = 0
    
    # Start background job to monitor for Enter key
    $keyJob = Start-Job -ScriptBlock {
        param($flagFile)
        $null = Read-Host
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    } -ArgumentList $flagFile
    
    # Save cursor position and clear screen properly
    Write-Host "`e[s`e[2J`e[H" -NoNewline
    
    # Animation sequence - infinite loop
    while ($true) {
        # Check if flag file exists (Enter was pressed)
        if (Test-Path $flagFile) {
            Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
            break
        }
        
        # Move cursor to home without clearing (smoother)
        Write-Host "`e[H" -NoNewline
        
        # Bottom to top shimmer wave
        $line1_color = $colors[($frame + 0) % $colors.Count]
        $line2_color = $colors[($frame + 1) % $colors.Count]
        $line3_color = $colors[($frame + 2) % $colors.Count]
        $line4_color = $colors[($frame + 3) % $colors.Count]
        $line5_color = $colors[($frame + 4) % $colors.Count]
        $line6_color = $colors[($frame + 5) % $colors.Count]
        $line7_color = $colors[($frame + 6) % $colors.Count]
        $line8_color = $colors[($frame + 7) % $colors.Count]
        $line9_color = $colors[($frame + 8) % $colors.Count]
        $line10_color = $colors[($frame + 9) % $colors.Count]
        $line11_color = $colors[($frame + 10) % $colors.Count]
        
        Write-Host "$centerSpaces        `e[38;5;${line11_color}m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁`e[0m"
        Write-Host "$centerSpaces        `e[38;5;${line10_color}m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces       `e[38;5;${line9_color}m▕░░░░░░░░░░░░░░░░░ `e[1;97m███████████╗ ███╗  ███╗`e[38;5;${line9_color}m ░░░░░░░░░░░░░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces      `e[38;5;${line8_color}m▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ `e[1;97m╚══███╔══╝  ███║  ███║`e[38;5;${line8_color}m ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▏`e[0m"
        Write-Host "$centerSpaces     `e[38;5;${line7_color}m▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ `e[1;97m███║     █████████║`e[38;5;${line7_color}m ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▏`e[0m"
        Write-Host "$centerSpaces    `e[38;5;${line6_color}m▕█████████████████████ `e[1;97m███║     ███╔══███║`e[38;5;${line6_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces   `e[38;5;${line5_color}m▕█████████████████████ `e[1;97m███║     ███║  ███║`e[38;5;${line5_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces  `e[38;5;${line4_color}m▕█████████████████████ `e[1;97m███╝     ███╝  ███╝`e[38;5;${line4_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces `e[38;5;${line4_color}m▕█████████████████████ `e[1;97m███╝     ███╝  ███╝`e[38;5;${line4_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line3_color}m▕█████████████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████████████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line2_color}m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔`e[0m"
        Write-Host ""
        
        $frame++
        Start-Sleep -Milliseconds 80
    }
    
    # Clean up background job
    Stop-Job $keyJob -ErrorAction SilentlyContinue
    Remove-Job $keyJob -Force -ErrorAction SilentlyContinue
    
    Write-Host "`e[?25h" -NoNewline  # Show cursor
    Write-Host "`n`e[1;32m✓ Ready!`e[0m`n"
}

function demo_wave_loader {
    param([string]$Message = "Demo Wave Loader")
    
    # Create a dummy background process that runs for a very long time
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-Command", "Start-Sleep -Seconds 99999" -PassThru -WindowStyle Hidden
    
    # Set up cleanup
    $cleanup = {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch {}
        Write-Host "`e[?25h`n"
        exit 0
    }
    Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null
    
    Clear-Host
    Write-Host "`nPress Ctrl+C to exit (Spam it, if it doesn't work first time!)`n`n"
    
    try {
        # Run the wave loader with the dummy process
        wave_loader -Pid $proc.Id -Message $Message
    }
    finally {
        if (!$proc.HasExited) {
            $proc.Kill()
        }
    }
}

function animate_youlend {
    $centerSpaces = center_content 92
    
    Clear-Host
    Write-Host "`e[?25l" -NoNewline  # Hide cursor
    
    # Smoother shimmer with more color steps
    $colors = @(232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233)
    $frame = 0
    
    # Save cursor position and clear screen properly
    Write-Host "`e[s`e[2J`e[H" -NoNewline
    
    # Animation sequence - infinite loop
    while ($true) {
        # Move cursor to home without clearing (smoother)
        Write-Host "`e[H" -NoNewline
        
        # Bottom to top shimmer wave
        $line1_color = $colors[($frame + 0) % $colors.Count]
        $line2_color = $colors[($frame + 1) % $colors.Count]
        $line3_color = $colors[($frame + 2) % $colors.Count]
        $line4_color = $colors[($frame + 3) % $colors.Count]
        $line5_color = $colors[($frame + 4) % $colors.Count]
        $line6_color = $colors[($frame + 5) % $colors.Count]
        $line7_color = $colors[($frame + 6) % $colors.Count]
        $line8_color = $colors[($frame + 7) % $colors.Count]
        $line9_color = $colors[($frame + 8) % $colors.Count]
        $line10_color = $colors[($frame + 9) % $colors.Count]
        $line11_color = $colors[($frame + 10) % $colors.Count]
        
        Write-Host "$centerSpaces       `e[38;5;${line11_color}m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁`e[0m"
        Write-Host "$centerSpaces       `e[38;5;${line10_color}m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces      `e[38;5;${line9_color}m▕░░░░░░░░░░ `e[1;97m██╗   ██╗ ██████╗  ██╗   ██╗ ██╗      ███████╗ ███╗   ██╗ ██████╗`e[38;5;${line9_color}m  ░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces     `e[38;5;${line8_color}m▕▒▒▒▒▒▒▒▒▒▒ `e[1;97m╚██╗ ██╔╝██╔═══██╗ ██║   ██║ ██║      ██╔════╝ ████╗  ██║ ██╔══██╗`e[38;5;${line8_color}m ▒▒▒▒▒▒▒▒▏`e[0m"
        Write-Host "$centerSpaces    `e[38;5;${line7_color}m▕▓▓▓▓▓▓▓▓▓▓ `e[1;97m ╚████╔╝ ██║   ██║ ██║   ██║ ██║      █████╗   ██╔██╗ ██║ ██║  ██║`e[38;5;${line7_color}m ▓▓▓▓▓▓▓▓▏`e[0m"
        Write-Host "$centerSpaces   `e[38;5;${line6_color}m▕██████████ `e[1;97m  ╚██╔╝  ██║   ██║ ██║   ██║ ██║      ██╔══╝   ██║╚██╗██║ ██║  ██║`e[38;5;${line6_color}m ████████▏`e[0m"
        Write-Host "$centerSpaces  `e[38;5;${line5_color}m▕██████████ `e[1;97m   ██║   ╚██████╔╝ ╚██████╔╝ ███████╗ ███████╗ ██║ ╚████║ ██████╔╝`e[38;5;${line5_color}m ████████▏`e[0m"
        Write-Host "$centerSpaces `e[38;5;${line4_color}m ██████████ `e[1;97m   ╚═╝    ╚═════╝   ╚═════╝  ╚══════╝ ╚══════╝ ╚═╝  ╚═══╝ ╚═════╝`e[38;5;${line4_color}m  ████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line3_color}m▕██████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line2_color}m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔`e[0m"
        Write-Host ""

        $frame++
        Start-Sleep -Milliseconds 80
    }
}