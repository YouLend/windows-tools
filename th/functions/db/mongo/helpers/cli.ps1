function mongocli_connect {
    param(
        [string]$cluster
    )
    
    $db_user = switch ($cluster) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1" { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default { "teleport" }
    }
    
    # If the MongoDB client is found, connect to the selected database
    Write-Host "`nConnecting to " -NoNewline -ForegroundColor White
    Write-Host $cluster -ForegroundColor Green -NoNewline
    Write-Host "..."
    
    for ($i = 3; $i -ge 1; $i--) {
        Write-Host ". " -NoNewline -ForegroundColor Green
        Start-Sleep 1
    }
    Clear-Host
    & tsh db connect $cluster --db-user=$db_user --db-name="admin"
    return
}