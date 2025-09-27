function connect_psql {
    param(
        [string]$cluster,
        [string]$database,
        [string]$db_user
    )
    
    for ($i = 3; $i -ge 1; $i--) {
        Write-Host ". " -NoNewline -ForegroundColor Green
        Start-Sleep 1
    }
    Write-Host ""
    Clear-Host
    & tsh db connect $cluster --db-user=$db_user --db-name=$database
}