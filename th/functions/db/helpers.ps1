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

function list_postgres_databases {
    param(
        [string]$cluster,
        [string]$port
    )

    # Start proxy in background
    $job = Start-Job -ScriptBlock {
        param($cluster, $port)
        & tsh proxy db $cluster --db-user=tf_teleport_rds_read_user --db-name=postgres --port=$port --tunnel 2>&1 | Out-Null
    } -ArgumentList $cluster, $port

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

function create_db_proxy {
    param (
        [string]$cluster,
        [string]$database="",
        [string]$db_user="",
        [int]$port
    )
    # Create simple script to run proxy
    $tempDir = $env:TEMP
    $scriptPath = Join-Path $tempDir "launch_proxy_$cluster.ps1"

    # Add database parameter if provided
    if ([string]::IsNullOrEmpty($database) -and [string]::IsNullOrEmpty($db_user) ) {
        $command = "tsh proxy db --tunnel --port=$port `"$cluster`""
    } else {
        $command = "tsh proxy db --tunnel --port=$port --db-user $db_user --db-name=`"$database`" `"$cluster`""
    }

    Set-Content -Path $scriptPath -Value $command

    $proc = Start-Process powershell.exe -ArgumentList "-WindowStyle Minimized", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -PassThru
    $pidFile = Join-Path $tempDir "tsh_proxy_$cluster.pid"
    $proc.Id | Out-File -FilePath $pidFile

    $maxWaitTime = 60  # Increased timeout to 30 seconds
    $waitCount = 0
    $proxyReady = $false

    while ($waitCount -lt $maxWaitTime -and -not $proxyReady) {
        Start-Sleep -Milliseconds 500
        $waitCount++

        # Show progress dots every 2 seconds
        if ($waitCount % 4 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }

        # Check if port is listening
        $tcpConnection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($tcpConnection) {
            $proxyReady = $true
            Write-Host "`n✅ Proxy ready on port $port" -ForegroundColor Green
        }
    }

    if (-not $proxyReady) {
        Write-Host "`n❌ Timed out waiting for proxy to start on port $port" -ForegroundColor Red
        Write-Host "Check the minimized PowerShell window for error details" -ForegroundColor Yellow
        return
    }
}