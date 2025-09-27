function print_aws_help {
    #Clear-Host
    create_header "th aws | a"
    Write-Host "Login to our AWS accounts." -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th aws [options] | a" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th a" -NoNewline -ForegroundColor White
    Write-Host "                      : Open interactive login."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th a <account> [opt_args]" -NoNewline -ForegroundColor White
    Write-Host " : Quick aws log-in, Where:"
    Write-Host "    ║"
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<account>" -NoNewline -ForegroundColor White
    Write-Host " is an abbreviated account name e.g." -NoNewLine
    Write-Host " dev, cpg" -NoNewLine -ForegroundColor White
    Write-Host " etc..."
    Write-Host "    ║" 
    Write-Host "    ╚═ " -NoNewline
    Write-Host "[opt_args]" -NoNewline -ForegroundColor White
    Write-Host " takes a combination of s/ss and/or b;" 
    Write-Host "       ║" 
    Write-Host "       ╚═" -NoNewLine
    Write-Host " s/ss" -NoNewLine -ForegroundColor White
    Write-Host " determines whether you login with the sudo or super_sudo "
    Write-Host "       ║  role associated with the account."
    Write-Host "       ╚═" -NoNewLine
    Write-Host " b" -NoNewLine -ForegroundColor White
    Write-Host " opens the browser for the chosen account & role."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev"
    Write-Host "     : logs you into " -NoNewline
    Write-Host "yl-development" -NoNewline -ForegroundColor Green
    Write-Host " as " -NoNewline
    Write-Host "dev" -ForegroundColor Green
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev s"
    Write-Host "   : logs you into " -NoNewline
    Write-Host "yl-development" -NoNewline -ForegroundColor Green
    Write-Host " as " -NoNewline
    Write-Host "sudo_dev" -ForegroundColor Green
    Write-Host " ╚═ " -NoNewline
    ccode "th a dev ssb"
    Write-Host " : Opens the AWS console for " -NoNewLine
    Write-Host "yl-development" -NoNewLine -ForegroundColor Green
    Write-Host " as " -NoNewLine
    Write-Host "super_sudo_dev`n " -NoNewLine -ForegroundColor Green
}