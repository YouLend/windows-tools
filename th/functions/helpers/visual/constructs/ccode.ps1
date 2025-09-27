function ccode {
    param([string]$text)
    
    Write-Host "" -ForegroundColor White -NoNewLine
    Write-Host "$text" -NoNewline -BackgroundColor White -ForegroundColor Black
    Write-Host "" -ForegroundColor White -NoNewLine
}