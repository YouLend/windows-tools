function kube_quick_login {
    param(
        [string]$ql_arg
    )

    $cluster_name = load_config "kube" $ql_arg "cluster"
    
    if ([string]::IsNullOrEmpty($cluster_name)) {
        show_available_environments "kube" "Kube Login Error" $ql_arg
        return
    }

    # Check for privileged environments requiring elevated access
    switch ($ql_arg) {
        { $_ -in @("prod", "uprod") } {
            $loginResult = & tsh kube login $cluster_name 2>&1
            if ($LASTEXITCODE -eq 0) {
                $authResult = & kubectl auth can-i create pod 2>&1
                if ($LASTEXITCODE -ne 0) {
                    kube_elevated_login $cluster_name
                }
            } else {
                Write-Host "`n❌ Cluster not found. Please contact your Teleport admin." -ForegroundColor Red
                return
            }
        }
    }

    Clear-Host
    create_header "Kube Login"
    
    Write-Host "Logging you into: " -NoNewline
    Write-Host $cluster_name -ForegroundColor Green

    & tsh kube login $cluster_name > $null 2>&1
    
    Write-Host "`nLogged in successfully!"
    Write-Host ""
}