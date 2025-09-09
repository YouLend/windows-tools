function rds_connect {
    param(
        [string]$rds,
        [string]$port
    )
    
    $db_user = "tf_teleport_rds_read_user"

    function list_postgres_databases {
        param(
            [string]$rds,
            [string]$port
        )

        # Start proxy in background
        $job = Start-Job -ScriptBlock {
            param($rds, $port)
            & tsh proxy db $rds --db-user=tf_teleport_rds_read_user --db-name=postgres --port=$port --tunnel 2>&1 | Out-Null
        } -ArgumentList $rds, $port

        # Wait for proxy to open (up to 10 seconds)
        $connected = $false
        for ($i = 1; $i -le 10; $i++) {
            try {
                $tcpConnection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
                if ($tcpConnection) {
                    $connected = $true
                    break
                }
            } catch {}
            Start-Sleep 1
        }

        if (-not $connected) {
            Write-Host "`nL Failed to establish tunnel to database." -ForegroundColor Red
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $null
        }

        Clear-Host
        create_header "Available Databases"

        $result = load -Job {
            param($port)
            $connectionString = "postgres://tf_teleport_rds_read_user@localhost:$port/postgres"
            $output = psql $connectionString -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false;"
            return $output
        } -ArgumentList $port -Message "Fetching databases..."

        if (-not $result -or $result.Count -eq 0) {
            Write-Host "No databases found or connection failed." -ForegroundColor Red
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $null
        }

        for ($i = 0; $i -lt $result.Count; $i++) {
            Write-Host ("{0,2}. {1}" -f ($i + 1), $result[$i])
        }

        Write-Host "`nSelect database (number): " -NoNewline -ForegroundColor White
        $db_choice = Read-Host

        if ([string]::IsNullOrEmpty($db_choice)) {
            Write-Host "No selection made. Exiting."
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $null
        }

        $selected_index = [int]$db_choice - 1
        if ($selected_index -lt 0 -or $selected_index -ge $result.Count) {
            Write-Host "`nInvalid selection" -ForegroundColor Red
            Stop-Job $job -ErrorAction SilentlyContinue
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            return $null
        }

        $database = $result[$selected_index]
        
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        
        return $database
    }

    function check_admin {
        $status = & tsh status 2>$null
        if ($status -match "sudo_teleport_rds_write_role") {
            Write-Host "`nConnecting as admin? (y/n): " -NoNewline
            $admin = Read-Host

            if ($admin -match '^[Yy]$') {
                $script:db_user = "tf_sudo_teleport_rds_user"
            }
        }
    }

    function check_psql {
        try {
            & psql --version > $null 2>&1
            return $true
        } catch {
            Write-Host "`n=============== PSQL not found =============== " -ForegroundColor White
            Write-Host "`nL PSQL client not found. It is required to connect to PostgreSQL databases."
            
            while ($true) {
                Write-Host "`nWould you like to install it via chocolatey? (y/n): " -NoNewline
                $install = Read-Host
                
                if ($install -match '^[Yy]$') {
                    Write-Host ""
                    try {
                        choco install postgresql -y
                        Write-Host "`n PSQL client installed successfully!" -ForegroundColor Green
                        return $true
                    } catch {
                        Write-Host "`nL Failed to install PSQL. Please install manually." -ForegroundColor Red
                        return $false
                    }
                } elseif ($install -match '^[Nn]$') {
                    Write-Host "`nPSQL installation skipped."
                    return $false
                } else {
                    Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
                }
            }
        }
    }

    function connect_db {
        param([string]$database)
        
        for ($i = 3; $i -ge 1; $i--) {
            Write-Host ". " -NoNewline -ForegroundColor Green
            Start-Sleep 1
        }
        Write-Host ""
        Clear-Host
        & tsh db connect $rds --db-user=$db_user --db-name=$database
    }

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

            $database = list_postgres_databases $rds
            
            if (-not $database) {
                return
            }

            check_admin

            connect_db $database
        }
        "2" {
            Write-Host "`nConnecting via DBeaver..." -ForegroundColor Green
            
            check_admin

            open_dbeaver $rds $db_user $port
        }
        default {
            Write-Host "Invalid selection. Exiting."
            return
        }
    }
}

function check_rds_login {
    $output = & tsh db ls -f json 2>$null
    if (-not $output) {
        return @{
            db_lines = @()
            login_status = @()
        }
    }

    try {
        $dbs_json = $output | ConvertFrom-Json
        $dbs = $dbs_json | Where-Object { $_.metadata.labels.db_type -eq "rds" } | ForEach-Object { $_.metadata.name }
    } catch {
        return @{
            db_lines = @()
            login_status = @()
        }
    }

    $db_lines = @()
    $login_status = @()
    $access_status = "unknown"
    $test_db = ""
    
    # First pass: collect all db names and find a test database
    foreach ($db_name in $dbs) {
        if ([string]::IsNullOrEmpty($db_name)) {
            continue
        }

        $db_lines += $db_name
        
        # Find first prod/sandbox db to test with
        if ([string]::IsNullOrEmpty($test_db) -and ($db_name -match "prod|sandbox")) {
            $test_db = $db_name
        }
    }
    
    # Check if user has the requestable role for database access
    $status = & tsh status 2>$null
    if ($status -match "sudo_teleport_rds_read_role") {
        $access_status = "ok"
    } else {
        $access_status = "fail"
    }
    
    # Second pass: set status for all databases based on single test
    foreach ($db_name in $db_lines) {
        if ($db_name -match "prod|sandbox") {
            $login_status += $access_status
        } else {
            $login_status += "n/a"
        }
    }

    return @{
        db_lines = $db_lines
        login_status = $login_status
    }
}

function open_dbeaver {
    param(
        [string]$rds,
        [string]$db_user,
        [string]$port
    )
    
    Write-Host "Connecting to " -NoNewline -ForegroundColor White
    Write-Host $rds -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline -ForegroundColor White
    Write-Host $db_user -ForegroundColor Green -NoNewline
    Write-Host "...`n"
    Start-Sleep 1
    
    # Start proxy in background
    Start-Job -ScriptBlock {
        param($rds, $port, $db_user)
        & tsh proxy db $rds --db-name="postgres" --port=$port --tunnel --db-user=$db_user 2>&1 | Out-Null
    } -ArgumentList $rds, $port, $db_user | Out-Null
    
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