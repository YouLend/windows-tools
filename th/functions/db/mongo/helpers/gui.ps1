function open_atlas {
    param(
        [string]$cluster,
        [int]$port
    )
    
    $db_user = switch ($cluster) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1" { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default { "teleport" }
    }
    
    Clear-Host
    create_header "Mongo Atlas"
    Write-Host "Logging into: " -NoNewline
    Write-Host $cluster -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline
    Write-Host $db_user -ForegroundColor Green
    
    & tsh db login $cluster --db-user=$db_user --db-name="admin" > $null 2>&1
    Write-Host "`nLogged in successfully!" -ForegroundColor Green
    
    create_db_proxy $cluster $port

    # Open MongoDB Compass
    Write-Host "`nOpening MongoDB compass..."
    try {
        Start-Process "mongodb://localhost:$port/?directConnection=true"
        Write-Host "`nMongoDB Compass launched!`n" -ForegroundColor Green
    } catch {
        Write-Host "`nCould not open MongoDB Compass." -ForegroundColor Yellow
        Write-Host "Manual connection string: " -NoNewline -ForegroundColor White
        Write-Host "mongodb://localhost:$port/?directConnection=true" -ForegroundColor Cyan
    }
}