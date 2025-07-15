# ============================================================
# ======================== Databases =========================
# ============================================================

function db_login {
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

            # Perform teleport login if needed
            th_login

            # Get the list of databases
            $output = tsh db ls --format=json | ConvertFrom-Json

            # Filter for RDS only
            $dbs = $output | Where-Object { $_.metadata.labels.db_type -eq $db_type }

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
        elseif ($choice -eq "2") {
            Write-Host "`nSelected: " -NoNewLine
            Write-Host "MongoDB" -ForegroundColor White
            $db_type = "mongo"

            th_login

            # Get the list of databases
            $output = tsh db ls --format=json | ConvertFrom-Json

            # Filter for RDS only
            $dbs = $output | Where-Object { $_.metadata.labels.db_type -eq $db_type }

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

    $filteredDbs = $jsonOutput | Where-Object { $_.metadata.labels.db_type -eq $db_type }

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

function db_elevated_login {
    param (
        [string]$cluster = $null
    )

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

function open_dbeaver($database, $rds, $db_user) {
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

function rds_connect {
    param (
        [string]$rds
    )

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

    switch ($option) {
        1 {
            Write-Host "`nWhich internal database would you like to connect to?" -ForegroundColor White
            Write-Host "`nEnter db name (leave blank to connect to " -NoNewLine -ForegroundColor White
            Write-Host "postgres" -ForegroundColor White -NoNewLine
            Write-Host "): " -NoNewLine
            $database = Read-Host 
            $db_user=""
            while ($true) {
                Write-Host "`nConnecting as Admin? (y/n): " -ForegroundColor White -NoNewLine
                $admin = Read-Host
                if ($admin -match '^[Yy]$') {
                    $db_user = "sudo_teleport_rds_user"
                    break
                }
                elseif ($admin -match '^[Nn]$') {
                    $db_user="teleport_rds_read_user"
                    break
                }
                else {
                    Write-Host "`nInvalid selection. Please enter Y or N: " -ForegroundColor Red                
                }
            }
            if ([string]::IsNullOrWhiteSpace($database)) {
                $database = "postgres"
            }

            Write-Host "`n`nConnecting to " -NoNewLine
            Write-Host "$database " -NoNewLine -ForegroundColor Green
            Write-Host "in " -NoNewLine
            Write-Host "$rds " -NoNewLine -ForegroundColor Green
            Write-Host "as " -NoNewLine 
            Write-Host "$db_user" -ForegroundColor Green
            for ($i = 3; $i -ge 1; $i--) {
                Write-Host ". " -NoNewline -ForegroundColor Green
                Start-Sleep -Seconds 1
            }
            Clear-Host

            tsh db connect $rds --db-user=$db_user --db-name=$database
        }
        2 {
            Write-Host "`nConnecting via DBeaver..."
            Write-Host "`nWhich internal database would you like to connect to?" -ForegroundColor White
            Write-Host "`nEnter db name (leave blank to connect to " -NoNewLine
            Write-Host "postgres" -ForegroundColor White -NoNewLine
            Write-Host "): " -NoNewLine
            $database = Read-Host 
            $db_user=""
            while ($true) {
                Write-Host "`nConnecting as Admin? (y/n): " -ForegroundColor White -NoNewLine
                $admin = Read-Host
                if ($admin -match '^[Yy]$') {
                    $db_user = "sudo_teleport_rds_user"
                    break
                }
                elseif ($admin -match '^[Nn]$') {
                    $db_user="teleport_rds_read_user"
                    break
                }
                else {
                    Write-Host "`nInvalid selection. Please enter Y or N: " -ForegroundColor Red
                }
            }
            
            if ([string]::IsNullOrWhiteSpace($database)) {
                $database = "postgres"
                open_dbeaver "postgres" $rds $db_user
                return
            }
            open_dbeaver $database $rds $db_user
            return
        }
        default {
            Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        }
    }
}

function mongo_connect {
    param (
        [string]$db
    )

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