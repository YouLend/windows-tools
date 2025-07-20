# ============================================================
# ======================== Databases =========================
# ============================================================

function db_login {
    th_login
    Write-Host "`nWhich database would you like to connect to: "
    Write-Host "`n1. " -NoNewLine
    Write-Host "RDS" -ForegroundColor White
    Write-Host "2. " -NoNewLine
    Write-Host "MongoDB" -ForegroundColor White
    $script:exit_db
    while ($true) {
        Write-Host "`nEnter choice: " -NoNewLine
        $choice = Read-Host 
        if ($choice -eq "1") {
            # User selected RDS
            Write-Host "`nSelected: " -NoNewLine
            Write-Host "RDS" -ForegroundColor White
            $db_type = "rds"
            break
        }
        elseif ($choice -eq "2") {
            Write-Host "`nSelected: " -NoNewLine
            Write-Host "MongoDB" -ForegroundColor White
            $db_type = "mongo"

            # Get the list of databases
            $output = tsh db ls --format=json | ConvertFrom-Json

            # Filter for RDS only
            $dbs = $output | Where-Object { $_.metadata.labels.db_type -ne "rds" }

            # If no RDS databases are listed, prompt for elevated login
            if (-not $dbs) {
                Clear-Host
                Write-Host "`n====================== Privilege Request ==========================" -ForegroundColor White
                Write-Host "`nYou don't have access to any databases..." -ForegroundColor White
                Write-Host "`nWould you like to raise a request? (y/n): " -ForegroundColor White -NoNewLine
                $elevated = Read-Host
                if ($elevated -match '^[Yy]$') {
                    db_elevated_login
                    return
                }
                return
            }
            break
        }
        else {
            Write-Host "`nInvalid selection. Please choose 1 or 2." -ForegroundColor Red
        }
    }
    if ($script:reauth_db -eq "TRUE") {
        Write-Host "`nRe-Authenticating`n" -ForegroundColor White
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$script:REQUEST_ID" *> $null
        $script:reauth_db = "FALSE"
    }

    if ($script:exit_db -eq "TRUE") {
        $script:exit_db = "FALSE"
        return
    }

    # Fetch and parse JSON output from tsh
    $jsonOutput = tsh db ls --format=json | ConvertFrom-Json

    if ($db_type -eq "rds") {
        $filteredDbs = $jsonOutput | Where-Object { $_.metadata.labels.db_type -eq $db_type  }
    } else {
        $filteredDbs = $jsonOutput | Where-Object { $_.metadata.labels.db_type -ne "rds" }
    }

    # Display full names with numbering
    Clear-Host
    Write-Host "`nAvailable databases:`n" -ForegroundColor White
    $i = 1
    foreach ($db in $filteredDbs) {
        Write-Host ("{0,3}. {1}" -f $i, $db.metadata.name) -ForegroundColor White
        $i++
    }

    # Prompt for selection
    Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
    $db_choice = Read-Host

    while (-not $chosen_db) {
        $index = [int]$db_choice - 1
        if ($index -ge 0 -and $index -lt $filteredDbs.Count) {
            $chosen_db = $filteredDbs[$index]
        } else {
            Write-Host "`nInvalid selection" -ForegroundColor Red
            Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewLine
            $db_choice = Read-Host
        }
    }

    # Extract database name
    $db = $chosen_db.metadata.name

    if (-not $db) {
        Write-Host "`nInvalid selection" -ForegroundColor Red
        return
    }

    if ($chosen_db.metadata.labels.db_type -eq "rds") {
        rds_connect $db
        return
    }
    mongo_connect $db
}

