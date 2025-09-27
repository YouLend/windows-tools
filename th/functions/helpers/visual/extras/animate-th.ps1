function animate_th {
    $centerSpaces = center_content
    $version = "1.3.7"
    
    Clear-Host
    Write-Host "`e[?25l" -NoNewline  # Hide cursor
    
    Write-Host "`n`e[1mTeleport Helper - Press Enter to continue...`e[0m`n"
    
    # Create a flag file for key detection
    $flagFile = "$env:TEMP\animate_stop_$PID"
    if (Test-Path $flagFile) { Remove-Item $flagFile -Force }
    
    # Smoother shimmer with more color steps
    $colors = @(232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234, 233)
    $frame = 0
    
    # Start background job to monitor for Enter key
    $keyJob = Start-Job -ScriptBlock {
        param($flagFile)
        $null = Read-Host
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    } -ArgumentList $flagFile
    
    # Save cursor position and clear screen properly
    Write-Host "`e[s`e[2J`e[H" -NoNewline
    
    # Animation sequence - infinite loop
    while ($true) {
        # Check if flag file exists (Enter was pressed)
        if (Test-Path $flagFile) {
            Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
            break
        }
        
        # Move cursor to home without clearing (smoother)
        Write-Host "`e[H" -NoNewline
        
        # Bottom to top shimmer wave
        $line1_color = $colors[($frame + 0) % $colors.Count]
        $line2_color = $colors[($frame + 1) % $colors.Count]
        $line3_color = $colors[($frame + 2) % $colors.Count]
        $line4_color = $colors[($frame + 3) % $colors.Count]
        $line5_color = $colors[($frame + 4) % $colors.Count]
        $line6_color = $colors[($frame + 5) % $colors.Count]
        $line7_color = $colors[($frame + 6) % $colors.Count]
        $line8_color = $colors[($frame + 7) % $colors.Count]
        $line9_color = $colors[($frame + 8) % $colors.Count]
        $line10_color = $colors[($frame + 9) % $colors.Count]
        $line11_color = $colors[($frame + 10) % $colors.Count]
        
        Write-Host "$centerSpaces        `e[38;5;${line11_color}m ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁`e[0m"
        Write-Host "$centerSpaces        `e[38;5;${line10_color}m▕░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces       `e[38;5;${line9_color}m▕░░░░░░░░░░░░░░░░░ `e[1;97m███████████╗ ███╗  ███╗`e[38;5;${line9_color}m ░░░░░░░░░░░░░░░░░░░░▏`e[0m"
        Write-Host "$centerSpaces      `e[38;5;${line8_color}m▕▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ `e[1;97m╚══███╔══╝  ███║  ███║`e[38;5;${line8_color}m ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▏`e[0m"
        Write-Host "$centerSpaces     `e[38;5;${line7_color}m▕▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ `e[1;97m███║     █████████║`e[38;5;${line7_color}m ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▏`e[0m"
        Write-Host "$centerSpaces    `e[38;5;${line6_color}m▕█████████████████████ `e[1;97m███║     ███╔══███║`e[38;5;${line6_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces   `e[38;5;${line5_color}m▕█████████████████████ `e[1;97m███║     ███║  ███║`e[38;5;${line5_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces  `e[38;5;${line4_color}m▕█████████████████████ `e[1;97m███╝     ███╝  ███╝`e[38;5;${line4_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces `e[38;5;${line4_color}m▕█████████████████████ `e[1;97m███╝     ███╝  ███╝`e[38;5;${line4_color}m ████████████████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line3_color}m▕█████████████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄████████████████████▏`e[0m"
        Write-Host "$centerSpaces`e[38;5;${line2_color}m ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔`e[0m"
        Write-Host ""
        
        $frame++
        Start-Sleep -Milliseconds 80
    }
    
    # Clean up background job
    Stop-Job $keyJob -ErrorAction SilentlyContinue
    Remove-Job $keyJob -Force -ErrorAction SilentlyContinue
    
    Write-Host "`e[?25h" -NoNewline  # Show cursor
    Write-Host "`n`e[1;32m✓ Ready!`e[0m`n"
}