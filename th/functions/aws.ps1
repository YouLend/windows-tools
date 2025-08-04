# ============================================================
# =========================== AWS ============================
# ============================================================
function aws_login {
    # If returning from aws_elevated_login reauthenticate with request_id 
    if ($env:reauth_aws -eq "TRUE"){
        Write-Host "`nRe-Authenticating`n" -ForegroundColor White
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$env:REQUEST_ID" *> $null
        $env:reauth_aws = "FALSE"
    }
    else {
        th_login
    }

    # If arguments provided, use quick login
    if ($args.Count -gt 0) {
        aws_quick_login @args
        return
    }
    
    # =====================================
    # Get the list of apps
    $jsonOutput = tsh apps ls --format=json | ConvertFrom-Json

    # Display full names with numbering
    Clear-Host
    Write-Host 
    create_header "Available Accounts"
    $i = 1
    foreach ($app in $jsonOutput) {
        Write-Host ("{0,3}. {1}" -f $i, $app.metadata.name) -ForegroundColor White
        $i++
    }

    # Prompt for selection
    Write-Host "`nSelect app (number): " -ForegroundColor White -NoNewLine
    $app_choice = Read-Host

    if (-not $app_choice) {
        Write-Host "`nNo selection made. Exiting."
        return
    }

    # Resolve selection to object
    $chosen_app = $null
    while (-not $chosen_app) {
        $index = [int]$app_choice - 1
        if ($index -ge 0 -and $index -lt $jsonOutput.Count) {
            $chosen_app = $jsonOutput[$index]
        } else {
            Write-Host "`nInvalid selection" -ForegroundColor Red
            Write-Host "`nSelect app (number): " -ForegroundColor White -NoNewLine
            $app_choice = Read-Host
        }
    }

    # Extract app name
    $app = $chosen_app.metadata.name

    Write-Host "`nSelected app: " -ForegroundColor White -NoNewLine
    Write-Host $app -ForegroundColor Green

    tsh apps logout *> $null

    # ============== Role Selection ====================

    # Attempt login to get AWS role info (expecting error but want the printed roles)
    $loginOutput = tsh apps login $app 2>&1

    # Extract AWS roles section
    $startMarker = "Available AWS roles:"
    $endMarker = "ERROR: --aws-role flag is required"
    $inSection = $false
    $roleSection = @()

    foreach ($line in $loginOutput -split "`n") {
        if ($line -match $startMarker) {
        $inSection = $true
        continue
        }
        if ($line -match $endMarker) {
        $inSection = $false
        break
        }
        if ($inSection -and $line.Trim() -ne "" -and $line -notmatch "ERROR:") {
        $roleSection += $line
        }
    }

    Write-Host $loginOutput
    $defaultRole = ($loginOutput | Select-String -Pattern 'arn:aws:iam::[^ ]*').Matches.Value -replace '^.*role/', ''

    if (-not $roleSection) {
        aws_elevated_login $app $defaultRole
    }

    $rolesList = $roleSection[2..($roleSection.Count - 1)]

    if (-not $rolesList) {
        Write-Host "No roles found in the AWS roles listing."
        Write-Host "Logging you into app '$app' without specifying an AWS role."
        tsh apps login $app
        return
    }
    # Print available roles
    Clear-Host
    Write-Host
    create_header "Available Roles"
    for ($i = 0; $i -lt $rolesList.Count; $i++) {
        $roleNameOnly = ($rolesList[$i] -split '\s+')[0]
        Write-Host ("{0,2}. {1}" -f ($i + 1), $roleNameOnly) -ForegroundColor White
    }

    # Prompt for role selection
    Write-Host "`nSelect role (number): " -ForegroundColor White -NoNewLine
    $roleChoice = Read-Host 
    if (-not $roleChoice -or -not ($roleChoice -match '^\d+$')) {
        Write-Host "No valid selection made. Exiting."
        return
    }

    $roleIndex = [int]$roleChoice - 1
    if ($roleIndex -lt 0 -or $roleIndex -ge $rolesList.Count) {
        Write-Host "Invalid selection."
        return
    }

    $roleLine = $rolesList[$roleIndex]
    $roleName = ($roleLine -split '\s+')[0]

    if (-not $roleName) {
        Write-Host "Invalid selection."
        return
    }

    Write-Host "`nLogging you into " -ForegroundColor White -NoNewLine
    Write-Host $app -ForegroundColor Green -NoNewLine
    Write-Host " as " -ForegroundColor White -NoNewLine
    Write-Host $roleName -ForegroundColor Green
    tsh apps login $app --aws-role $roleName *>$null
    Write-Host "`nLogged in successfully!" -ForegroundColor Green
    create_proxy
}

# AWS account mapping
function load_aws_config {
    param([string]$env)
    
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $configFile = Join-Path $scriptDir "/config.json"
    
    if (-not (Test-Path $configFile)) {
        return ""
    }
    
    try {
        $config = Get-Content $configFile | ConvertFrom-Json
        return $config.aws.$env
    }
    catch {
        Write-Host "Error reading config file: $_" -ForegroundColor Red
        return ""
    }
}

