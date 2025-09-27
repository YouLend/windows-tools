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
    Write-Host "`nLogged out of all apps and proxies.`n" -ForegroundColor Green
}