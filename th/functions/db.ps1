# ============================================================
# ======================== Databases =========================
# ============================================================
function db_login {
    th_login
    Clear-Host
    create_header "DB"

    Write-Host "Which database would you like to connect to: "
    Write-Host "`n1. " -NoNewLine
    Write-Host "RDS" -ForegroundColor White
    Write-Host "2. " -NoNewLine
    Write-Host "MongoDB" -ForegroundColor White
    $script:exit_db
    $selected_db = ""

    while ($true) {
        Write-Host "`nEnter choice: " -NoNewLine
        $choice = Read-Host 
        if ($choice -eq "1") {
            # RDS
            Write-Host "`nSelected: " -NoNewLine
            Write-Host "RDS" -ForegroundColor White

            $db_type = "rds"

            Clear-Host
            create_header "Available Databases"

            # Run both RDS login check and database listing in parallel
            $results = load -Jobs @{
                login_check = { check_rds_login }
                databases = { 
                    $json_output = tsh db ls --format=json | ConvertFrom-Json
                    return $json_output | Where-Object { $_.metadata.labels.db_type -eq "rds" }
                }
            } -Message "Checking RDS access..."

            $login_results = $results.login_check
            $filtered_dbs = $results.databases
            
            # Print results
            for ($i = 0; $i -lt $login_results.databases.Count; $i++) {
                $status = $login_results.statuses[$i]
                switch ($status) {
                    "ok"    { Write-Host ("{0,2}. {1}" -f ($i + 1), $login_results.databases[$i]) }
                    "fail"  { Write-Host ("{0,2}. {1}" -f ($i + 1), $login_results.databases[$i]) -ForegroundColor DarkGray }
                    default { Write-Host ("{0,2}. {1}" -f ($i + 1), $login_results.databases[$i]) }
                }
            }

            # Prompt for selection
            Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
            $db_number = Read-Host

            while (-not $selected_db) {
                $index = [int]$db_number - 1
                if ($index -ge 0 -and $index -lt $filtered_dbs.Count) {
                    $selected_db = $filtered_dbs[$index]
                    
                    # Check if the selected database has failed login status
                    $selected_status = if ($index -lt $login_results.statuses.Count) { $login_results.statuses[$index] } else { "n/a" }
                    if ($selected_status -eq "fail") {
                        db_elevated_login "sudo_teleport_rds_read_role" $selected_db.metadata.name
                    }
                } else {
                    Write-Host "`nInvalid selection" -ForegroundColor Red
                    Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
                    $db_number = Read-Host
                }
            }
            break
        }
        # MongoDB
        elseif ($choice -eq "2") {
            Write-Host "`nSelected: " -NoNewLine
            Write-Host "MongoDB" -ForegroundColor White
            $db_type = "mongo"

            Clear-Host
            create_header "Available Databases"

            # Run both database listing and access check in parallel
            $results = load -Jobs @{
                databases = { 
                    $json_output = tsh db ls --format=json | ConvertFrom-Json
                    return $json_output | Where-Object { $_.metadata.labels.db_type -ne "rds" }
                }
                access = { 
                    $tshStatus = tsh status
                    return $tshStatus -match '\batlas-can-read\b'
                }
            } -Message "Checking MongoDB access..."

            $filtered_dbs = $results.databases
            $hasAtlasAccess = $results.access

            # If no MongoDB databases are listed, prompt for elevated login
            if (-not $filtered_dbs) {
                db_elevated_login "atlas-read-only" "MongoDBs"
                break
            }

            $i = 1
            foreach ($db in $filtered_dbs) {
                Write-Host ("{0}. " -f $i) -NoNewLine
                if ($hasAtlasAccess) {
                    Write-Host $db.metadata.name -ForegroundColor White
                } else {
                    Write-Host $db.metadata.name -ForegroundColor DarkGray
                }
                $i++
            }

            # Prompt for selection
            Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
            $db_number = Read-Host

            while (-not $selected_db) {
                $index = [int]$db_number - 1
                if ($index -ge 0 -and $index -lt $filtered_dbs.Count) {
                    $selected_db = $filtered_dbs[$index]
                    
                    # If user doesn't have atlas access, trigger elevated login
                    if (-not $hasAtlasAccess) {
                        db_elevated_login "atlas-read-only" $selected_db.metadata.name
                    }
                } else {
                    Write-Host "`nInvalid selection" -ForegroundColor Red
                    Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
                    $db_number = Read-Host
                }
            }
            break
        }
        else {
            Write-Host "`nInvalid selection. Please choose 1 or 2." -ForegroundColor Red
        }
    }
    # Re-Authenticate following an access request
    if ($script:reauth_db -eq "TRUE") {
        Write-Host "`nRe-Authenticating`n" -ForegroundColor White
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$script:REQUEST_ID" *> $null
        $script:reauth_db = "FALSE"
    }

    # Exit script if user chose not to raise an access request 
    if ($script:exit_db -eq "TRUE") {
        $script:exit_db = "FALSE"
        return
    }

    if ($selected_db.metadata.labels.db_type -eq "rds") {
        rds_connect $selected_db.metadata.name
        return
    }
    mongo_connect $selected_db.metadata.name
}

