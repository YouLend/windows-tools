function create_header {
    param (
        [string]$HeaderText,
        [string]$CenterSpaces
    )

    $headerLength = $HeaderText.Length
    $totalDashCount = 52
    $availableDashCount = $totalDashCount - ($headerLength - 5)

    if ($availableDashCount -lt 2) {
        $availableDashCount = 2
    }

    $leftDashes = [math]::Floor($availableDashCount / 2)
    $rightDashes = $availableDashCount - $leftDashes

    $leftDashStr = ('━' * $leftDashes)
    $rightDashStr = ('━' * $rightDashes)

    # Top ruler
    Write-Host ""
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "    ▄███████▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀███████████▀" -ForegroundColor DarkGray

    # Center header line
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "  $leftDashStr " -NoNewLine
    Write-Host "$HeaderText " -NoNewLine -ForegroundColor White
    Write-Host "$rightDashStr" -ForegroundColor White

    # Bottom ruler
    Write-Host "$CenterSpaces" -NoNewline
    Write-Host "▄███████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄███████▀" -ForegroundColor DarkGray
    Write-Host ""
}