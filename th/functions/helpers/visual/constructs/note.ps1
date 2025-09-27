function create_note {
    param (
        [string]$NoteText
    )
    # Print note with ANSI-style formatting using ForegroundColor
    Write-Host "`n▄██▀ $NoteText`n" -ForegroundColor DarkGray
}