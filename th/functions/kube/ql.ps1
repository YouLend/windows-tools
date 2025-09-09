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
            $request_role = load_request_role "kube" $ql_arg
            if (-not [string]::IsNullOrEmpty($request_role)) {
                $status = & tsh status 2>$null
                if ($status -notmatch $request_role) {
                    kube_elevated_login $cluster_name $ql_arg
                }
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