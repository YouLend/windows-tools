function print_help($Version) {

    $centerSpaces = center_content -ContentWidth 65

    print_logo $Version -CenterSpaces $centerSpaces
    create_header -HeaderText "Usage" -CenterSpaces $centerSpaces

    # Usage commands
    Write-Host "$centerSpaces     ╚═ th aws  [options] | a   : AWS login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th db   [options] | d   : Database login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th kube [options] | k   : Kubernetes login." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th terra          | t   : Quick log-in to yl-admin." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th login          | l   : Simple log in to Teleport" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th clear          | c   : Clean up Teleport session." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th version        | v   : Show the current version." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th config               : Define config preferences." -ForegroundColor White
    

    # Divider line
    Write-Host "$centerSpaces     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Note
    Write-Host "$centerSpaces     For help, and " -NoNewLine
    Write-host "[options] " -ForegroundColor White -NoNewLine 
    Write-Host "info, run " -NoNewLine
    Write-Host "th a/k/d etc.. -h" -ForegroundColor White

    # Docs section
    create_header -HeaderText "Docs" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the documentation pages:"
    Write-Host "$centerSpaces     ╚═ Quickstart:       | th qs" -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ Docs:             | th doc" -ForegroundColor White

    # Extras section
    create_header -HeaderText "Extras" -CenterSpaces $centerSpaces
    Write-Host "$centerSpaces     Run the following commands to access the extra features:"
    Write-Host "$centerSpaces     ╚═ th loader              : Run loader animation." -ForegroundColor White
    Write-Host "$centerSpaces     ╚═ th animate [options]   : Run logo animation." -ForegroundColor White
    Write-Host "$centerSpaces        ╚═ yl" -ForegroundColor White
    Write-Host "$centerSpaces        ╚═ th" -ForegroundColor White

    # Mini decorative footer
    Write-Host "$centerSpaces            ▁▁▁▁▁▁▁▁▁▁▁▁▁  " -ForegroundColor DarkGray -NoNewLine
    Write-Host "▄▄▄ ▄▁▄   "  -ForegroundColor White -NoNewLine
    Write-Host "▁▁▁▁▁▁▁▁▁▁▁▁▁▁" -ForegroundColor DarkGray
    Write-Host "$centerSpaces           ▔▔▔▔▔▔▔▔▔▔▔▔▔▔" -ForegroundColor DarkGray -NoNewLine
    Write-Host "   ▀  ▀▔▀   " -ForegroundColor White -NoNewLine
    Write-Host "▔▔▔▔▔▔▔▔▔▔▔▔▔" -ForegroundColor DarkGray -NoNewLine
}