# Quick AWS login
function aws_quick_login {
    param(
        [string]$env_arg,
        [string]$sudo_flag
    )
    
    if (-not $env_arg) {
        Write-Host "Usage: aws_quick_login <environment> [s]"
        Write-Host "Available environments: dev, sandbox, staging, usstaging, admin, prod, usprod, corepgblue, corepggreen"
        return
    }
    
    $account_name = load_aws_config $env_arg
    if (-not $account_name) {
        Write-Host "Environment '$env_arg' not found in th.config.json" -ForegroundColor Red
        return
    }

    Clear-Host
    create_header "AWS Login"
    
    $role_value = switch ($env_arg) {
        "dev" { "dev" }
        "corepg" { "coreplayground" }
        default { $env_arg }
    }
    
    if ($sudo_flag -eq "s") {
        $role_name = "sudo_$role_value"
    } else {
        $role_name = $role_value
    }
    
    Write-Host "Logging you into: " -NoNewLine
    Write-Host $account_name -ForegroundColor Green -NoNewLine
    Write-Host " as " -NoNewLine
    Write-Host $role_name -ForegroundColor Green
    
    tsh apps logout *>$null 2>&1
    tsh apps login $account_name --aws-role $role_name *>$null 2>&1
    
    Write-Host "`nLogged in successfully!" -ForegroundColor Green
    create_proxy $account_name
}


function create_proxy($app) {
    # If no app provided, get active app
    if (-not $app) {
        $app = & tsh apps ls -f text | ForEach-Object {
            if ($_ -match '^>\s+(\S+)') { $matches[1] }
        }
    }

    if (-not $app) {
        Write-Host "No active app found. Run 'tsh apps login <app>' first."
        return 1
    }

    Write-Host "`nPreparing environment for app: $app"

    $tempDir = $env:TEMP
    $logFile = Join-Path $tempDir "tsh_proxy_output_$app.log"
    $envSnapshot = Join-Path $tempDir "$app.ps1"
    $scriptPath = Join-Path $tempDir "launch_proxy_$app.ps1"
    $pidFile = Join-Path $tempDir "tsh_proxy_$app.pid"

    # Assign port
    $port = 60000 + ([Math]::Abs($app.GetHashCode()) % 1000)
    Write-Host "Using port " -NoNewLine
    Write-Host $port -ForegroundColor Green -NoNewLine
    Write-Host " for local proxy..."

    # Build proxy command
    $command = "tsh proxy aws --app `"$app`" --port $port 2>&1 | Tee-Object -FilePath `"$logFile`""
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

    # Confirm port is listening
    Start-Sleep -Milliseconds 500
    $tcpListening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if (-not $tcpListening) {
        Write-Host "Proxy process failed to bind to port $port."
        return
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

    Write-Host "`nCredentials applied and stored for: " -ForegroundColor White -NoNewLine
    Write-Host $app -ForegroundColor Green
    Write-Host
}

function aws_elevated_login($app, $defaultRole) {
    Clear-Host
    create_header "Privilege Request"
    Write-Host "`nNo privileged roles found. Your only available role is: " -NoNewLine
    Write-Host $defaultRole -ForegroundColor Green
    while ($true) {
        Write-Host "`nWould you like to raise a privilege request?"
        create_note "Entering (n) will log you in as prod"
        $request = Read-Host "(y/n)"
        $request = $request.Trim()
        if ($request -match '^[Yy]$') {
            Write-Host "`nEnter request reason: " -ForegroundColor White -NoNewLine
            $reason = Read-Host 
            switch ($app) {
                "yl-production" {
                    Write-Host "`nAccess request sent for sudo_prod." -ForegroundColor Green
                    $rawOutputLines = @()
                    tsh request create --roles sudo_prod_role  --reason "$reason" |
                        Tee-Object -Variable rawOutputLines |
                        ForEach-Object { Write-Host $_ }

                    # Join the lines back into a single string (for parsing)
                    $rawOutput = $rawOutputLines -join "`n"

                    # Extract the Request ID
                    $env:REQUEST_ID = ($rawOutput -split "`n" | Where-Object { $_ -match '^Request ID' }) -replace 'Request ID:\s*', '' | ForEach-Object { $_.Trim() }
                    $env:reauth_aws = "TRUE"
                }
                "yl-usproduction" {
                    Write-Host "`nAccess request sent for sudo_usprod." -ForegroundColor Green
                    $rawOutputLines = @()
                    tsh request create --roles sudo_usprod_role --reason "$reason" |
                        Tee-Object -Variable rawOutputLines |
                        ForEach-Object { Write-Host $_ }

                    # Join the lines back into a single string (for parsing)
                    $rawOutput = $rawOutputLines -join "`n"

                    # Extract the Request ID
                    $env:REQUEST_ID = ($rawOutput -split "`n" | Where-Object { $_ -match '^Request ID' }) -replace 'Request ID:\s*', '' | ForEach-Object { $_.Trim() }
                    $env:reauth_aws = "TRUE"
                }
            }
        }
        elseif ($request -match '^[Nn]$') {
            Write-Host "`nLogging you into " -ForegroundColor White -NoNewLine
            Write-Host $app -ForegroundColor Green -NoNewLine
            Write-Host " as " -ForegroundColor White -NoNewLine
            Write-Host $defaultRole -ForegroundColor Green
            tsh apps login $app --aws-role $defaultRole *>$null
            Write-Host "`nLogged in successfully!" -ForegroundColor Green
            create_proxy
            return
        }
        else {
            Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Red
        }
    }
}

# ============================================================
# ======================== Terraform =========================
# ============================================================
function terraform_login {
    th_login
    Clear-Host
    create_header "Terragrunt"
    tsh apps logout *>$null
    Write-Host "Logging into " -ForegroundColor White -NoNewLine
    Write-Host "yl-admin " -ForegroundColor Green -NoNewLine
    Write-Host "as " -ForegroundColor White -NoNewLine
    Write-Host "sudo_admin" -ForegroundColor Green
    tsh apps login "yl-admin" --aws-role "sudo_admin" *>$null
    create_proxy
    Write-Host "Logged in successfully`n" -ForegroundColor Green
}