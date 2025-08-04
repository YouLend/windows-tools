# Load all function files
$moduleRoot = $PSScriptRoot
$version = "1.4.7"
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
	Clear-Host
    switch ($Command) {
		{ $_ -in @("kube", "k") } {
			if ($SubArgs[0] -eq "-h") {
			Write-Output "Interactive login for our K8s Clusters."
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
		{ $_ -in @("loader") } {
			demo_wave_loader
		}
		default {
			print_help $version
		}
    }
}
