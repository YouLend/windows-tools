# ========================================================================================================================
#                                                    Functional Helpers
# ========================================================================================================================

function get_th_version {
    $version_cache = "$env:APPDATA\.th_version"
    if (Test-Path $version_cache) {
        Get-Content $version_cache
    } else {
        # First time or cache missing - create it
        $cacheDir = Split-Path $version_cache -Parent
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        
        try {
            $chocoInfo = choco list --local-only th --exact --limit-output
            if ($chocoInfo -match "th\|(.+)") {
                $Matches[1] | Set-Content $version_cache
                Get-Content $version_cache
            } else {
                "unknown" | Set-Content $version_cache
                "unknown"
            }
        } catch {
            "unknown" | Set-Content $version_cache
            "unknown"
        }
    }
}

function load_config {
    param(
        [string]$service_type,  # kube, aws, db
        [string]$env,
        [string]$field,  # cluster, account, role, database, request_role
        [string]$db_type = ""  # optional, only for db service
    )
    
    # Get the th module root directory (go up from functions/helpers to th root)
    $th_root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $config_file = Join-Path $th_root "th\config\th.config.json"
    
    if (-not (Test-Path $config_file)) {
        return ""
    }
    
    try {
        $config = Get-Content $config_file | ConvertFrom-Json
        
        switch ($service_type) {
            "db" {
                if ($db_type) {
                    return $config.db.$db_type.$env.$field
                } else {
                    return ""
                }
            }
            "kube" {
                # If env looks like a cluster name, map it to environment key
                $env_key = $env
                if ($env -match "-eks-") {
                    if ($env -match "usprod") {
                        $env_key = "uprod"
                    } elseif ($env -match "prod") {
                        $env_key = "prod"
                    }
                }
                return $config.kube.$env_key.$field
            }
            "aws" {
                return $config.aws.$env.$field
            }
            default {
                return ""
            }
        }
    } catch {
        return ""
    }
}

function load_request_role {
    param(
        [string]$service_type,
        [string]$env,
        [string]$db_type = ""
    )
    
    load_config $service_type $env "request_role" $db_type
}

function show_available_environments {
    param(
        [string]$service_type,  # aws, kube, db
        [string]$error_title = "Available Environments",
        [string]$env_arg = ""
    )
    
    $script_dir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $config_file = Join-Path $script_dir "config\th.config.json"
    
    Clear-Host
    create_header $error_title
    $available_message = ""
    if ($env_arg) {
        if ($service_type -eq "db") {
            $available_message = "Available database aliases:"
            Write-Host "❌ Invalid environment format: '$env_arg'" -ForegroundColor Red
        } elseif ($service_type -eq "aws") {
            $available_message = "Available account aliases:"
            Write-Host "❌ Account '$env_arg' not found in configuration." -ForegroundColor Red
        } elseif ($service_type -eq "kube") {
            $available_message = "Available cluster aliases:"
            Write-Host "❌ Cluster '$env_arg' not found in configuration." -ForegroundColor Red
        }
        Write-Host ""
    }

    Write-Host $available_message 
    
    if (-not (Test-Path $config_file)) {
        Write-Host "Configuration file not found: $config_file" -ForegroundColor Red
        return
    }
    
    try {
        $config = Get-Content $config_file | ConvertFrom-Json
        
        switch ($service_type) {
            { $_ -in @("aws", "kube") } {
                $field_name = if ($service_type -eq "aws") { "account" } else { "cluster" }
                
                $entries = $config.$service_type.PSObject.Properties
                $maxKeyLen = ($entries | Measure-Object -Property Name -Maximum).Maximum.Length
                Write-Host ""
                foreach ($entry in $entries) {
                    $key = $entry.Name
                    $value = $entry.Value.$field_name
                    Write-Host ("• {0,-$maxKeyLen} : {1}" -f $key, $value) -ForegroundColor White
                }
            }
            "db" {
                # Calculate max key length from both RDS and MongoDB entries
                $allKeyLengths = @()
                if ($config.db.rds) {
                    $config.db.rds.PSObject.Properties | ForEach-Object { $allKeyLengths += ("r-" + $_.Name).Length }
                }
                if ($config.db.mongo) {
                    $config.db.mongo.PSObject.Properties | ForEach-Object { $allKeyLengths += ("m-" + $_.Name).Length }
                }
                $maxKeyLen = ($allKeyLengths | Measure-Object -Maximum).Maximum
                
                # RDS entries
                Write-Host "`nRDS:" -ForegroundColor White
                if ($config.db.rds) {
                    $rdsEntries = $config.db.rds.PSObject.Properties
                    foreach ($entry in $rdsEntries) {
                        $key = "r-" + $entry.Name
                        $value = $entry.Value.database
                        Write-Host ("• {0,-$maxKeyLen} : {1}" -f $key, $value) -ForegroundColor White
                    }
                }
                
                # MongoDB entries  
                Write-Host "`nMongo:" -ForegroundColor White
                if ($config.db.mongo) {
                    $mongoEntries = $config.db.mongo.PSObject.Properties
                    foreach ($entry in $mongoEntries) {
                        $key = "m-" + $entry.Name
                        $value = $entry.Value.database
                        Write-Host ("• {0,-$maxKeyLen} : {1}" -f $key, $value) -ForegroundColor White
                    }
                }
            }
            default {
                Write-Host "Unsupported service type: $service_type" -ForegroundColor Red
                return
            }
        }
    } catch {
        Write-Host "Error reading configuration file: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    return
}

function th_login {
    Clear-Host
    create_header "Login"
    Write-Host "Checking login status..."
    try {
        tsh apps logout *> $null
    } catch {
        Write-Host "TSH connection failed. Cleaning up existing sessions and reauthenticating...`n"
        th_kill
    }

    $status = tsh status 2>$null
    if ($status -match 'Logged in as:') {
        Write-Host "`nAlready logged in to Teleport!" -ForegroundColor White
        Start-Sleep -Milliseconds 500
        return
    }

    Write-Host "`nLogging you into Teleport..."
    
    # Start login in background
    #Start-Process tsh -ArgumentList 'login', '--auth=ad', '--proxy=youlend.teleport.sh:443' -WindowStyle Hidden
    tsh login --user=yl.teleport.test@gmail.com --proxy=youlend.teleport.sh:443

    # Wait up to 15 seconds (30 x 0.5s) for login to complete
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        if (tsh status 2>$null | Select-String -Quiet 'Logged in as:') {
            Write-Host "`nLogged in successfully" -ForegroundColor Green
            return
        }
    }

    Write-Host "`nTimed out waiting for Teleport login."
    return
}

