function mongo_connect {
    param(
        [string]$cluster,
        [int]$port
    )
    Clear-Host
    create_header "MongoDB"
    Write-Host "How would you like to connect?`n"
    Write-Host "1. Via MongoCLI" -ForegroundColor White
    Write-Host "2. Via AtlasGUI" -ForegroundColor White
    Write-Host "`nSelect option (number): " -NoNewline
    $option = Read-Host
    
    while ($true) {
        switch ($option) {
            "1" {
                mongocli_connect $cluster
                return
            }
            "2" {
                open_atlas $cluster $port
                return
            }
            default {
                Write-Host "`nInvalid selection. Please enter 1 or 2." -ForegroundColor Red
                Write-Host "`nSelect option (number): " -NoNewline
                $option = Read-Host
                continue
            }
        }
    }
}