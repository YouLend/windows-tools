# ========================================================================================================================
#                                                    Functional Helpers
# ========================================================================================================================

function th_login {
    Clear-Host
    create_header "Login"
    Write-Host "Checking login status..."
    try {
        tsh apps logout *> $null
    } catch {
        Write-Host "TSH connection failed. Cleaning up existing sessions & reauthenticating...`n"
        th_kill
    }

    $status = tsh status 2>$null
    if ($status -match 'Logged in as:') {
        Write-Host "`nAlready logged in to Teleport!" -ForegroundColor White
        return
    }

    Write-Host "`nLogging you into Teleport..."
    
    # Start login in background
    Start-Process tsh -ArgumentList 'login', '--auth=ad', '--proxy=youlend.teleport.sh:443' -WindowStyle Hidden
    # Wait up to 15 seconds (30 x 0.5s) for login to complete
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        if (tsh status 2>$null | Select-String -Quiet 'Logged in as:') {
            Write-Host "`nLogged in successfully" -ForegroundColor Green
            return
        }
    }

    Write-Host "`nTimed out waiting for Teleport login."
    return
}

# ===========================
# Helper - Clean up session  
# ===========================
function th_kill {
    Clear-Host
    create_header "Cleanup"
    # Unset AWS environment variables
    Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_CA_BUNDLE -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ACCOUNT -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_DEFAULT_REGION -ErrorAction SilentlyContinue

    Write-Host "Cleaning up Teleport session..." -ForegroundColor White

    # Kill all running processes related to tsh
    Get-NetTCPConnection -State Listen |
        ForEach-Object {
            $tshPid = $_.OwningProcess
            $proc = Get-Process -Id $tshPid -ErrorAction SilentlyContinue
            if ($proc -and $proc.Name -match "tsh") {
                Stop-Process -Id $tshPid -Force
            }
        }
    # Kill PowerShell windows running 'tsh proxy db'
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -like "powershell*" -and $_.CommandLine -match "tsh proxy db"
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force
            Write-Host "Killed PowerShell window running proxy (PID: $($_.ProcessId))"
        }

    tsh logout *>$null
    Write-Host "`nKilled all running tsh proxies"

    # Remove all profile files from temp
    $tempDir = $env:TEMP
    $patterns = @("yl*", "tsh*", "admin_*", "launch_proxy*")
    foreach ($pattern in $patterns) {
        Get-ChildItem -Path (Join-Path $tempDir $pattern) -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Write-Host "Removed all tsh files from /tmp"

    # Remove related lines from PowerShell profile
    if (Test-Path $PROFILE) {
        $profileLines = Get-Content $PROFILE
        $filteredLines = $profileLines | Where-Object {
            $_ -notmatch 'Temp\\yl-.*\.ps1'
        }
        $filteredLines | Set-Content -Path $PROFILE -Encoding UTF8
        Write-Output "Removed all .PROFILE inserts."
    }

    # Log out of all TSH apps
    tsh apps logout 2>$null
    Write-Host "`nLogged out of all apps & proxies.`n" -ForegroundColor Green
}

function Get-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::New([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

function spinner {
    param (
        [int]$Pid,
        [string]$Message = "Loading.."
    )

    $spinChars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏".ToCharArray()
    $i = 0

    # Hide cursor
    Write-Host "`e[?25l" -NoNewline

    while (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
        $char = $spinChars[$i % $spinChars.Length]
        Write-Host "`r`e[K$char $Message" -NoNewline
        Start-Sleep -Milliseconds 100
        $i++
    }

    # Clear line and restore cursor
    Write-Host "`r`e[K" -NoNewline
    Write-Host "`e[?25h"
}

function load {
    param (
        [ScriptBlock]$Job,
        [string]$Message = "Loading..."
    )

    # Wrap the job to always import the module first
    $wrappedJob = [ScriptBlock]::Create(@"
        Import-Module '$($PSScriptRoot)\..\th.psm1' -Force
        & { $($Job.ToString()) }
"@)

    $jobInstance = Start-Job -ScriptBlock $wrappedJob

    try {
        wave_loader -JobId $jobInstance.Id -Message $Message
    }
    finally {
        Wait-Job $jobInstance | Out-Null
        $result = Receive-Job $jobInstance
        Remove-Job $jobInstance | Out-Null
    }
    
    return $result
}

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
# ========================================================================================================================
#                                                       Visual Helpers
# ========================================================================================================================

function center_content {
    param (
        [int]$ContentWidth = 65
    )

    # Get terminal width
    $termWidth = $Host.UI.RawUI.WindowSize.Width

    # Calculate padding (number of spaces)
    $padding = [math]::Max(0, ($termWidth - $ContentWidth) / 2)

    # Return string of spaces
    return ' ' * [int]$padding
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
    Write-Host "$centerSpaces     ╚═ th kube       | k   : Kubernetes login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th aws        | a   : AWS login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th db         | d   : Log into our various databases." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th terra      | t   : Quick log-in to Terragrunt." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th logout     | l   : Clean up Teleport session." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th login      | li  : Simple log in to Teleport." -ForegroundColor White
    

    # Divider line
    Write-Host "$centerSpaces     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Note
    Write-Host "$centerSpaces     For specific instructions, run th <option> -h"

    # Docs section
    create_header -HeaderText "Docs" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the documentation pages:"
    Write-Host "$centerSpaces     ╚═ Quickstart:   | th qs" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ Docs:         | th doc" -ForegroundColor White

    # Extras section
    create_header -HeaderText "Extras" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the extra features:"
    Write-Host "$centerSpaces     ╚═ th loader           : Run loader animation." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th animate [option] : Run logo animation." -ForegroundColor White
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

function demo_wave_loader {
    param (
        [string]$Message = "Demo Wave Loader"
    )

    # Clear screen and notify user
    Clear-Host
    Write-Host "`nPress Ctrl+C to exit (Spam it, if it doesn't work first time!)`n" -ForegroundColor Yellow

    # Create a dummy background process
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-Command", "Start-Sleep -Seconds 99999" -PassThru -WindowStyle Hidden

    # Trap Ctrl+C and clean up
    $cleanup = {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch {}
        Write-Host "`e[?25h`n"
        exit 0
    }
    Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null

    try {
        wave_loader -Pid $proc.Id -Message $Message
    } finally {
        if (!$proc.HasExited) {
            $proc.Kill()
        }
    }
}

# ========================================================================================================================
#                                                            Extras
# ========================================================================================================================