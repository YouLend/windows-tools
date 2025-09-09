# Load all function files
$moduleRoot = $PSScriptRoot
$version = "1.6.0"
Get-ChildItem -Path "$moduleRoot/functions" -Filter *.ps1 -Recurse | ForEach-Object {
    . $_.FullName
}

# Update functions are already loaded from functions directory

function th {
	# Capture current terminal state IMMEDIATELY before any processing (for update notifications)
	$global:PreCommandOutput = @()
	$global:PreCommandCursorPos = $null
	
	$Command = $args[0]
	$captureCommands = @("kube", "k", "aws", "a", "database", "d", "db", "terra", "t", "capture", "cap")
	
	if ($Command -in $captureCommands) {
		try {
			$console = $Host.UI.RawUI
			$cursorPos = $console.CursorPosition
			$global:PreCommandCursorPos = $cursorPos
			
			# Calculate rectangle coordinates for buffer capture
			$left = 0
			$top = 0
			$right = $console.BufferSize.Width - 1
			$bottom = $cursorPos.Y
			
			# Only capture if there's content to capture
			if ($bottom -ge $top -and $bottom -lt $console.BufferSize.Height) {
				$rect = New-Object System.Management.Automation.Host.Rectangle($left, $top, $right, $bottom)
				$buffer = $console.GetBufferContents($rect)
				
				# Convert buffer to string array, preserving exact spacing
				for ($y = 0; $y -lt $buffer.GetLength(0); $y++) {
					$line = ""
					for ($x = 0; $x -lt $buffer.GetLength(1); $x++) {
						$line += $buffer[$y, $x].Character
					}
					# Filter out the command line that triggered this function
					# Skip lines that match PS prompt pattern with "th" command
					if (-not ($line -match "PS\s+.*>\s*th\s+" -and $line.Contains($Command))) {
						$global:PreCommandOutput += $line
					}
				}
			}
		} catch {
			# If buffer reading fails, just continue without restoration
			$global:PreCommandOutput = @()
			$global:PreCommandCursorPos = $null
		}
	}

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
				# Show update notification after command completes
				# if ($updateCacheFile) {
				# 	show_update_notification $updateCacheFile
				# }
			}
		}
		{ $_ -in @("terra", "t") } {
			if ($SubArgs[0] -eq "-h") {
				Write-Output "Logs into yl-admin as sudo-admin"
			} else {
				terraform_login @SubArgs
				# Show update notification after command completes
				# if ($updateCacheFile) {
				# 	show_update_notification $updateCacheFile
				# }
			}
		}
		{ $_ -in @("aws", "a") } {
			if ($SubArgs[0] -eq "-h") {
				print_aws_help
			} else {
				# Run aws_login and capture what should be displayed
				aws_login -Arguments $SubArgs
				
				# if ($updateCacheFile) {
				# 	show_update_notification $updateCacheFile
				# }
			}
		}
		{ $_ -in @("database", "db", "d") } {
			if ($SubArgs[0] -eq "-h") {
				print_db_help
			} else {
				db_login -Arguments $SubArgs
				# Show update notification after command completes
				# if ($updateCacheFile) {
				# 	show_update_notification $updateCacheFile
				# }
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
				tsh login --auth=ad --proxy=youlend.teleport.sh:443
			}
		}
		{ $_ -in @("version", "v") } {
			Write-Output $version
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
