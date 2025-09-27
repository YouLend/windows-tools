function wave_loader {
    param (
        [int]$JobId,
        [int]$Pid,
        [string]$Message = "Loading..."
    )


    $headerWidth = 65
    $waveLen = $headerWidth
    $blocks = @("▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
    $pos = 0
    $direction = 1

    $msgLen = $Message.Length
    $msgWithSpacesLen = $msgLen + 2
    $msgStart = [math]::Floor(($waveLen - $msgWithSpacesLen) / 2)
    $msgEnd = $msgStart + $msgWithSpacesLen

    try {
        while (($JobId -and (Get-Job -Id $JobId -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Running' })) -or ($Pid -and (Get-Process -Id $Pid -ErrorAction SilentlyContinue))) {
            $line = ""
            for ($i = 0; $i -lt $waveLen; $i++) {
                if ($i -eq $pos) {
                    $center = [math]::Floor($waveLen / 2)
                    $distance = [math]::Abs($pos - $center)
                    $maxDist = [math]::Floor($waveLen / 2)
                    $boost = 7 - [math]::Floor($distance * 7 / $maxDist)
                    if ($boost -lt 0) { $boost = 0 }
                    $line += "$($blocks[$boost])"
                }
                elseif ($i -ge $msgStart -and $i -lt $msgEnd) {
                    $charIdx = $i - $msgStart
                    if ($charIdx -eq 0 -or $charIdx -eq ($msgWithSpacesLen - 1)) {
                        $line += " "
                    }
                    else {
                        $msgCharIdx = $charIdx - 1
                        $line += $Message[$msgCharIdx]
                    }
                }
                else {
                    $line += " "
                }
            }

            Write-Host "`r$line" -NoNewline

            $pos += $direction
            if ($pos -lt 0 -or $pos -ge $waveLen) {
                $direction *= -1
                $pos += $direction
            }

            $center = [math]::Floor($waveLen / 2)
            $distance = [math]::Abs($pos - $center)
            $maxDist = [math]::Floor($waveLen / 2)

            # Speed adjustment
            if ($distance -gt $maxDist * 0.9) {
                Start-Sleep -Milliseconds 30
            }
            elseif ($distance -gt $maxDist * 0.8) {
                Start-Sleep -Milliseconds 20
            }
            elseif ($distance -gt $maxDist * 0.75) {
                Start-Sleep -Milliseconds 10
            }
            elseif ($distance -gt $maxDist / 2) {
                Start-Sleep -Milliseconds 5
            }
            else {
                Start-Sleep -Milliseconds 5
            }
        }
    }
    finally {
        # Clear the entire line and move cursor to beginning
        Write-Host "`r$(' ' * 80)`r" -NoNewline
    }
}