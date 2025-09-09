function db_elevated_login {
    param(
        [string]$role,
        [string]$db_name = "Mongo databases"
    )

    while ($true) {
        Clear-Host
        create_header "Privilege Request"
        Write-Host "You don't have access to " -NoNewline
        Write-Host $db_name -ForegroundColor White
        Write-Host "`nWould you like to raise a request? (y/n): " -NoNewline
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            Write-Host "`nEnter your reason for request: " -NoNewline -ForegroundColor White
            $reason = Read-Host
            Write-Host ""
            
            tsh request create --roles $role --max-duration 4h --reason $reason

            $global:reauth_db = $true
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host ""
            Write-Host "Request creation skipped."
            $global:exit_db = $true
            return
        }
        else {
            Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
        }
    }
}