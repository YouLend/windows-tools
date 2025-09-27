function th_login {
    Clear-Host
    create_header "Login"
    Write-Host "Checking login status..."
    try {
        tsh apps logout *> $null
    } catch {
        Write-Host "TSH connection failed. Cleaning up existing sessions and reauthenticating...`n"
        th_kill
    }

    $status = tsh status 2>$null
    if ($status -match 'Logged in as:') {
        Write-Host "`nAlready logged in to Teleport!" -ForegroundColor White
        Start-Sleep -Milliseconds 500
        return
    }

    Write-Host "`nLogging you into Teleport..."
    
    # Start login in background
    Start-Process tsh -ArgumentList 'login', '--auth=ad', '--proxy=youlend.teleport.sh:443' -WindowStyle Hidden

    # Wait up to 15 seconds (30 x 0.5s) for login to complete
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        if (tsh status 2>$null | Select-String -Quiet 'Logged in as:') {
            Write-Host "`nLogged in successfully`n" -ForegroundColor Green
            return
        }
    }

    Write-Host "`nTimed out waiting for Teleport login."
    return
}