function kube_elevated_login {
    param(
        [string]$cluster,
        [string]$env = ""
    )

    $request_role = load_request_role "kube" $cluster

    while ($true) {
        Clear-Host
        create_header "Privilege Request"
        Write-Host "You don't have write access to " -NoNewline
        Write-Host $cluster -ForegroundColor Green -NoNewline
        Write-Host "."
        Write-Host "`nWould you like to raise a request?" -ForegroundColor White
        create_note "Entering (N/n) will log you in as a read-only user."
        Write-Host "(Yy/Nn): " -NoNewline
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            Write-Host "`nEnter your reason for request: " -NoNewline -ForegroundColor White
            $reason = Read-Host

            Write-Host ""
            tsh request create --roles $request_role --max-duration 4h --reason $reason

            $global:reauth_kube = $true
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host ""
            Write-Host "Request creation skipped."
            return
        }
        else {
            Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
        }
    }
}