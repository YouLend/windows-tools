function aws_elevated_login {
    param(
        [string]$app,
        [string]$default_role
    )
    
    Clear-Host
    create_header "Privilege Request"
    Write-Host "No privileged roles found. Your only available role is: " -NoNewline
    Write-Host $default_role -ForegroundColor Green

    while ($true) {
        Write-Host ""
        Write-Host "Would you like to raise a privilege request?" -ForegroundColor White
        create_note "Entering (N/n) will log you in as $default_role. "
        Write-Host "(Yy/Nn): " -NoNewline
        $request = Read-Host
        
        if ($request -match '^[Yy]$') {
            Write-Host ""
            Write-Host "Enter request reason: " -NoNewline -ForegroundColor White
            $reason = Read-Host

            $request_role = "sudo_" + $default_role + "_role"
            Write-Host ""
            tsh request create --roles $request_role --reason $reason --max-duration 4h
            
            $global:reauth_aws = $true
            return
        }
        elseif ($request -match '^[Nn]$') {
            Clear-Host
            create_header "AWS Login"
            Write-Host "Logging you in to " -NoNewline -ForegroundColor White
            Write-Host $app -ForegroundColor Green -NoNewline
            Write-Host " as " -NoNewline -ForegroundColor White
            Write-Host $default_role -ForegroundColor Green
            
            & tsh apps login $app > $null 2>&1

            Write-Host "`nLogged in successfully!" -ForegroundColor Green
            
            create_proxy $app $default_role
            $global:reauth_aws = $false
            return
        }
        else {
            Write-Host ""
            Write-Host "Invalid input. Please enter y or n." -ForegroundColor Red
        }
    }
}