function kube_login {
    param(
        [string]$env_arg
    )
    
    th_login

    # Direct login if environment argument provided
    if (-not [string]::IsNullOrEmpty($env_arg)) { 
        kube_quick_login $env_arg
        return
    }

    Clear-Host
    create_header "Available Clusters"
    
    $result = load -Job { check_cluster_access } -Message "Checking cluster access..."
    $cluster_lines = $result.cluster_lines
    $full_names = $result.full_names
    $login_status = $result.login_status

    for ($i = 0; $i -lt $cluster_lines.Count; $i++) {
        $line = $cluster_lines[$i]
        $status = if ($i -lt $login_status.Count) { $login_status[$i] } else { "n/a" }

        switch ($status) {
            "ok" {
                Write-Host ("{0,2}. {1}" -f ($i + 1), $line)
            }
            "fail" {
                Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor DarkGray
            }
            default {
                Write-Host ("{0,2}. {1}" -f ($i + 1), $line)
            }
        }
    }

    Write-Host "`nSelect cluster (number): " -NoNewline -ForegroundColor White
    $choice = Read-Host

    if ([string]::IsNullOrEmpty($choice)) {
        Write-Host "No selection made. Exiting."
        return
    }

    $selected_index = [int]$choice - 1
    if ($selected_index -lt 0 -or $selected_index -ge $cluster_lines.Count) {
        Write-Host "`nInvalid selection" -ForegroundColor Red
        return
    }

    $selected_cluster = $full_names[$selected_index]
    $selected_cluster_status = if ($selected_index -lt $login_status.Count) { $login_status[$selected_index] } else { "n/a" }

    if ($selected_cluster_status -eq "fail") {
        kube_elevated_login $selected_cluster
    }

    Clear-Host
    create_header "Kube Login"
    Write-Host "Logging you into: " -NoNewline -ForegroundColor White
    Write-Host $selected_cluster -ForegroundColor Green
    & tsh kube login $selected_cluster > $null 2>&1
    Write-Host "`nLogged in successfully!" -ForegroundColor White
    Write-Host ""
}