function check_rds_login {
    $output = tsh db ls --format=json
    $dbs = ($output | ConvertFrom-Json) | Where-Object { $_.metadata.labels.db_type -eq "rds" } | Select-Object -ExpandProperty metadata | Select-Object -ExpandProperty name

    $accessStatus = "unknown"
    $testDb = $null
    $databases = @()
    $statuses = @()

    # Collect DB names, pick test DB
    foreach ($db in $dbs) {
        if (-not [string]::IsNullOrWhiteSpace($db)) {
            $databases += $db
            if (-not $testDb -and ($db -match "prod" -or $db -match "sandbox")) {
                $testDb = $db
            }
        }
    }

    # Run proxy and check access
    if ($testDb) {
        $proxyOutFile = [System.IO.Path]::GetTempFileName()
        $proxyErrFile = [System.IO.Path]::GetTempFileName()
        $proxy = Start-Process tsh -ArgumentList "proxy", "db", $testDb, "--db-name", "postgres", "--db-user", "tf_teleport_rds_read_user", "--tunnel" `
            -NoNewWindow -PassThru -RedirectStandardOutput $proxyOutFile -RedirectStandardError $proxyErrFile

        $psqlUrl = $null
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Milliseconds 500
            if (Select-String -Path $proxyOutFile -Pattern 'psql postgres://.*@localhost:\d+/postgres' -Quiet) {
                $matchLine = Get-Content $proxyOutFile | Select-String 'psql postgres://.*@localhost:\d+/postgres' | Select-Object -First 1
                if ($matchLine -match 'psql (postgres://[^ ]+)') {
                    $psqlUrl = $matches[1]
                } else {
                    $psqlUrl = $null
                }
                break
            }
        }

        if ($psqlUrl) {
            $env:PGPASSWORD = $env:PGPASSWORD  # Ensure available
            $testResult = & psql $psqlUrl -c "SELECT 1;" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $accessStatus = "ok"
            } else {
                $accessStatus = "fail"
            }
        } else {
            $accessStatus = "fail"
        }

        Stop-Process -Id $proxy.Id -Force
        Start-Sleep -Milliseconds 500  # Wait for process to fully stop
        try {
            Remove-Item $proxyOutFile -Force -ErrorAction SilentlyContinue
        } catch {}
        try {
            Remove-Item $proxyErrFile -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    # Build status array
    foreach ($db in $databases) {
        if ($db -match "prod" -or $db -match "sandbox") {
            $statuses += $accessStatus
        } else {
            $statuses += "n/a"
        }
    }

    # Return results as hashtable
    return @{
        databases = $databases
        statuses = $statuses
    }
}

function db_elevated_login($role, $db) {
    while ($true) {
        Clear-Host
        create_header "Privilege Request"
        Write-Host "You don't have access to " -NoNewLine
        Write-Host "$db..." -ForegroundColor White
        Write-Host "`nWould you like to raise a request? (y/n): " -ForegroundColor White -NoNewLine
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            Write-Host "`nEnter your reason for request: " -ForegroundColor White -NoNewLine
            $reason = Read-Host
            Write-Host 
            # Create a buffer to store output line-by-line while also printing to the console
            $rawOutputLines = @()
            tsh request create --roles $role --reason "$reason" --max-duration 6h |
                Tee-Object -Variable rawOutputLines |
                ForEach-Object { Write-Host $_ }

            # Join the lines back into a single string (for parsing)
            $rawOutput = $rawOutputLines -join "`n"

            # Extract the Request ID
            $script:REQUEST_ID = ($rawOutput -split "`n" | Where-Object { $_ -match '^Request ID' }) -replace 'Request ID:\s*', '' | ForEach-Object { $_.Trim() }
            $script:reauth_db = "TRUE"

            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host "`nRequest creation skipped.`n"
            $script:exit_db = "TRUE"
            return
        }
        else {
            Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
        }
    }
}

