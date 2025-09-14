function mongo_connect {
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
                mongocli_connect $cluster
            }
            "2" {
                open_atlas $cluster $port
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
        [string]$cluster,
        [string]$port
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

function check_atlas_access {
    $status = & tsh status 2>$null
    $has_atlas_access = if ($status -match "atlas-read-only") { "true" } else { "false" }
    
    $json_output = & tsh db ls --format=json 2>$null
    
    return @{
        has_atlas_access = $has_atlas_access
        json_output = $json_output
    }
}

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
    
    try {
        & mongosh --version > $null 2>&1
        $mongosh_found = $true
    } catch {
        $mongosh_found = $false
    }
    
    if (-not $mongosh_found) {
        check_mongosh_installed
    } else {
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
}

function check_mongosh_installed {
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
}