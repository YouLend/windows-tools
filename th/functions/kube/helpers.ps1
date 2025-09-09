function kube_elevated_login {
    param(
        [string]$cluster,
        [string]$env = ""
    )

    $request_role = load_request_role "kube" $cluster

    while ($true) {
        Clear-Host
        create_header "Privilege Request"
        Write-Host "You don't have write access to " -NoNewline
        Write-Host $cluster -ForegroundColor Green -NoNewline
        Write-Host "."
        Write-Host "`nWould you like to raise a request?" -ForegroundColor White
        create_note "Entering (N/n) will log you in as a read-only user."
        Write-Host "(Yy/Nn): " -NoNewline
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            Write-Host "`nEnter your reason for request: " -NoNewline -ForegroundColor White
            $reason = Read-Host

            Write-Host ""
            tsh request create --roles $request_role --max-duration 4h --reason $reason

            $global:reauth_kube = $true
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host ""
            Write-Host "Request creation skipped."
            return
        }
        else {
            Write-Host "`nInvalid input. Please enter y or n." -ForegroundColor Red
        }
    }
}

function check_cluster_access {
    $output = & tsh kube ls -f json 2>$null
    if (-not $output) {
        return @{
            cluster_lines = @()
            login_status = @()
        }
    }

    try {
        $clusters_json = $output | ConvertFrom-Json
        $clusters = $clusters_json | ForEach-Object { $_.kube_cluster_name } | Where-Object { -not [string]::IsNullOrEmpty($_) }
    } catch {
        return @{
            cluster_lines = @()
            login_status = @()
        }
    }

    if (-not $clusters -or $clusters.Count -eq 0) {
        Write-Host "No Kubernetes clusters available."
        return @{
            cluster_lines = @()
            login_status = @()
        }
    }

    $cluster_lines = @()
    $login_status = @()
    $access_status = "unknown"
    $test_cluster = ""
    
    # First pass: collect all cluster names and find a test cluster
    foreach ($cluster_name in $clusters) {
        if ([string]::IsNullOrEmpty($cluster_name)) {
            continue
        }

        $cluster_lines += $cluster_name
        
        # Find first prod cluster to test with
        if ([string]::IsNullOrEmpty($test_cluster) -and $cluster_name -match "prod") {
            $test_cluster = $cluster_name
        }
    }
    
    # Test access with one prod cluster if we found one
    if (-not [string]::IsNullOrEmpty($test_cluster)) {
        try {
            $login_result = & tsh kube login $test_cluster 2>&1
            if ($LASTEXITCODE -eq 0) {
                $auth_result = & kubectl auth can-i create pod 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $access_status = "ok"
                } else {
                    $access_status = "fail"
                }
            } else {
                $access_status = "fail"
            }
        } catch {
            $access_status = "fail"
        }
    }
    
    # Second pass: set status for all clusters based on single test
    foreach ($cluster_name in $cluster_lines) {
        if ($cluster_name -match "prod") {
            $login_status += $access_status
        } else {
            $login_status += "n/a"
        }
    }

    return @{
        cluster_lines = $cluster_lines
        login_status = $login_status
    }
}