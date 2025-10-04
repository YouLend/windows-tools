# Check for update results and display notification (non-blocking)
function show_update_notification {
    # Read directly from .th/version file
    $versionFile = Join-Path $HOME ".th\version"

    $result = $null

    # Read from version file
    if (Test-Path $versionFile) {
        try {
            $result = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
        } catch {
            # Ignore file read errors
        }
    }

    # Clean up any completed jobs immediately
    Get-Job | Where-Object { $_.State -eq 'Completed' } | Remove-Job -Force -ErrorAction SilentlyContinue

    if ($result) {
        $result = $result.Trim()

        # Parse version file data
        $lines = $result -split "`n"
        $versionData = @{}
        foreach ($line in $lines) {
            if ($line -match "^([^:]+):\s*(.+)$") {
                $versionData[$matches[1]] = $matches[2].Trim()
            }
        }

        # Check if we should show update notification
        if ($versionData.ContainsKey("STATUS") -and $versionData["STATUS"] -eq "SHOW_UPDATE") {
            $currentVersion = $versionData["CURRENT_VERSION"]
            $latestVersion = $versionData["LATEST_VERSION"]

            if ($currentVersion -and $latestVersion) {
                # Get changelog from GitHub API
                $changelog = get_changelog $latestVersion

                create_notification $currentVersion $latestVersion $changelog
            }
        }
    }
}