function fetch_postgres_dbs($rds) {
    $dbUser = "tf_teleport_rds_read_user"
    $port = Get-FreePort

    # Start proxy and keep track of process
    $proxyProc = Start-Process tsh -ArgumentList @(
        "proxy", "db", $rds,
        "--tunnel",
        "--port=$port",
        "--db-user=$dbUser",
        "--db-name=postgres"
    ) -PassThru -WindowStyle Hidden

    # Wait for proxy port to open (max 10s)
    $portOpen = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 1
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient("localhost", $port)
            if ($tcp.Connected) {
                $tcp.Close()
                $portOpen = $true
                break
            }
        } catch {}
    }

    if (-not $portOpen) {
        try { $proxyProc.Kill() } catch {}
        return @{ success = $false; error = "Failed to establish tunnel to database." }
    }

    $query = "SELECT datname FROM pg_database WHERE datistemplate = false;"
    $dbList = & psql "postgres://$dbUser@localhost:$port/postgres" -t -A -c $query 2>$null

    # Cleanup
    try { $proxyProc.Kill() } catch {}

    if ([string]::IsNullOrWhiteSpace($dbList)) {
        return @{ success = $false; error = "No databases found or connection failed." }
    }

    $databases = $dbList -split "`n" | Where-Object { $_.Trim() -ne "" }
    return @{ success = $true; databases = $databases }
}

function rds_connect($rds) {
    $db_user = "tf_teleport_rds_read_user"

    Write-Host "`n$rds " -NoNewLine -ForegroundColor Green
    Write-Host "selected." 
    Start-Sleep -Seconds 1

    Clear-Host
    create_header "Connect"
    Write-Host "How would you like to connect?`n"
    Write-Host "1. Via " -NoNewLine
    Write-Host "PSQL" -ForegroundColor White
    Write-Host "2. Via " -NoNewLine
    Write-Host "DBeaver" -ForegroundColor White
    $option = Read-Host "`nSelect option (number)"

    if ([string]::IsNullOrWhiteSpace($option)) {
        Write-Host "No selection made. Exiting." -ForegroundColor Red
        return
    }

    

    function check_admin {   
        $tshStatus = tsh status
        if ($tshStatus -match '\bsudo_teleport_rds_write_role\b') {
            Write-Host "`nConnecting as admin? (y/n): " -NoNewline
            $admin = Read-Host

            if ($admin -match '^[Yy]$') {
                $db_user = "tf_sudo_teleport_rds_user"
            }
        }
        return $db_user
    }

    function connect_db($rds, $db_user, $database) {

        Write-Host "`nConnecting to " -NoNewline
        Write-Host "$database" -ForegroundColor Green -NoNewline
        Write-Host " in " -NoNewline
        Write-Host "$rds" -ForegroundColor Green -NoNewline
        Write-Host " as " -NoNewline
        Write-Host "$db_user`n" -ForegroundColor Green

        3..1 | ForEach-Object {
            Write-Host ". " -ForegroundColor Green -NoNewline
            Start-Sleep -Seconds 1
        }

        Write-Host "`n"
        Clear-Host

        tsh db connect $rds --db-user=$db_user --db-name=$database
    }

    function list_postgres_dbs($rds) {
        Clear-Host
        create_header "Available Databases"

        # Use load function for the database fetching
        $result = load -Job { fetch_postgres_dbs $using:rds } -Message "Fetching databases..."

        if (-not $result.success) {
            Write-Host "`n $($result.error)" -ForegroundColor Red
            return
        }

        # Ensure databases is treated as a proper array
        $databases = @($result.databases)
        $dbCount = $databases.Count

        # Display results
        for ($i = 0; $i -lt $dbCount; $i++) {
            $index = $i + 1
            Write-Host "$index. $($databases[$i])" 
        }

        Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewline
        $choice = Read-Host

        if (-not $choice -or -not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $dbCount) {
            Write-Host "`nInvalid selection. Exiting." -ForegroundColor Red
            return
        }

        $database = $databases[$choice - 1]
        return $database
    }

    switch ($option) {
        1 {
            $database = list_postgres_dbs $rds

            $db_user = check_admin

            connect_db $rds $db_user $database
            return 
        }
        2 {
            $database = list_postgres_dbs $rds

            $db_user = check_admin
            
            if ([string]::IsNullOrWhiteSpace($database)) {
                $database = "postgres"
                open_dbeaver "postgres" $rds $db_user
                return
            }
            open_dbeaver $rds $db_user $database 
            return
        }
        default {
            Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        }
    }
}

