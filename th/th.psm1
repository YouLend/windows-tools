# Load all function files
$moduleRoot = $PSScriptRoot

Get-ChildItem -Path "$moduleRoot/functions" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

function th {
    $Command = $args[0]
	if ($args.Count -gt 1) {
		$SubArgs = $args[1..($args.Count - 1)]
	} else {
		$SubArgs = @()
	}
    switch ($Command) {
		{ $_ -in @("kube", "k") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Interactive login for our K8s Clusters."
			#Write-Output "-l : List all Kubernetes clusters"
			#Write-Output "-s : List all current sessions"
			#Write-Output "-e : Execute a command"
			#Write-Output "-j : Join a session"
			} else {
			kube_login @SubArgs
			}
		}
		{ $_ -in @("terra", "t") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Logs into yl-admin as sudo-admin"
			} else {
			terraform_login @SubArgs
			}
		}
		{ $_ -in @("aws", "a") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Interactive login for our AWS accounts."
			} else {
			aws_login @SubArgs
			}
		}
		{ $_ -in @("db", "d") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Usage:"
			Write-Output "-l : List all accounts"
			} else {
			db_login @SubArgs
			}
		}
		{ $_ -in @("logout", "l") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Logout from all proxies."
			} else {
			th_kill
			}
		}
		{ $_ -in @("login") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Simple log in to Teleport."
			} else {
			tsh login --auth=ad --proxy=youlend.teleport.sh:443
			}
		}
		# ========== temp
		{ $_ -in @("kill", "kl") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Logout from all proxies."
			} else {
				Get-NetTCPConnection -State Listen |
					ForEach-Object {
						$tshPid = $_.OwningProcess
						$proc = Get-Process -Id $tshPid -ErrorAction SilentlyContinue
						if ($proc -and $proc.Name -match "tsh") {
							Stop-Process -Id $tshPid -Force
						}
					}
				# Kill PowerShell windows running 'tsh proxy db'
				Get-CimInstance Win32_Process |
					Where-Object {
						$_.Name -like "powershell*" -and $_.CommandLine -match "tsh proxy db"
					} |
					ForEach-Object {
						Stop-Process -Id $_.ProcessId -Force
						Write-Host "Killed PowerShell window running proxy (PID: $($_.ProcessId))"
					}
			}
		}
		# ========== temp
		default {
			Write-Host "`nUsage:" -ForegroundColor White
			Write-Output "`nth kube   | k : Kubernetes login options"
			Write-Output "th aws    | a : AWS login options"
			Write-Output "th terra  | t : Log into yl-admin as sudo-admin"
			Write-Output "th db     | d : Log into yl-admin as sudo-admin"
			Write-Output "th logout | l : Logout from all proxies"
			Write-Output "th login      : Simple login to Teleport"
			Write-Output "--------------------------------------------------------------------------"
			Write-Output "For specific instructions on any of the above, run: th <option> -h"
			Write-Host "`nPages:" -ForegroundColor White
			Write-Host "`nQuickstart: " -ForegroundColor White -NoNewLine
			Write-Host "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start" -ForegroundColor Blue
			Write-Host "Docs: " -ForegroundColor White -NoNewLine
			Write-Host "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs" -ForegroundColor Blue
			Write-Host "`n--> (Hold CRTL + Click to open links)`n" -ForegroundColor White
		}
    }
}
