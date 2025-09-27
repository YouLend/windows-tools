function load_config {
    param(
        [string]$service_type,  # kube, aws, db
        [string]$env,
        [string]$field,  # cluster, account, role, database, request_role
        [string]$db_type = ""  # optional, only for db service
    )
    
    $config_file = Join-Path $PSScriptRoot "..\..\..\..\config\th.config.json"
    
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