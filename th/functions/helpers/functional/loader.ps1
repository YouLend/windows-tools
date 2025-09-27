function load {
    param (
        [ScriptBlock]$Job,
        [string]$Message = "Loading...",
        [object[]]$ArgumentList = @()
    )

    $wrappedJob = {
        param($jobScript, $modulePath, $jobArgs)
        Import-Module $modulePath -Force
        $scriptBlock = [ScriptBlock]::Create($jobScript)
        if ($jobArgs -and $jobArgs.Count -gt 0) {
            & $scriptBlock @jobArgs
        } else {
            & $scriptBlock
        }
    }

    $modulePath = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) + "\th.psm1"
    $jobInstance = Start-Job -ScriptBlock $wrappedJob -ArgumentList $Job.ToString(), $modulePath, $ArgumentList

    try {
        wave_loader -JobId $jobInstance.Id -Message $Message
    }
    finally {
        Wait-Job $jobInstance | Out-Null
        $result = Receive-Job $jobInstance
        Remove-Job $jobInstance | Out-Null
    }
    
    return $result
}