function aws_quick_login {
    param(
        [string]$env_arg,
        [string[]]$additional_args
    )

    $open_browser = $false
    $sudo_flag = ""
    
    # Check additional args for combined flags like 'sb', 'ss', etc.
    foreach ($arg in $additional_args) {
        if ($arg -match "b") {
            $open_browser = $true
        }
        # Check for super sudo first, then regular sudo
        if ($arg -eq "ss" -or $arg -eq "ssb") {
            $sudo_flag = "ss"  # Super sudo
        } elseif ($arg -match "s") {
            $sudo_flag = "s"   # Regular sudo
        }
    }
    
    $account_name = load_config "aws" $env_arg "account"
    
    # Check if the environment exists in config
    if (-not $account_name) {
        show_available_environments "aws" "AWS Login Error" $env_arg
        return
    }
    
    $role_value = load_config "aws" $env_arg "role"
    
    if (-not $role_value) {
        $role_value = $env_arg
    }

    # Check for elevated privilege requirements
    $status = & tsh status 2>&1 | Out-String
    
    if ($sudo_flag -eq "ss") {
        # Super sudo requires TeamLead role
        if (-not ($status -match "TeamLead")) {
            Write-Host "Error: You don't have access to super_sudo roles.`n" -ForegroundColor Red
            return
        }
    } elseif ($sudo_flag -eq "s") {
        # Regular sudo check
        $required_role = "sudo_$($role_value)_role"
        if (-not ($status -match $required_role)) {
            aws_elevated_login $account_name $role_value
            if ($global:reauth_aws -eq $false) {
                return
            }
        }
    }

    Clear-Host
    create_header "AWS Login"
    
    if ($sudo_flag -eq "ss") {
        $role_name = "super_sudo_$role_value"
        Write-Host "Logging you into: " -NoNewline
        Write-Host $account_name -ForegroundColor Green -NoNewline
        Write-Host " as " -NoNewline
        Write-Host $role_name -ForegroundColor Green
    } elseif ($sudo_flag -eq "s") {
        $role_name = "sudo_$role_value"
        Write-Host "Logging you into: " -NoNewline
        Write-Host $account_name -ForegroundColor Green -NoNewline
        Write-Host " as " -NoNewline
        Write-Host $role_name -ForegroundColor Green
    } else {
        $role_name = $role_value
        Write-Host "Logging you into: " -NoNewline
        Write-Host $account_name -ForegroundColor Green -NoNewline
        Write-Host " as " -NoNewline
        Write-Host $role_name -ForegroundColor Green
    }

    & tsh apps logout > $null 2>&1
    & tsh apps login $account_name --aws-role $role_name > $null 2>&1

    Write-Host ""
    Write-Host "Logged in successfully!"
    
    # Skip proxy creation if browser flag is set, open console instead
    if ($open_browser) {
        Write-Host "`n🌐 Opening AWS console in browser...`n"
        $base_url = "https://youlend.teleport.sh/web/launch"
        $app_config = & tsh apps config
        $app_uri = ($app_config | Select-String "URI" | ForEach-Object { ($_ -split '\s+')[1] }) -replace 'https://', ''
        $role_arn = ($app_config | Select-String "AWS ARN" | ForEach-Object { ($_ -split '\s+')[2] }) -replace '/', '%2F'
        $url = "$base_url/$app_uri/youlend.teleport.sh/$app_uri/$role_arn"
        Start-Process $url
    } else {
        create_proxy $account_name $role_name
    }
    
    return
}