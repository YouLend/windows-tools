# ============================================================
# ======================= Kubernetes =========================
# ============================================================
function kube_login($envArg) {
    th_login
    # If the user passes in an argument e.g. admin. Log them straight in to that cluster
    if ($envArg) {
        kube_quick_login
        return
    }

    Clear-Host
    create_header "Available Clusters"

    # Use load function for cluster access checking
    $results = load -Job { check_cluster_access } -Message "Checking cluster access..."

    if (-not $results.success) {
        Write-Host "$($results.error)" -ForegroundColor Red
        return 1
    }

    # Ensure arrays are properly handled
    $clusterLines = @($results.clusters)
    $loginStatus = @($results.statuses)

    # Print results
    for ($i = 0; $i -lt $clusterLines.Count; $i++) {
        $line = $clusterLines[$i]
        $status = $loginStatus[$i]

        switch ($status) {
            "ok"   { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor White}
            "fail" { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor DarkGray}
            "n/a"  { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor White}
        }
    }

    Write-Host "`nSelect cluster (number): " -ForegroundColor White -NoNewLine
    $choice = Read-Host

    if (-not $choice -or -not ($choice -match '^\d+$')) {
        Write-Host "No valid selection made. Exiting." -ForegroundColor Red
        return 1
    }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $clusterLines.Count) {
        Write-Host "`nInvalid selection" -ForegroundColor Red
        return 1
    }

    $selectedCluster = $clusterLines[$index]
    $selectedStatus = $loginStatus[$index]

    if ($selectedStatus -eq "fail") {
        kube_elevated_login $selectedCluster
    } 
    # If a user is returning from a privilege request (kube_elevated_login), reauth first
    if ($env:reauth_kube -eq "TRUE") {
        Write-Host "`nRe-Authenticating`n" -ForegroundColor White
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$env:REQUEST_ID" *> $null
        $env:reauth_kube = "FALSE"
        return
    }

    Write-Host "`nLogging you into: " -NoNewLine
    Write-Host $selectedCluster -ForegroundColor Green
    tsh kube login $selectedCluster *> $null
    Write-Host "`nLogged in successfully!`n" -ForegroundColor White
}

function kube_quick_login() {
    # Direct login if environment argument provided
    $clusterName = load_kube_config $envArg
    
    if (-not $clusterName) {
        Write-Host "`n" -NoNewLine
        Write-Host "Unknown environment: $envArg" -ForegroundColor Red
        Write-Host "`nAvailable environments: dev, sandbox, staging, usstaging, admin, prod, usprod, corepgblue, corepggreen"
        return 1
    }

    Clear-Host
    create_header "Kube Login"
    
    Write-Host "Logging you into: " -NoNewLine
    Write-Host $clusterName -ForegroundColor Green

    tsh kube login $clusterName *> $null
    
    Write-Host "`nLogged in successfully!`n"
    return
}

# Cluster environment mapping - resides in ../config.json
function load_kube_config {
    param([string]$env)
    
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $configFile = Join-Path $scriptDir "/config.json"
    
    if (-not (Test-Path $configFile)) {
        return ""
    }
    
    try {
        $config = Get-Content $configFile | ConvertFrom-Json
        return $config.kube.$env
    }
    catch {
        Write-Host "Error reading config file: $_" -ForegroundColor Red
        return ""
    }
}

function check_cluster_access {
    $output = tsh kube ls -f json
    $clusters = ($output | ConvertFrom-Json) | ForEach-Object { $_.kube_cluster_name } | Where-Object { $_ -and $_.Trim() -ne "" }

    if (-not $clusters) {
        return @{ success = $false; error = "No Kubernetes clusters available." }
    }

    $accessStatus = "unknown"
    $testCluster = $null
    $clusterNames = @()
    $statuses = @()

    # Collect cluster names, pick test cluster
    foreach ($cluster in $clusters) {
        if (-not [string]::IsNullOrWhiteSpace($cluster)) {
            $clusterNames += $cluster
            if (-not $testCluster -and ($cluster -match "prod")) {
                $testCluster = $cluster
            }
        }
    }

    # Test access with one prod cluster if we found one
    if ($testCluster) {
        try {
            tsh kube login $testCluster *>$null
            $canCreate = kubectl auth can-i create pod 2>$null
            if ($canCreate -eq "yes") {
                $accessStatus = "ok"
            } else {
                $accessStatus = "fail"
            }
        } catch {
            $accessStatus = "fail"
        }
    }

    # Build status array
    foreach ($cluster in $clusterNames) {
        if ($cluster -match "prod") {
            $statuses += $accessStatus
        } else {
            $statuses += "n/a"
        }
    }

    # Return results as hashtable
    return @{
        success = $true
        clusters = $clusterNames
        statuses = $statuses
    }
}

function kube_elevated_login($cluster) {
    while ($true) {
        Clear-Host
        create_header "Privilege Request"
        Write-Host "You don't have write access to " -NoNewLine
        Write-Host "$cluster.`n" -ForegroundColor White
        Write-Host "Would you like to raise a request?" -ForegroundColor White
        Write-Host "`nNote:" -ForegroundColor White -NoNewLine
        Write-Host "Entering (N/n) will log you in as a read-only user."
        Write-Host "`n(Yy/Nn): " -NoNewLine
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            Write-Host "`n" -NoNewLine
            Write-Host "Enter your reason for request: " -ForegroundColor White -NoNewLine
            $reason = Read-Host

            $requestOutput = ""
            if ($cluster -eq 'live-prod-eks-blue') {
                $requestOutput = tsh request create --roles sudo_prod_eks_cluster --reason "$reason"
            }
            elseif ($cluster -eq 'live-usprod-eks-blue') {
                $requestOutput = tsh request create --roles sudo_usprod_eks_cluster --reason "$reason"
            }
            else {
                Write-Host "`nCluster doesn't exist" -ForegroundColor Red
                continue
            }

            # Extract request ID
            $env:REQUEST_ID = ($requestOutput | Select-String "Request ID:" | ForEach-Object { $_.Line -replace ".*Request ID:\s*", "" }).Trim()

            Write-Host "Access request sent!" -ForegroundColor Green
            Write-Host "`n"
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host
            Write-Host "Request creation skipped."
            return
        }
        else {
            Write-Host "`n" -NoNewLine
            Write-Host "Invalid input. Please enter y or n." -ForegroundColor Red
            Write-Host
        }
    }
}
