function show_available_environments {
    param(
        [string]$service_type,  # aws, kube, db
        [string]$error_title = "Available Environments",
        [string]$env_arg = ""
    )

    $config_file = Join-Path $PSScriptRoot "..\..\..\..\config\th.config.json"
    
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