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

            $database = list_postgres_databases $cluster $port
            
            if (-not $database) {
                return
            }

            connect_psql $cluster $database $db_user
        }
        "2" {
            Write-Host "`nConnecting via DBeaver..." -ForegroundColor Green

            open_dbeaver $cluster $db_user $port
        }
        default {
            Write-Host "Invalid selection. Exiting."
            return
        }
    }
}



