function print_config_help {
    Clear-Host
    create_header "th config"
    Write-Host "Manage & define configuration preferences" -ForegroundColor White
    Write-Host "`nUsage: " -NoNewLine
    Write-Host "th config [options]" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th config" -NoNewline -ForegroundColor White
    Write-Host "               : Display current configuration settings."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th config <key> <value>" -NoNewline -ForegroundColor White
    Write-Host " : Set a given configuration value."
    Write-Host "`nAvailable [options]:" -ForegroundColor White
    Write-Host "• timeout <minutes> " -NoNewLine -ForegroundColor White
    Write-Host "- Set inactivity timeout in minutes" -ForegroundColor Gray
    Write-Host "• update <hours> " -NoNewLine -ForegroundColor White
    Write-Host "   - Set update notification suppression in hours" -ForegroundColor Gray
    Write-Host "`nExamples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th config timeout 120"
    Write-Host " : Sets inactivity timeout to " -NoNewLine
    Write-Host "120 minutes`n " -NoNewLine -ForegroundColor Green
}