# ========================================================================================================================
#                                                    Functional Helpers
# ========================================================================================================================

function th_login {
    Clear-Host
    Write-Host ""
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
    Write-Host ""
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
    Write-Host ""
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
    Write-Host "$centerSpaces     ╚═ th login            : Simple log in to Teleport." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th quickstart | qs  : Open quickstart guide in browser." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th docs       | doc : Open documentation in browser." -ForegroundColor White

    # Divider line
    Write-Host "$centerSpaces     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Note
    Write-Host "$centerSpaces     For specific instructions, run th <option> -h`n"

    # Docs section
    create_header -HeaderText "Docs" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the documentation pages:"
    Write-Host "$centerSpaces     ╚═ Quickstart:     th qs" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ Docs:           th doc" -ForegroundColor White
    Write-Host ""

    # Extras section
    create_header -HeaderText "Extras" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the extra features:"
    Write-Host "$centerSpaces     ╚═ th animate [option] : Run animation." -ForegroundColor White
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

# ========================================================================================================================
#                                                            Extras
# ========================================================================================================================