function print_db_help {
    Clear-Host
    create_header "th database | d"
    Write-Host "Connect to our databases (RDS and MongoDB)" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th database [options] | d" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th d" -NoNewline -ForegroundColor White
    Write-Host "                 : Open interactive database selection."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th d <db-env> <port>" -NoNewline -ForegroundColor White
    Write-Host " : Quick database connect, Where:"
    Write-Host "    ║"
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<db-env>" -NoNewline -ForegroundColor White
    Write-Host "   is an abbreviation for a database, using the format:" -NoNewLine
    Write-Host " dbtype-env" -ForegroundColor White
    Write-Host "    ║             e.g. " -NoNewline
    Write-Host "r-dev" -NoNewline -ForegroundColor White
    Write-Host " would connect to the " -NoNewline
    Write-Host "dev, RDS cluster." -ForegroundColor White
    Write-Host "    ╚═ " -NoNewline
    Write-Host "[opt_args]" -NoNewline -ForegroundColor White
    Write-Host " either a port number or 'c', depending on connection method:"
    Write-Host "        ║"
    Write-Host "        ╚═ " -NoNewline
    Write-Host "[port]" -NoNewLine -ForegroundColor White
    Write-Host " an integer, 10000-50000. Useful for connection re-use in GUI's."
    Write-Host "        ║"
    Write-Host "        ╚═ " -NoNewline
    Write-Host "[c]" -NoNewline -ForegroundColor White
    Write-Host " connects via CLI (psql or mongosh)." 
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th d r-dev"
    Write-Host "        : connects to " -NoNewline
    Write-Host "db-dev-aurora-postgres-1" -ForegroundColor Green -NoNewLine
    Write-Host "."
    Write-Host " ╚═ " -NoNewline
    ccode "th d m-prod c"
    Write-Host "     : connects to " -NoNewline
    Write-Host "mongodb-YLProd-Cluster-1" -ForegroundColor Green -NoNewLine
    Write-Host " via " -NoNewline
    Write-Host "mongosh" -ForegroundColor Green -NoNewLine
    Write-Host "."
    Write-Host " ╚═ " -NoNewline
    ccode "th d m-prod 43000"
    Write-Host " : Opens " -NoNewline
    Write-Host "mongodb-YLProd-Cluster-1" -NoNewline -ForegroundColor Green
    Write-Host " in " -NoNewline
    Write-Host "MongoDB Compass" -ForegroundColor Green -NoNewLine
    Write-Host " on port " -NoNewline
    Write-Host "43000" -ForegroundColor Green -NoNewLine
    Write-Host ".`n"
}