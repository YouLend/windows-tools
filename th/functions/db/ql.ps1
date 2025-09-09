function db_quick_login {
    param(
        [string]$env_arg,
        [string[]]$additional_args
    )

    $port = ""
    $db_type = "rds"  # Default to RDS
    $env_name = ""

    if ($env_arg -match "^m-") {
        $db_type = "mongo"
        $env_name = $env_arg.Substring(2)
    } elseif ($env_arg -match "^r-") {
        $db_type = "rds"
        $env_name = $env_arg.Substring(2)
    } else {
        # No valid prefix found - show error
        show_available_environments "db" "DB Login Error" $env_arg
        return
    }

    $db_name = load_config "db" $env_name "database" $db_type
    if ([string]::IsNullOrEmpty($db_name)) {
        show_available_environments "db" "DB Login Error" $env_arg
        return
    }
    
    # Validate port number if provided in any argument
    foreach ($arg in $additional_args) {
        if ($arg -match '^\d+$') {
            $port_num = [int]$arg
            if ($port_num -lt 30000 -or $port_num -gt 50000) {
                Write-Host "L Port number must be between 30000 and 50000" -ForegroundColor Red
                return
            }
            $port = $arg
            break
        }
    }

    # Check for privileged environments requiring elevated access
    if ($db_type -eq "rds") {
        switch ($env_name) {
            { $_ -in @("pv", "pb", "upb", "upv", "prod", "usprod") } {
                $status = & tsh status 2>&1 | Out-String
                $request_role = load_request_role "db" $env_name "rds"
                if (-not ($status -match $request_role)) {
                    db_elevated_login $request_role $db_name
                }
            }
        }
    } elseif ($db_type -eq "mongo") {
        switch ($env_name) {
            { $_ -in @("prod", "uprod", "sand") } {
                $status = & tsh status 2>&1 | Out-String
                $request_role = load_request_role "db" $env_name "mongo"
                if (-not ($status -match $request_role)) {
                    db_elevated_login $request_role $db_name
                }
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($db_name)) {
        Clear-Host
        create_header "DB Login Error"
        Write-Host "`nL Environment '$env_name' not found for $db_type.`n" -ForegroundColor Red
        return
    }
    
    Clear-Host
    create_header "DB Quick Login"

    if ([string]::IsNullOrEmpty($port)) { 
        $port = find_available_port 
    }
    
    if ($db_type -eq "rds") {
        open_dbeaver $db_name "tf_teleport_rds_read_user" $port
    } elseif ($db_type -eq "mongo") {
        open_atlas $db_name $port
    }
}