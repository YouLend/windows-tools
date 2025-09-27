function create_db_proxy {
    param (
        [string]$cluster,
        [int]$port,
        [string]$db_user="",
        [string]$database=""
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