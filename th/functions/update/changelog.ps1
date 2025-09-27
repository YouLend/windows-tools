function get_changelog {
    param([string]$version)
    
    $repo = "YouLend/windows-tools"
    
    try {
        # Check if curl is available (Windows usually has Invoke-RestMethod)
        $uri = "https://api.github.com/repos/$repo/releases/tags/th-v$version"
        $response = Invoke-RestMethod -Uri $uri -ErrorAction SilentlyContinue
        
        if ($response -and $response.body) {
            # Extract content after "Summary:" header
            $lines = $response.body -split "`r?`n"
            $inSummary = $false
            $changelog = @()
            
            foreach ($line in $lines) {
                if ($line -match "^#.*Summary") {
                    $inSummary = $true
                    continue
                }
                if ($inSummary) {
                    if ($line -match "^-") {
                        $changelog += $line
                    }
                    if ($changelog.Count -ge 10) {
                        break
                    }
                }
            }
            
            return ($changelog -join "`n")
        } else {
            return "No changelog available for version $version"
        }
    } catch {
        return "Unable to fetch changelog - API unavailable"
    }
}
