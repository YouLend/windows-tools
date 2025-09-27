function create_proxy($app, $role) {

    # Kill existing proxy processes
    $tempDir = $env:TEMP
    
    # Kill processes by PID files
    Get-ChildItem -Path $tempDir -Filter "tsh_proxy_*.pid" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $pid = Get-Content $_.FullName -ErrorAction SilentlyContinue
            if ($pid) {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignore errors if process doesn't exist
        }
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
    
    # Kill any remaining tsh proxy processes
    Get-Process -Name "tsh" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*proxy aws*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Wait a moment for processes to fully terminate
    Start-Sleep -Milliseconds 500

    # Clean up existing AWS environment variables
    $awsEnvVars = @('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN', 'AWS_DEFAULT_REGION', 'ACCOUNT', 'ROLE')
    foreach ($var in $awsEnvVars) {
        Remove-Item -Path "Env:$var" -ErrorAction SilentlyContinue
    }

    # Clean up existing temp files for all apps
    Get-ChildItem -Path $tempDir -Filter "tsh_proxy_output_*.log" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $tempDir -Filter "yl-*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $tempDir -Filter "launch_proxy_*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "`nStarting AWS proxy for " -NoNewLine
    Write-Host "$app" -ForegroundColor Green
    $logFile = Join-Path $tempDir "tsh_proxy_output_$app.log"
    $envSnapshot = Join-Path $tempDir "$app.ps1"
    $scriptPath = Join-Path $tempDir "launch_proxy_$app.ps1"
    $pidFile = Join-Path $tempDir "tsh_proxy_$app.pid"

    # Build proxy command
    $command = "tsh proxy aws --app `"$app`" 2>&1 | Tee-Object -FilePath `"$logFile`""
    Set-Content -Path $scriptPath -Value $command

    # Start proxy in background
    $proc = Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden", "-ExecutionPolicy Bypass", "-File `"$scriptPath`"" -PassThru
    $proc.Id | Out-File -FilePath $pidFile

    # Wait for credentials
    $timeout = 20
    $waitCount = 0
    while ($true) {
        Start-Sleep -Milliseconds 500
        if ((Test-Path $logFile) -and (Select-String -Path $logFile -Pattern '\$Env:AWS_ACCESS_KEY_ID=' -Quiet)) {
            break
        }
        $waitCount++
        if ($waitCount -ge $timeout) {
            Write-Host "Timed out waiting for AWS credentials."
            return
        }
    }

    # Extract and apply environment variables
    $exports = Get-Content $logFile | Where-Object { $_ -match '^\s*\$Env:\w+=' }
    Remove-Item -Path $envSnapshot -ErrorAction SilentlyContinue

    foreach ($line in $exports) {
        if ($line -match '\$Env:(\w+)="([^"]+)"') {
            $name = $matches[1]
            $val = $matches[2]
            Set-Item -Path "Env:$name" -Value $val
            "`$env:${name} = '$val'" | Out-File -Append -FilePath $envSnapshot
        }
    }

    # Add ACCOUNT and REGION
    "`$env:ACCOUNT = '$app'" | Out-File -Append -FilePath $envSnapshot
    Set-Item -Path Env:ACCOUNT -Value $app

    "`$env:ROLE = '$role'" | Out-File -Append -FilePath $envSnapshot
    Set-Item -Path Env:ACCOUNT -Value $role

    $region = if ($app -like "yl-us*") { "us-east-2" } else { "eu-west-1" }
    "`$env:AWS_DEFAULT_REGION = '$region'" | Out-File -Append -FilePath $envSnapshot
    Set-Item -Path Env:AWS_DEFAULT_REGION -Value $region

    # Clean and update PowerShell profile
    $profilePath = $PROFILE
    $sourceLine = "`nif (Test-Path '$envSnapshot') { . '$envSnapshot' }"

    if (Test-Path $profilePath) {
        $existingLines = Get-Content $profilePath
        $filteredLines = $existingLines | Where-Object { $_ -notmatch 'Temp\\yl-.*\.ps1' }

        # Ensure trailing newline before adding sourceLine
        if ($filteredLines.Count -gt 0 -and $filteredLines[-1] -ne '') {
            $filteredLines += ''
        }

        $updatedLines = $filteredLines + $sourceLine
        Set-Content -Path $profilePath -Value $updatedLines -Encoding UTF8
    } else {
        Set-Content -Path $profilePath -Value $sourceLine -Encoding UTF8
    }

    Write-Host "`nCredentials exported, and made global, for: " -NoNewLine
    Write-Host $app -ForegroundColor Green
    Write-Host
}