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
    $full_names = @()
    $login_status = @()
    $access_status = "unknown"
    $test_cluster = ""

    # First pass: collect all cluster names and find a test cluster
    foreach ($cluster_name in $clusters) {
        if ([string]::IsNullOrEmpty($cluster_name)) {
            continue
        }

        # Extract prefix-env from full cluster name (first two dash-separated segments)
        $display_name = if ($cluster_name -match '^([^-]+-[^-]+)') { $matches[1] } else { $cluster_name }
        $cluster_lines += $display_name
        $full_names += $cluster_name
        
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
        full_names = $full_names
        login_status = $login_status
    }
}