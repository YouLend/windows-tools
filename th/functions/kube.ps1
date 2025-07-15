# ============================================================
# ======================= Kubernetes =========================
# ============================================================
# th kube handler function 
function tkube {
    param (
        [string[]]$Args
    )

    if ($Args.Count -eq 0) {
        tkube_interactive_login
        return
    }

    switch ($Args[0]) {
        "-l" {
        tsh kube ls -f text
        }
        "-s" {
        tsh sessions ls --kind=kube 
        }
        "-e" {
        $restArgs = $Args[1..($Args.Length - 1)]
        tsh kube exec @restArgs
        }
        "-j" {
        $restArgs = $Args[1..($Args.Length - 1)]
        tsh kube join @restArgs
        }
        default {
        Write-Output "Usage:"
        Write-Output "`t-l : List all Kubernetes clusters"
        Write-Output "`t-s : List all current sessions"
        Write-Output "`t-e : Execute a command"
        Write-Output "`t-j : Join a session"
        }
    }
}

function kube_login {
    if ($env:reauth_kube -eq "TRUE") {
        Write-Host "`nRe-Authenticating`n" -ForegroundColor White
        tsh logout
        tsh login --auth=ad --proxy=youlend.teleport.sh:443 --request-id="$env:REQUEST_ID" *> $null
        $env:reauth_kube = "FALSE"
    }
    else {
        th_login
    }

    $output = tsh kube ls --format=json | ConvertFrom-Json
    $clusters = $output | ForEach-Object { $_.kube_cluster_name } | Where-Object { $_ }

    if (-not $clusters) {
        Write-Host "No Kubernetes clusters available." -ForegroundColor Red
        return 1
    }

    Write-Host "`nAvailable Clusters:`n" -ForegroundColor White

    $clusterLines = @()
    $loginStatus = @()

    for ($i = 0; $i -lt $clusters.Count; $i++) {
        $clusterName = $clusters[$i]
        $clusterLines += $clusterName

        if ($clusterName -like "*prod*") {
            try {
                tsh kube login $clusterName *>$null

                $canCreate = kubectl auth can-i create pod 2>$null
                if ($canCreate -eq "yes") {
                    $loginStatus += "ok"
                } else {
                    $loginStatus += "fail"
                }
            } catch {
                $loginStatus += "fail"
            }
        } else {
            $loginStatus += "n/a"
        }
    }

    for ($i = 0; $i -lt $clusterLines.Count; $i++) {
        $line = $clusterLines[$i]
        $status = $loginStatus[$i]

        switch ($status) {
            "ok"   { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor White}
            "fail" { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor Gray}
            "n/a"  { Write-Host ("{0,2}. {1}" -f ($i + 1), $line) -ForegroundColor White}
        }
    }

    Write-Host "`nSelect cluster (number): " -NoNewLine
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
        Write-Host
        tsh kube login $selectedCluster
    } else {
        Write-Host "`nLogging you into: " -NoNewLine
        Write-Host $selectedCluster -ForegroundColor Green
        tsh kube login $selectedCluster
    }
}

function kube_elevated_login($cluster) {
    while ($true) {
        Clear-Host
        Write-Host "`n==================== Privileged Access =====================" -ForegroundColor White
        Write-Host
        Write-Host "You don't have admin access to " -NoNewLine
        Write-Host "$cluster." -ForegroundColor White
        Write-Host "`nWould you like to raise a request? (y/n): " -ForegroundColor White -NoNewLine
        $elevated = Read-Host
        
        if ($elevated -match '^[Yy]$') {
            # Placeholder: Add checks for new Kubernetes roles here if needed
            Write-Host "`nEnter your reason for request: " -ForegroundColor White -NoNewLine
            $reason = Read-Host

            Write-Host "`nAccess request sent for: " -ForegroundColor White -NoNewLine
            Write-Host "production-eks-clusters" -ForegroundColor Green

            $rawOutputLines = @()
            tsh request create --roles production-eks-clusters --reason "$reason" |
                Tee-Object -Variable rawOutputLines |
                ForEach-Object { Write-Host $_ }

            # Join the lines back into a single string (for parsing)
            $rawOutput = $rawOutputLines -join "`n"

            # Extract the Request ID
            $env:REQUEST_ID = ($rawOutput -split "`n" | Where-Object { $_ -match '^Request ID' }) -replace 'Request ID:\s*', '' | ForEach-Object { $_.Trim() }
            $env:reauth_kube = "true"
            return
        }
        elseif ($elevated -match '^[Nn]$') {
            Write-Host
            Write-Host "Request creation skipped."
            return
        }
        else {
            Write-Host "Invalid input. Please enter Y or N."
        }
    }
}

