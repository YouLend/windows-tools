function db_quick_login {
    param(
        [string]$env_arg,
        [string[]]$additional_args
    )

    $port = ""
    $cluster_type = "rds"  # Default to RDS
    $env_name = ""
    $open_console = $false
    
    if ($env_arg -match "^m-") {
        $cluster_type = "mongo"
        $env_name = $env_arg.Substring(2)
    } elseif ($env_arg -match "^r-") {
        $cluster_type = "rds"
        $env_name = $env_arg.Substring(2)
    } else {
        # No valid prefix found - show error
        show_available_environments "db" "DB Login Error" $env_arg
        return
    }

    $cluster = load_config "db" $env_name "database" $cluster_type
    if ([string]::IsNullOrEmpty($cluster)) {
        show_available_environments "db" "DB Login Error" $env_arg
        return
    }
    
    # Validate port number if provided in any argument
    foreach ($arg in $additional_args) {
        if ($arg -match '^\d+$') {
            $port_num = [int]$arg
            if ($port_num -lt 10000 -or $port_num -gt 50000) {
                Write-Host "❌ Port number must be between 10000 and 50000" -ForegroundColor Red
                return
            }
            # Check if port is already in use
            $tcpConnection = Get-NetTCPConnection -LocalPort $port_num -State Listen -ErrorAction SilentlyContinue
            if ($tcpConnection) {
                Write-Host "`n❌ Port $port_num is already in use. Please specify a different port.`n" -ForegroundColor Red
                return
            }
            $port = $arg
            break
        }
    }

    # Check additional args for console flag
    foreach ($arg in $additional_args) {
        if ($arg -eq "c" -or $arg -eq "console") {
            $open_console = $true
        }
    }

    # Check for privileged environments requiring elevated access
    if ($cluster_type -eq "rds") {
        switch ($env_name) {
            { $_ -in @("pv", "pb", "upb", "upv", "prod", "usprod") } {
                $status = & tsh status 2>&1 | Out-String
                $request_role = load_request_role "db" $env_name "rds"
                if (-not ($status -match $request_role)) {
                    db_elevated_login $request_role $cluster
                }
            }
        }
    } elseif ($cluster_type -eq "mongo") {
        switch ($env_name) {
            { $_ -in @("prod", "uprod", "sand") } {
                $status = & tsh status 2>&1 | Out-String
                $request_role = load_request_role "db" $env_name "mongo"
                if (-not ($status -match $request_role)) {
                    db_elevated_login $request_role $cluster
                }
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($cluster)) {
        Clear-Host
        create_header "DB Login Error"
        Write-Host "`nL Environment '$env_name' not found for $cluster_type.`n" -ForegroundColor Red
        return
    }
    
    if ([string]::IsNullOrEmpty($port)) { 
        $port = find_available_port 
    }
    
    if ($open_console -eq $true) {
        if ($cluster_type -eq "rds") {
            $database = list_postgres_databases $cluster $port
            connect_psql $cluster $database "tf_teleport_rds_read_user"
            $open_console = $false
        } elseif ($cluster_type -eq "mongo") {
            mongocli_connect $cluster
            $open_console = $false
        }
    } else {
        Clear-Host
        create_header "DB Quick Login"
        if ($cluster_type -eq "rds") {
            open_dbeaver $cluster "tf_teleport_rds_read_user" $port
        } elseif ($cluster_type -eq "mongo") {
            open_atlas $cluster $port
        }
    }
}