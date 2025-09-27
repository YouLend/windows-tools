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