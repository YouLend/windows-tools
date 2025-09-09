function db_login {
    param(
        [string[]]$Arguments
    )
    
    th_login

    if ($Arguments -and $Arguments.Count -gt 0) {
        if ($Arguments.Count -eq 1) {
            db_quick_login $Arguments[0]
        } else {
            db_quick_login $Arguments[0] $Arguments[1..($Arguments.Count-1)]
        }
        return
    }

    Clear-Host
    create_header "DB"
    Write-Host "Which database would you like to connect to?`n"
    Write-Host "1. RDS" -ForegroundColor White
    Write-Host "2. MongoDB" -ForegroundColor White
    
    $db_type = ""
    $selected_db = ""
    
    while ($true) {
        Write-Host "`nSelect option (number): " -NoNewline
        $db_choice = Read-Host
        
        switch ($db_choice) {
            "1" {
                Write-Host "`nRDS selected." -ForegroundColor White
                $db_type = "rds"

                Clear-Host
                create_header "Available Databases"
                
                $result = load -Job { check_rds_login } -Message "Checking rds access..."
                $db_lines = $result.db_lines
                $login_status = $result.login_status

                for ($i = 0; $i -lt $db_lines.Count; $i++) {
                    $line = $db_lines[$i]
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

                Write-Host ""
                Write-Host "Select database (number): " -NoNewline -ForegroundColor White
                $db_choice = Read-Host
                
                if ([string]::IsNullOrEmpty($db_choice)) {
                    Write-Host "No selection made. Exiting."
                    return
                }

                $selected_index = [int]$db_choice - 1
                
                if ([int]$db_choice -gt 0 -and [int]$db_choice -le $db_lines.Count) {
                    $selected_db = $db_lines[$selected_index]
                    
                    # Check if the selected database has failed login status
                    $selected_status = if ($selected_index -lt $login_status.Count) { $login_status[$selected_index] } else { "n/a" }
                    if ($selected_status -eq "fail") {
                        db_elevated_login "sudo_teleport_rds_read_role" $selected_db
                    }
                } else {
                    Write-Host "`nInvalid selection" -ForegroundColor Red
                    return
                }
                break
            }
            "2" {
                Write-Host "`nMongoDB selected." -ForegroundColor White
                $db_type = "mongo"

                Clear-Host
                create_header "Available Databases"

                $result = load -Job { check_atlas_access } -Message "Checking MongoDB access..."
                $has_atlas_access = $result.has_atlas_access
                $json_output = $result.json_output

                $parsed_json = $json_output | ConvertFrom-Json

                $filtered_dbs = $parsed_json | Where-Object { $_.metadata.labels.db_type -ne "rds" }

                # Display databases with color coding based on access
                for ($i = 0; $i -lt $filtered_dbs.Count; $i++) {
                    $db_name = $filtered_dbs[$i].metadata.name
                    Write-Host ("{0,2}. " -f ($i + 1)) -NoNewline
                    if ($has_atlas_access -eq "true") {
                        Write-Host $db_name
                    } else {
                        Write-Host $db_name -ForegroundColor DarkGray
                    }
                }

                # Prompt for selection
                Write-Host "`nSelect database (number): " -NoNewline -ForegroundColor White
                $db_choice = Read-Host

                if ([string]::IsNullOrEmpty($db_choice)) {
                    Write-Host "No selection made. Exiting."
                    return
                }

                $selected_index = [int]$db_choice - 1
                
                if ([int]$db_choice -gt 0 -and [int]$db_choice -le $filtered_dbs.Count) {
                    $selected_db = $filtered_dbs[$selected_index].metadata.name
                    
                    # If user doesn't have atlas access, trigger elevated login
                    if ($has_atlas_access -ne "true") {
                        db_elevated_login "atlas-read-only" $selected_db
                    }
                } else {
                    Write-Host "`nInvalid selection" -ForegroundColor Red
                    return
                }
                break
            }
            default {
                Write-Host "`nInvalid selection" -ForegroundColor Red
            }
        }
        break
    }

    if ($global:exit_db -eq $true) {
        $global:exit_db = $false
        return
    }

    Write-Host "`n$selected_db" -NoNewLine -ForegroundColor Green
    Write-Host " selected."     
    Start-Sleep 1

    if ([string]::IsNullOrEmpty($port)) { 
        $port = find_available_port 
    }

    # Connect to the appropriate database type
    if ($db_type -eq "rds") {
        rds_connect $selected_db $port
        return
    }
    mongo_connect $selected_db $port
    return
}