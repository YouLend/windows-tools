function open_dbeaver {
    param(
        [string]$cluster,
        [string]$db_user,
        [string]$port
    )


    Clear-Host
    create_header "DBeaver"
    
    Write-Host "Connecting to " -NoNewline -ForegroundColor White
    Write-Host $cluster -ForegroundColor Green -NoNewline
    Write-Host "..."
    
    create_db_proxy $cluster  $port "tf_teleport_rds_read_user" "postgres" 
    Start-Sleep 1

    Clear-Host
    create_header "DBeaver"
    Write-Host "1. Once DBeaver opens, click create a new connection in the very top left."
    Write-Host "2. Select " -NoNewLine
    Write-Host "PostgreSQL " -NoNewLine -ForegroundColor White
    Write-Host "as the database type." 
    Write-Host "3. Use the following connection details:"
    Write-Host " - Host:      localhost" -ForegroundColor White
    Write-Host " - Port:      $port" -ForegroundColor White
    Write-Host " - Database:  postgres" -ForegroundColor White
    Write-Host " - User:      $db_user" -ForegroundColor White
    Write-Host " - Password:  (leave blank)" -ForegroundColor White
    Write-Host " - Select 'Show all databases' ☑️" -ForegroundColor White
    Write-Host "5. Click " -NoNewLine
    Write-Host "Test Connection " -NoNewLine -ForegroundColor White
    Write-Host "to ensure everything is set up correctly."
    Write-Host "6. If the test is successful, click " -NoNewLine
    Write-Host "Finish " -NoNewLine -ForegroundColor White
    Write-Host "to save the connection.`n"
    Start-Sleep 1
    
    # Check if DBeaver is already running
    $dbeaverProcess = Get-Process -Name "dbeaver" -ErrorAction SilentlyContinue

    if ($dbeaverProcess) {
        # Bring DBeaver window to front
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class Win32 {
                [DllImport("user32.dll")]
                public static extern bool SetForegroundWindow(IntPtr hWnd);
                [DllImport("user32.dll")]
                public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            }
"@

        $mainWindowHandle = $dbeaverProcess[0].MainWindowHandle
        if ($mainWindowHandle -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($mainWindowHandle, 9) | Out-Null  # 9 = SW_RESTORE
            [Win32]::SetForegroundWindow($mainWindowHandle) | Out-Null
        }
    } else {
        try {
            Write-Host "Starting DBeaver...`n"
            Start-Process "dbeaver"
        } catch {
            Write-Host "`n❌ Could not open DBeaver. Please ensure it is installed and accessible from PATH." -ForegroundColor Red
        }
    }
}