function db_elevated_login() {

    while ($true) {
        if ($elevated -match '^[Yy]$') {
            Write-Host "`nEnter your reason for request: " -ForegroundColor White -NoNewLine
            $reason = Read-Host

            # Create a buffer to store output line-by-line while also printing to the console
            $rawOutputLines = @()
            tsh request create --roles atlas-read-only --reason "$reason" |
                Tee-Object -Variable rawOutputLines |
                ForEach-Object { Write-Host $_ }

            # Join the lines back into a single string (for parsing)
            $rawOutput = $rawOutputLines -join "`n"

            # Extract the Request ID
            $script:REQUEST_ID = ($rawOutput -split "`n" | Where-Object { $_ -match '^Request ID' }) -replace 'Request ID:\s*', '' | ForEach-Object { $_.Trim() }
            $script:reauth_db = "TRUE"

            Write-Host "`nAccess request sent!`n"
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host "`nRequest creation skipped.`n"
            $script:exit_db = "TRUE"
            return
        }
        else {
            Write-Host "`nInvalid input. Please enter y or n."
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

function rds_connect($rds) {
    $db_user = "teleport_rds_read_user"

    Write-Host "`n$rds " -NoNewLine -ForegroundColor Green
    Write-Host "selected." 
    Write-Host "`nHow would you like to connect?`n"
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
        if ($tshStatus -match '\bsudo_teleport_rds_user\b') {
            Write-Host "`nConnecting as admin? (y/n): " -NoNewline
            $admin = Read-Host

            if ($admin -match '^[Yy]$') {
                $db_user = "sudo_teleport_rds_user"
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

        $dbUser = "teleport_rds_read_user"

        Write-Host "`nFetching list of databases from " -ForegroundColor White -NoNewLine
        Write-Host "$rds..." -ForegroundColor Green

        function Get-FreePort {
            $listener = [System.Net.Sockets.TcpListener]::New([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            $port = $listener.LocalEndpoint.Port
            $listener.Stop()
            return $port
        }

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
            Write-Host "`n❌ Failed to establish tunnel to database." -ForegroundColor Red
            try { $proxyProc.Kill() } catch {}
            return
        }

        $query = "SELECT datname FROM pg_database WHERE datistemplate = false;"
        $dbList = & psql "postgres://$dbUser@localhost:$port/postgres" -t -A -c $query 2>$null

        if ([string]::IsNullOrWhiteSpace($dbList)) {
            Write-Host "❌ No databases found or connection failed." -ForegroundColor Red
            try { $proxyProc.Kill() } catch {}
            return
        }

        $databases = $dbList -split "`n" | Where-Object { $_.Trim() -ne "" }

        Write-Host "`nAvailable databases:`n" -ForegroundColor White
        for ($i = 0; $i -lt $databases.Length; $i++) {
            $index = $i + 1
            Write-Host "$index. $($databases[$i])" 
        }

        Write-Host "`nSelect database (number): " -ForegroundColor White -NoNewline
        $choice = Read-Host

        if (-not $choice -or -not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $databases.Length) {
            Write-Host "`nInvalid selection. Exiting." -ForegroundColor Red
            try { $proxyProc.Kill() } catch {}
            return
        }

        $database = $databases[$choice - 1]

        # Cleanup
        try { $proxyProc.Kill() } catch {}

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

function mongo_connect($db) {

    $db_user = switch ($db) {
        "mongodb-YLUSProd-Cluster-1" { "teleport-usprod" }
        "mongodb-YLProd-Cluster-1"   { "teleport-prod" }
        "mongodb-YLSandbox-Cluster-1" { "teleport-sandbox" }
        default {
            Write-Host "`n`e[31mUnknown database: $db`e[0m"
            return
        }
    }

    Write-Host "`n$db" -ForegroundColor Green -NoNewLine
    Write-Host " selected."
    Write-Host "`nHow would you like to connect?"
    Write-Host "`n1. Via " -NoNewLine
    Write-Host "MongoCLI" -ForegroundColor White
    Write-Host "2. Via " -NoNewLine
    Write-Host "AtlasGUI`n" -ForegroundColor White -NoNewLine

    while ($true) {
        $option = Read-Host "`nSelect option (number)"
        switch ($option) {
            "1" {
                    Clear-Host
                    tsh db connect $db --db-user=$db_user --db-name=admin
                    return
            }
            "2" {
                Write-Host "`nLogging into: $db"
                tsh db login $db --db-user=$db_user --db-name=admin | Out-Null

                Write-Host "`nCreating proxy..."
                Start-Process powershell -ArgumentList @(
                    "-NoExit",
                    "-ExecutionPolicy", "Bypass",
                    "-WindowStyle", "Minimized",
                    "-Command", "tsh proxy db --tunnel --port=50000 $db"
                )
                Write-Host "`nOpening MongoDB Compass..."
                Start-Process "mongodb://localhost:50000/?directConnection=true"
                return
            }
            default {
                Write-Host "`nInvalid selection. Please enter 1 or 2."
            }
        }
    }
}