function th_kill {
    Clear-Host
    create_header "Cleanup"
    # Unset AWS environment variables
    Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_CA_BUNDLE -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ACCOUNT -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_DEFAULT_REGION -ErrorAction SilentlyContinue

    Write-Host "Cleaning up Teleport session..." -ForegroundColor White

    # Kill all running processes related to tsh
    Get-NetTCPConnection -State Listen |
        ForEach-Object {
            $tshPid = $_.OwningProcess
            $proc = Get-Process -Id $tshPid -ErrorAction SilentlyContinue
            if ($proc -and $proc.Name -match "tsh") {
                Stop-Process -Id $tshPid -Force
            }
        }
    # Kill PowerShell windows running 'tsh proxy db'
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -like "powershell*" -and $_.CommandLine -match "tsh proxy db"
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force
            Write-Host "Killed PowerShell window running proxy (PID: $($_.ProcessId))"
        }

    tsh logout *>$null
    Write-Host "`nKilled all running tsh proxies"

    # Remove all profile files from temp
    $tempDir = $env:TEMP
    $patterns = @("yl*", "tsh*", "admin_*", "launch_proxy*")
    foreach ($pattern in $patterns) {
        Get-ChildItem -Path (Join-Path $tempDir $pattern) -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Write-Host "Removed all tsh files from /tmp"

    # Remove related lines from PowerShell profile
    if (Test-Path $PROFILE) {
        $profileLines = Get-Content $PROFILE
        $filteredLines = $profileLines | Where-Object {
            $_ -notmatch 'Temp\\yl-.*\.ps1'
        }
        $filteredLines | Set-Content -Path $PROFILE -Encoding UTF8
        Write-Output "Removed all .PROFILE inserts."
    }

    # Log out of all TSH apps
    tsh apps logout 2>$null
    Write-Host "`nLogged out of all apps and proxies.`n" -ForegroundColor Green
}

function find_available_port {
    for ($i = 1; $i -le 100; $i++) {
        $port = Get-Random -Minimum 40000 -Maximum 60000
        $tcpConnection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if (-not $tcpConnection) {
            return $port
        }
    }
    return 50000
}

function load {
    param (
        [ScriptBlock]$Job,
        [string]$Message = "Loading...",
        [object[]]$ArgumentList = @()
    )

    $wrappedJob = {
        param($jobScript, $modulePath, $jobArgs)
        Import-Module $modulePath -Force
        $scriptBlock = [ScriptBlock]::Create($jobScript)
        if ($jobArgs -and $jobArgs.Count -gt 0) {
            & $scriptBlock @jobArgs
        } else {
            & $scriptBlock
        }
    }

    $modulePath = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) + "\th.psm1"
    $jobInstance = Start-Job -ScriptBlock $wrappedJob -ArgumentList $Job.ToString(), $modulePath, $ArgumentList

    try {
        wave_loader -JobId $jobInstance.Id -Message $Message
    }
    finally {
        Wait-Job $jobInstance | Out-Null
        $result = Receive-Job $jobInstance
        Remove-Job $jobInstance | Out-Null
    }
    
    return $result
}