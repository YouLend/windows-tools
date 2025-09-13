function rds_connect {
    param(
        [string]$cluster,
        [string]$port
    )
    
    $db_user = "tf_teleport_rds_read_user"

    Clear-Host
    create_header "Connect"
    Write-Host "How would you like to connect?`n"
    Write-Host "1. Via PSQL" -ForegroundColor White
    Write-Host "2. Via DBeaver" -ForegroundColor White
    Write-Host "`nSelect option (number): " -NoNewline
    $option = Read-Host

    if ([string]::IsNullOrEmpty($option)) {
        Write-Host "No selection made. Exiting."
        return
    }

    switch ($option) {
        "1" {
            Write-Host "`nConnecting via PSQL..." -ForegroundColor Green

            if (-not (check_psql)) {
                return
            }

            $database = list_postgres_databases $cluster
            
            if (-not $database) {
                return
            }

            check_admin

            connect_psql $cluster $database $db_user
        }
        "2" {
            Write-Host "`nConnecting via DBeaver..." -ForegroundColor Green
            
            check_admin

            open_dbeaver $cluster $db_user $port
        }
        default {
            Write-Host "Invalid selection. Exiting."
            return
        }
    }
}

function open_dbeaver {
    param(
        [string]$cluster,
        [string]$db_user,
        [string]$port
    )
    
    Write-Host "Connecting to " -NoNewline -ForegroundColor White
    Write-Host $cluster -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline -ForegroundColor White
    Write-Host $db_user -ForegroundColor Green -NoNewline
    Write-Host "...`n"
    Start-Sleep 1
    
    # Start proxy in background
    Start-Job -ScriptBlock {
        param($cluster, $port, $db_user)
        & tsh proxy db $cluster --db-name="postgres" --port=$port --tunnel --db-user=$db_user 2>&1 | Out-Null
    } -ArgumentList $cluster, $port, $db_user | Out-Null
    
    Clear-Host
    create_header "DBeaver"
    Write-Host "To connect, follow these steps: " -ForegroundColor White
    Write-Host "`n1. Once DBeaver opens, click create a new connection in the very top left."
    Write-Host "2. Select " -NoNewLine
    Write-Host "PostgreSQL " -NoNewLine -ForegroundColor White
    Write-Host "as the database type." 
    Write-Host "3. Use the following connection details:"
    Write-Host " - Host:      localhost" -ForegroundColor White
    Write-Host " - Port:      $port" -ForegroundColor White
    Write-Host " - Database:  postgres" -ForegroundColor White
    Write-Host " - User:      $db_user" -ForegroundColor White
    Write-Host " - Password:  (leave blank)" -ForegroundColor White
    Write-Host " - Select 'Show all databases' ☑️" -ForegroundColor White
    Write-Host "5. Click " -NoNewLine
    Write-Host "Test Connection " -NoNewLine -ForegroundColor White
    Write-Host "to ensure everything is set up correctly."
    Write-Host "6. If the test is successful, click " -NoNewLine
    Write-Host "Finish " -NoNewLine -ForegroundColor White
    Write-Host "to save the connection.`n"
    Start-Sleep 1
    
    try {
        Start-Process "dbeaver"
    } catch {
        Write-Host "`nL Could not open DBeaver. Please ensure it is installed and accessible from PATH." -ForegroundColor Red
    }
}

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