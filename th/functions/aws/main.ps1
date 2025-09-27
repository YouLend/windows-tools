function aws_login {
    param(
        [string[]]$Arguments
    )
    th_login

    & tsh apps logout > $null 2>&1

    if ($Arguments -and $Arguments.Count -gt 0) {
        if ($Arguments.Count -eq 1) {
            aws_quick_login $Arguments[0]
        } else {
            aws_quick_login $Arguments[0] $Arguments[1..($Arguments.Count-1)]
        }
        return
    }
    
    # Fetch JSON output from tsh
    $jsonOutput = & tsh apps ls --format=json | ConvertFrom-Json
    
    # Filter matching databases
    Clear-Host
    create_header "Available accounts"
    $filtered = $jsonOutput | Where-Object { $_.metadata.name -ne $null }
    
    # Display enumerated names
    $accounts = @()
    $full_names = @()
    $index = 1
    foreach ($app in $filtered) {
        $full_name = $app.metadata.name
        # Remove yl- prefix except for mlflow accounts
        $display_name = if ($full_name -match "mlflow") {
            $full_name
        } elseif ($full_name -match "^yl-(.+)") {
            $matches[1]
        } else {
            $full_name
        }
        Write-Host "$index. $display_name"
        $accounts += $display_name
        $full_names += $full_name
        $index++
    }
    
    # Prompt for app selection
    Write-Host ""
    Write-Host "Select account (number): " -NoNewline -ForegroundColor White
    $appChoice = Read-Host
    
    # Validate input
    while ($appChoice -notmatch '^\d+$' -or [int]$appChoice -lt 1 -or [int]$appChoice -gt $accounts.Count) {
        Write-Host ""
        Write-Host "Invalid selection" -ForegroundColor Red
        Write-Host "Select account (number): " -NoNewline -ForegroundColor White
        $appChoice = Read-Host
    }
    
    $selectedApp = $full_names[[int]$appChoice - 1]
    
    Write-Host ""
    Write-Host "Selected app: " -NoNewline
    Write-Host $selectedApp -ForegroundColor Green
    Start-Sleep 1
    
    # Log out to force fresh AWS role output
    & tsh apps logout > $null 2>&1
    
    # Run tsh apps login to capture the AWS roles listing
    $loginOutput = & tsh apps login $selectedApp 2>&1
    $loginOutputString = $loginOutput -join "`n"
    
    # Extract the AWS roles section
    $roleSection = @()
    $captureRoles = $false
    foreach ($line in $loginOutput) {
        if ($line -match "Available AWS roles:") {
            $captureRoles = $true
            continue
        }
        if ($line -match "ERROR: --aws-role flag is required") {
            $captureRoles = $false
            break
        }
        if ($captureRoles -and $line -notmatch "ERROR:" -and $line.Trim() -ne "") {
            $roleSection += $line
        }
    }
    
    # Extract default role
    $defaultRole = ""
    if ($loginOutputString -match "arn:aws:iam::\d+:role/([^\s]+)") {
        $defaultRole = $Matches[1]
    }

    if ($roleSection.Count -eq 0) {
        aws_elevated_login $selectedApp $defaultRole
    }
    
    if ($global:reauth_aws -eq $true) {
        # Refresh login output
        $loginOutput = & tsh apps login $selectedApp 2>&1
        $roleSection = @()
        $captureRoles = $false
        foreach ($line in $loginOutput) {
            if ($line -match "Available AWS roles:") {
                $captureRoles = $true
                continue
            }
            if ($line -match "ERROR: --aws-role flag is required") {
                $captureRoles = $false
                break
            }
            if ($captureRoles -and $line -notmatch "ERROR:" -and $line.Trim() -ne "") {
                $roleSection += $line
            }
        }
    } elseif ($global:reauth_aws -eq $false) {
        return
    }
    
    # Extract roles list (skip first 2 header lines)
    $rolesList = @()
    for ($i = 2; $i -lt $roleSection.Count; $i++) {
        $roleLine = $roleSection[$i].Trim()
        if ($roleLine -ne "") {
            $role = ($roleLine -split '\s+')[0]
            $rolesList += $role
        }
    }
    
    Clear-Host
    create_header "Available Roles"
    
    $index = 1
    foreach ($role in $rolesList) {
        Write-Host "$index. $role"
        $index++
    }
    
    # Prompt for role selection
    Write-Host ""
    Write-Host "Select role (number): " -NoNewline -ForegroundColor White
    $roleChoice = Read-Host
    
    while ($roleChoice -notmatch '^\d+$' -or [int]$roleChoice -lt 1 -or [int]$roleChoice -gt $rolesList.Count) {
        Write-Host ""
        Write-Host "Invalid selection" -ForegroundColor Red
        Write-Host ""
        Write-Host "Select role (number): " -NoNewline -ForegroundColor White
        $roleChoice = Read-Host
    }
    
    $selectedRole = $rolesList[[int]$roleChoice - 1]
    
    Write-Host ""
    Write-Host "Logging you into " -NoNewline
    Write-Host $selectedApp -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline
    Write-Host $selectedRole -ForegroundColor Green
    
    & tsh apps login $selectedApp --aws-role $selectedRole > $null 2>&1
    Write-Host ""
    Write-Host "Logged in successfully!" -ForegroundColor Green
    
    create_proxy $selectedApp $selectedRole
}