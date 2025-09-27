function demo_wave_loader {
    param([string]$Message = "Demo Wave Loader")
    
    # Create a dummy background process that runs for a very long time
    $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-Command", "Start-Sleep -Seconds 99999" -PassThru -WindowStyle Hidden
    
    # Set up cleanup
    $cleanup = {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        } catch {}
        Write-Host "`e[?25h`n"
        exit 0
    }
    Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null
    
    Clear-Host
    Write-Host "`nPress Ctrl+C to exit (Spam it, if it doesn't work first time!)`n`n"
    
    try {
        # Run the wave loader with the dummy process
        wave_loader -Pid $proc.Id -Message $Message
    }
    finally {
        if (!$proc.HasExited) {
            $proc.Kill()
        }
    }
}
