function get_th_version {
    $versionFile = Join-Path $HOME ".th\version"

    if (Test-Path $versionFile) {
        try {
            $cacheContent = Get-Content $versionFile -Raw
            $lines = $cacheContent -split "`n"
            foreach ($line in $lines) {
                if ($line -match "^CURRENT_VERSION:(.+)$") {
                    return $matches[1].Trim()
                }
            }
        } catch {
            # Return null if can't read
        }
    }
    return $null
}
