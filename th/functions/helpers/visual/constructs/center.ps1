function center_content {
    param([int]$ContentWidth = 65)
    
    # Get terminal width and calculate centering
    $termWidth = $Host.UI.RawUI.WindowSize.Width
    $padding = [math]::Floor(($termWidth - $ContentWidth) / 2)
    
    # Create padding string
    return ' ' * [math]::Max(0, $padding)
}