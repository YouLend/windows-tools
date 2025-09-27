function print_logo($Version, $CenterSpaces) {
    Write-Host ""
    
    Write-Host "$CenterSpaces                 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁" -ForegroundColor Gray
    Write-Host "$CenterSpaces                ▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏" -ForegroundColor Gray
    Write-Host "$CenterSpaces               ▕░░░░░░░░░░░ " -NoNewline; Write-Host "████████╗ ██╗  ██╗" -ForegroundColor White -NoNewline; Write-Host " ░░░░░░░░░░░░░▏" -ForegroundColor Gray
    Write-Host "$CenterSpaces              ▕▒▒▒▒▒▒▒▒▒▒▒ " -NoNewline; Write-Host "╚══██╔══╝ ██║  ██║" -ForegroundColor White -NoNewline; Write-Host " ▒▒▒▒▒▒▒▒▒▒▒▒▒▏" 
    Write-Host "$CenterSpaces             ▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓ " -NoNewline; Write-Host "█▉║    ███████║" -ForegroundColor White -NoNewline; Write-Host " ▓▓▓▓▓▓▓▓▓▓▓▓▓▏" 
    Write-Host "$CenterSpaces            ▕██████████████ " -NoNewline; Write-Host "█▉║    ██╔══██║" -ForegroundColor White -NoNewline; Write-Host " █████████████▏"
    Write-Host "$CenterSpaces           ▕██████████████ " -NoNewline; Write-Host "██║    ██║  ██║" -ForegroundColor White -NoNewline; Write-Host " █████████████▏" 
    Write-Host "$CenterSpaces          ▕██████████████ " -NoNewline; Write-Host "██╝    ██╝  ██╝" -ForegroundColor White -NoNewline; Write-Host " █████████████▏" 
    Write-Host "$CenterSpaces         ▕██████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█████████████▏" 
    Write-Host "$CenterSpaces          ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
    Write-Host "$CenterSpaces         ■■■■■■■■■" -NoNewline -ForegroundColor DarkGray; Write-Host " Teleport Helper - v$Version " -ForegroundColor White -NoNewline; Write-Host "■■■■■■■■■" -ForegroundColor DarkGray
}