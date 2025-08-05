# TH - Chocolatey Package

This directory contains the Chocolatey package files for TH (Teleport Helper).

## Package Structure

```
chocolatey/
├── th.nuspec                      # Package manifest
├── tools/
│   ├── chocolateyinstall.ps1      # Installation script
│   └── chocolateyuninstall.ps1    # Uninstall script
└── README.md                      # This file
```

## Building the Package

1. **Install Chocolatey** (if not already installed):
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

2. **Build the package**:
   ```bash
   cd chocolatey
   choco pack
   ```

3. **Test locally**:
   ```bash
   choco install th -s . -f
   ```

4. **Uninstall test**:
   ```bash
   choco uninstall th
   ```

## Publishing to Chocolatey Community

1. **Create account** at https://community.chocolatey.org/

2. **Get API key** from your profile

3. **Push package**:
   ```bash
   choco push th.1.4.9.nupkg -s https://push.chocolatey.org/ -k YOUR_API_KEY
   ```

## Package Details

- **ID**: `th`
- **Version**: `1.4.9` (update in th.nuspec)
- **Install Location**: `$env:USERPROFILE\Documents\PowerShell\Modules\th`
- **Configuration**: `th.config.json` copied to module directory

## Prerequisites

The package assumes users have:
- PowerShell 5.1+ or PowerShell Core
- Teleport CLI (tsh) installed
- kubectl for Kubernetes operations
- Appropriate network access to Teleport proxy

## Updating

To update the package:
1. Update version in `th.nuspec`
2. Update version in `th\th.psm1`
3. Rebuild and republish

## Testing

Always test the package locally before publishing:
```bash
# Build
choco pack

# Install locally
choco install th -s . -f

# Test functionality
th --help
th k -h
th a -h

# Uninstall
choco uninstall th
```