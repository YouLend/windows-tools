function check_rds_login {
    $output = & tsh db ls -f json 2>$null
    if (-not $output) {
        return @{
            db_lines = @()
            login_status = @()
        }
    }

    try {
        $dbs_json = $output | ConvertFrom-Json
        $dbs = $dbs_json | Where-Object { $_.metadata.labels.db_type -eq "rds" -or $_.metadata.labels.CreatedBy -eq "Terraform" } | ForEach-Object { $_.metadata.name }
    } catch {
        return @{
            db_lines = @()
            login_status = @()
        }
    }

    $db_lines = @()
    $full_names = @()
    $login_status = @()
    $access_status = "unknown"
    $test_db = ""

    # First pass: collect all db names and find a test database
    foreach ($db_name in $dbs) {
        if ([string]::IsNullOrEmpty($db_name)) {
            continue
        }

        # Extract prefix-env from full name - include extra segment for live-prod/usprod
        $display_name = if ($db_name -match '(live-prod|usprod)') {
            if ($db_name -match '^([^-]+-[^-]+-[^-]+)') { $matches[1] } else { $db_name }
        } else {
            if ($db_name -match '^([^-]+-[^-]+)') { $matches[1] } else { $db_name }
        }
        $db_lines += $display_name
        $full_names += $db_name
        
        # Find first prod/sandbox db to test with
        if ([string]::IsNullOrEmpty($test_db) -and ($db_name -match "prod|sandbox")) {
            $test_db = $db_name
        }
    }
    
    # Check if user has the requestable role for database access
    $status = & tsh status 2>$null
    if ($status -match "sudo_teleport_rds_read_role") {
        $access_status = "ok"
    } else {
        $access_status = "fail"
    }
    
    # Second pass: set status for all databases based on single test
    foreach ($db_name in $db_lines) {
        if ($db_name -match "prod|sandbox") {
            $login_status += $access_status
        } else {
            $login_status += "n/a"
        }
    }

    return @{
        db_lines = $db_lines
        full_names = $full_names
        login_status = $login_status
    }
}