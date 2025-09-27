function print_kube_help {
    Clear-Host
    create_header "th kube | k"
    Write-Host "Login to our Kubernetes clusters." -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: " -NoNewline
    Write-Host "th kube [options] | k" -ForegroundColor White
    Write-Host " ╚═ " -NoNewline
    Write-Host "th k" -NoNewline -ForegroundColor White
    Write-Host "           : Open interactive login."
    Write-Host " ╚═ " -NoNewline
    Write-Host "th k <cluster>" -NoNewline -ForegroundColor White
    Write-Host " : Quick kube log-in, Where:"
    Write-Host "    ║" 
    Write-Host "    ╚═ " -NoNewline
    Write-Host "<cluster>" -NoNewline -ForegroundColor White
    Write-Host " is an abbreviated cluster name e.g. dev, cpg etc.."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host " ╚═ " -NoNewline
    ccode "th k dev"
    Write-Host " : logs you into " -NoNewline
    Write-Host "aslive-dev-eks-blue.`n" -ForegroundColor Green
}