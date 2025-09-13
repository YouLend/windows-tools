# Load all function files
$moduleRoot = $PSScriptRoot

Get-ChildItem -Path "$moduleRoot/functions" -Filter *.ps1 -Recurse | ForEach-Object {
    . $_.FullName
}

function th {
	$Command = $args[0]
    if ($args.Count -gt 1) {
		$SubArgs = @($args[1..($args.Count - 1)])
	} else {
		$SubArgs = @()
	}
	
	# Start background update check for interactive commands
	$updateCacheFile = ""
	switch ($Command) {
		{ $_ -in @("kube", "k", "aws", "a", "database", "d", "db", "terra", "t") } {
			$updateCacheFile = check_th_updates_background
		}
	}
	
    # Don't clear host immediately - let command run first, then check for updates
    switch ($Command) {
		{ $_ -in @("kube", "k") } {
			if ($SubArgs[0] -eq "-h") {
				print_kube_help
			} else {
				kube_login @SubArgs
				if ($updateCacheFile) {
					show_update_notification $updateCacheFile
				}
			}
		}
		{ $_ -in @("terra", "t") } {
			if ($SubArgs[0] -eq "-h") {
				Write-Output "Logs into yl-admin as sudo-admin"
			} else {
				terraform_login @SubArgs
				if ($updateCacheFile) {
					show_update_notification $updateCacheFile
				}
			}
		}
		{ $_ -in @("aws", "a") } {
			if ($SubArgs[0] -eq "-h") {
				print_aws_help
			} else {
				aws_login -Arguments $SubArgs			
				if ($updateCacheFile) {
					show_update_notification $updateCacheFile
				}
			}
		}
		{ $_ -in @("database", "d") } {
			if ($SubArgs[0] -eq "-h") {
				print_db_help
			} else {
				db_login -Arguments $SubArgs
				if ($updateCacheFile) {
					show_update_notification $updateCacheFile
				}
			}
		}
		{ $_ -in @("cleanup", "c") } {
			if ($SubArgs[0] -eq "-h") {
				Write-Output "Logout from all proxies, accounts & clusters."
			} else {
				th_kill
			}
		}
		{ $_ -in @("login", "l") } {
			if ($SubArgs[0] -eq "-h") {
				Write-Output "Log in to Teleport."
			} else {
				th_login
			}
		}
		{ $_ -in @("version", "v") } {
			get_th_version
		}
		{ $_ -in @("quickstart", "qs") } {
			Start-Process "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1384972392/TH+-+Teleport+Helper+Quick+Start"
		}
		{ $_ -in @("docs", "doc") } {
			Start-Process "https://youlend.atlassian.net/wiki/spaces/ISS/pages/1378517027/TH+-+Teleport+Helper+Docs"
		}
		{ $_ -in @("animate") } {
			switch ($SubArgs[0]) {
				"yl" { animate_youlend }
				default { animate_th }
			}
		}
		{ $_ -in @("loader") } {
			if ($SubArgs) {
				demo_wave_loader @SubArgs
			} else {
				demo_wave_loader
			}
		}
		{ $_ -in @("update", "u") } {
			choco upgrade th -y
		}
		{ $_ -in @("notifications", "n") } {
			create_notification "$version" "1.6.1"
		}
		"" {
			if (Get-Command less -ErrorAction SilentlyContinue) {
			print_help $version | less -R
			} else {
			# Fallback for Windows without `less`
			print_help $version | Out-Host -Paging
			}
		}
		default {
			Write-Host "Mate what..🤔 Try running " -NoNewLine
			ccode "th"
		}
    }
}
