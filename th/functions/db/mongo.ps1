function mongo_connect {
    param(
        [string]$db,
        [string]$port
    )
    
    $db_user = switch ($db) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1" { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default { "teleport" }
    }
    
    Clear-Host
    create_header "MongoDB"
    Write-Host "How would you like to connect?`n"
    Write-Host "1. Via MongoCLI" -ForegroundColor White
    Write-Host "2. Via AtlasGUI" -ForegroundColor White
    Write-Host "`nSelect option (number): " -NoNewline
    $option = Read-Host
    
    while ($true) {
        switch ($option) {
            "1" {
                try {
                    & mongosh --version > $null 2>&1
                    $mongosh_found = $true
                } catch {
                    $mongosh_found = $false
                }

                if (-not $mongosh_found) {
                    Write-Host "`nL MongoDB client not found. MongoSH is required to connect to MongoDB databases."
                    
                    while ($true) {
                        Write-Host "`nWould you like to install it via chocolatey? (y/n): " -NoNewline
                        $install = Read-Host
                        
                        if ($install -match '^[Yy]$') {
                            Write-Host ""
                            try {
                                choco install mongodb-shell -y
                                Write-Host "`n MongoDB client installed successfully!" -ForegroundColor Green
                                Write-Host "`nConnecting to " -NoNewline -ForegroundColor White
                                Write-Host $db -ForegroundColor Green -NoNewline
                                Write-Host "..."
                                Write-Host ""
                                & tsh db connect $db
                                return
                            } catch {
                                Write-Host "`nL Failed to install MongoDB client. Please install manually." -ForegroundColor Red
                                return
                            }
                        } elseif ($install -match '^[Nn]$') {
                            Write-Host "`nMongoDB client installation skipped."
                            return
                        } else {
                            Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
                        }
                    }
                } else {
                    # If the MongoDB client is found, connect to the selected database
                    Write-Host "`nConnecting to " -NoNewline -ForegroundColor White
                    Write-Host $db -ForegroundColor Green -NoNewline
                    Write-Host "..."
                    
                    for ($i = 3; $i -ge 1; $i--) {
                        Write-Host ". " -NoNewline -ForegroundColor Green
                        Start-Sleep 1
                    }
                    Clear-Host
                    & tsh db connect $db --db-user=$db_user --db-name="admin"
                    return
                }
            }
            "2" {
                open_atlas $db $port
                return
            }
            default {
                Write-Host "`nInvalid selection. Please enter 1 or 2." -ForegroundColor Red
                Write-Host "`nSelect option (number): " -NoNewline
                $option = Read-Host
                continue
            }
        }
    }
}

function open_atlas {
    param(
        [string]$db,
        [string]$port
    )
    
    $db_user = switch ($db) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1" { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default { "teleport" }
    }
    
    Clear-Host
    create_header "Mongo Atlas"
    Write-Host "Logging into: " -NoNewline
    Write-Host $db -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline
    Write-Host $db_user -ForegroundColor Green
    
    & tsh db login $db --db-user=$db_user --db-name="admin" > $null 2>&1
    Write-Host "`nLogged in successfully!" -ForegroundColor Green

    # Create a proxy for the selected db.
    Write-Host "`nCreating proxy for " -NoNewline
    Write-Host $db -ForegroundColor Green -NoNewline
    Write-Host "..."
    
    # Create script to run proxy with Tee-Object (allows proxy to keep running)
    $tempDir = $env:TEMP
    $logFile = Join-Path $tempDir "tsh_proxy_mongo_$db.log"
    $scriptPath = Join-Path $tempDir "launch_mongo_proxy_$db.ps1"
    $command = "tsh proxy db --tunnel --port=$port `"$db`" 2>&1 | Tee-Object -FilePath `"$logFile`""
    Set-Content -Path $scriptPath -Value $command

    # Start proxy in separate minimized PowerShell window
    $proc = Start-Process powershell.exe -ArgumentList "-WindowStyle Minimized", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -PassThru
    $pidFile = Join-Path $tempDir "tsh_proxy_mongo_$db.pid"
    $proc.Id | Out-File -FilePath $pidFile

    # Wait for proxy to start listening on the port
    Write-Host "`nWaiting for MongoDB proxy to start..."
    $maxWaitTime = 20
    $waitCount = 0
    $proxyReady = $false
    
    while ($waitCount -lt $maxWaitTime -and -not $proxyReady) {
        Start-Sleep -Milliseconds 500
        $waitCount++
        
        # Check if port is listening
        $tcpConnection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($tcpConnection) {
            $proxyReady = $true
            Write-Host "`nMongoDB proxy ready on port $port" -ForegroundColor Green
        }
    }
    
    if (-not $proxyReady) {
        Write-Host "`nTimed out waiting for MongoDB proxy to start on port $port" -ForegroundColor Red
        Write-Host "Check the proxy window for errors or try connecting manually to mongodb://localhost:$port/?directConnection=true" -ForegroundColor Yellow
        return
    }

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

function check_atlas_access {
    $status = & tsh status 2>$null
    $has_atlas_access = if ($status -match "atlas-read-only") { "true" } else { "false" }
    
    $json_output = & tsh db ls --format=json 2>$null
    
    return @{
        has_atlas_access = $has_atlas_access
        json_output = $json_output
    }
}