function mongo_connect($selected_db) {

    $db_user = switch ($selected_db) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1"   { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default {
            Write-Host "`n`e[31mUnknown database: $selected_db`e[0m"
            return
        }
    }
    
    Clear-Host
    create_header "MongoDB"
    Write-Host "How would you like to connect?"
    Write-Host "`n1. Via " -NoNewLine
    Write-Host "MongoCLI" -ForegroundColor White
    Write-Host "2. Via " -NoNewLine
    Write-Host "AtlasGUI`n" -ForegroundColor White -NoNewLine

    while ($true) {
        $option = Read-Host "`nSelect option (number)"
        switch ($option) {
            "1" {
                Clear-Host
                
                # Check if mongosh is available
                try {
                    $output = mongosh --version 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Command failed"
                    }
                } catch {
                    Write-Host "`nMongoDB Shell (mongosh) not found in PATH." -ForegroundColor Red
                    Write-Host "`nYou can install it from:"
                    Write-Host "`nhttps://www.mongodb.com/try/download/shell`n"
                    return
                }
                
                tsh db connect $selected_db --db-user=$db_user --db-name=admin
                return
            }
            "2" {
                Clear-Host
                create_header "AtlasGUI"
                Write-Host "Logging into:" -NoNewLine
                Write-Host " $selected_db" -ForegroundColor Green 
                tsh db login $selected_db --db-user=$db_user --db-name=admin | Out-Null

                Write-Host "`nCreating proxy..."

                function Get-FreePort {
                    $listener = [System.Net.Sockets.TcpListener]::New([System.Net.IPAddress]::Loopback, 0)
                    $listener.Start()
                    $port = $listener.LocalEndpoint.Port
                    $listener.Stop()
                    return $port
                }

                $port = Get-FreePort

                Start-Process powershell -ArgumentList @(
                    "-NoExit",
                    "-ExecutionPolicy", "Bypass",
                    "-WindowStyle", "Minimized",
                    "-Command", "tsh proxy db --tunnel --port=$port $selected_db"
                )
                Write-Host "`nOpening MongoDB Compass...`n"
                Start-Job { Start-Process "mongodb://localhost:$using:port/?directConnection=true" } *>$null
                return
            }
            default {
                Write-Host "`nInvalid selection. Please enter 1 or 2."
            }
        }
    }
}

function open_dbeaver($rds, $db_user, $database) {
    Write-Host "`nConnecting to " -NoNewLine
    Write-Host "$database " -NoNewLine -ForegroundColor Green
    Write-Host "in " -NoNewLine
    Write-Host "$rds " -NoNewLine -ForegroundColor Green
    Write-Host "as " -NoNewLine 
    Write-Host "$db_user" -ForegroundColor Green
    Start-Sleep -Seconds 2
    Clear-Host
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Minimized",
        "-Command", "tsh proxy db `"$rds`" --db-name=`"$database`" --port=50000 --tunnel --db-user=$db_user"
    )
    create_header "DBeaver"
    Write-Host "To connect to the database, follow these steps:`n"
    Write-Host "1. Once DBeaver opens click create a new connection in the very top left."
    Write-Host "2. Select " -NoNewLine
    Write-Host "PostgreSQL " -NoNewLine -ForegroundColor White
    Write-Host "as the database type."
    Write-Host "3. Use the following connection details:"
    Write-Host " - Host:      " -NoNewLine
    Write-Host "localhost" -ForegroundColor White
    Write-Host " - Port:      " -NoNewLine
    Write-Host "50000" -ForegroundColor White
    Write-Host " - Database:  " -NoNewLine
    Write-Host "$database" -ForegroundColor White
    Write-Host " - User:      " -NoNewLine
    Write-Host "$db_user" -ForegroundColor White
    Write-Host " - Password:  " -NoNewLine
    Write-Host "(leave blank)`n" -ForegroundColor White
    Write-Host "4. Optionally, select show all databases."
    Write-Host "5. Click 'Test Connection' to ensure everything is set up correctly."
    Write-Host "6. If the test is successful, click 'Finish' to save the connection."
    for ($i = 3; $i -ge 1; $i--) {
        Write-Host ". " -ForegroundColor Green -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host "`n`nOpening DBeaver`n"
    $proc = Get-Process -Name "dbeaver" -ErrorAction SilentlyContinue
    if ($proc) {
        Add-Type '[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name Win -Namespace Win32
        [Win32.Win]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
    } else {
        Start-Process "C:\Program Files\DBeaver\dbeaver.exe"
    }
}