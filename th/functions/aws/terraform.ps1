function terraform_login {
    th_login     
    Clear-Host
    create_header "Terragrunt Login"
    & tsh apps logout > $null 2>&1
    Write-Host "Logging into " -NoNewline -ForegroundColor White
    Write-Host "yl-admin" -ForegroundColor Green -NoNewline
    Write-Host " as " -NoNewline -ForegroundColor White  
    Write-Host "sudo_admin" -ForegroundColor Green
    & tsh apps login "yl-admin" --aws-role "sudo_admin" > $null 2>&1
    create_proxy "yl-admin" "sudo_admin"
}