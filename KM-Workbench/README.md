# Key Methods Workbench

**Install. Repair. Maintain.**

Key Methods Workbench is an internal technician utility for workstation setup, application deployment, Windows remediation, and maintenance workflows. Built for MSP and internal IT environments, it provides a polished, professional interface for common technician tasks.

![Key Methods Workbench](Assets/keymethods-logo.png)

## Features

- **🚀 Remote Launch**: Launch from PowerShell with a single command
- **📦 Application Management**: Install/uninstall software via Winget, Chocolatey, or custom commands
- **🔧 Windows Repairs**: Safe, advanced, and dangerous repair actions with proper warnings
- **⚡ System Tweaks**: Practical system configuration adjustments
- **🛠️ Maintenance Tools**: Quick access to Windows utilities and system management
- **📋 Logging**: Comprehensive session logging with export capability
- **🎨 Professional UI**: Dark-themed, branded interface

## Quick Start

### Remote Launch (One-Liner)

```powershell
irm https://wb.keymethods.net/bootstrap.ps1 | iex
```

### Download and Run (Recommended for Production)

```powershell
# Download the bootstrap script
iwr https://wb.keymethods.net/bootstrap.ps1 -OutFile .\bootstrap.ps1

# Review the script (recommended)
notepad .\bootstrap.ps1

# Execute with proper permissions
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

### Local Launch

```powershell
# Navigate to the project directory
cd KM-Workbench

# Run the bootstrap script directly
.\bootstrap.ps1

# Or with admin rights
.\bootstrap.ps1 -Admin
```

## Hosting Instructions

### GitHub Pages (Recommended for Development)

1. Create a new GitHub repository for the project
2. Push all files to the repository
3. Enable GitHub Pages in repository settings
4. Access the raw files using:
   ```
   https://raw.githubusercontent.com/YOURORG/km-workbench/main/bootstrap.ps1
   ```

### Custom Web Server (Production)

1. Copy all files to your web server directory (e.g., `C:\inetpub\wwwroot\wb.keymethods.net\`)
2. Configure MIME types for PowerShell files:
   - `.ps1` → `text/plain` or `application/octet-stream`
   - `.json` → `application/json`
3. Ensure CORS headers allow PowerShell web requests
4. Access via your configured URL:
   ```
   https://wb.keymethods.net/bootstrap.ps1
   ```

### Customizing the Bootstrap URL

Edit `bootstrap.ps1` and update the `$script:HostedBaseUrl` variable:

```powershell
# Line ~50 in bootstrap.ps1
$script:HostedBaseUrl = "https://wb.keymethods.net/"
# Change to your hosting location
$script:HostedBaseUrl = "https://yourdomain.com/km-workbench/"
```

## Project Structure

```
KM-Workbench/
├── bootstrap.ps1              # Remote launch entry point
├── main.ps1                   # Main application script
├── README.md                  # This file
├── Modules/
│   ├── Helpers.psm1          # Common helper functions
│   ├── Logging.psm1          # Logging functionality
│   ├── Branding.psm1         # Branding and theming
│   ├── Apps.psm1             # Application management
│   ├── Repairs.psm1          # Repair actions
│   ├── Tweaks.psm1           # System tweaks
│   ├── Maintenance.psm1      # Maintenance utilities
│   └── UI.psm1               # UI helper functions
├── Config/
│   ├── branding.json         # Branding configuration
│   ├── applications.json     # Application catalog
│   ├── repair-actions.json   # Repair action definitions
│   ├── presets.json          # Application and repair presets
│   └── maintenance-actions.json # Maintenance action definitions
├── Assets/
│   └── keymethods-logo.png   # Company logo
└── Logs/                     # Session logs (created at runtime)
```

## Adding Applications

Edit `Config/applications.json` and add a new entry:

```json
{
  "name": "Application Name",
  "category": "Category Name",
  "provider": "Winget",
  "packageId": "Publisher.PackageName",
  "description": "Brief description of the application",
  "tags": ["tag1", "tag2"],
  "enabled": true,
  "requiresAdmin": false
}
```

### Supported Providers

| Provider | Description |
|----------|-------------|
| `Winget` | Microsoft Package Manager |
| `Chocolatey` | Chocolatey package manager |
| `Custom` | Custom PowerShell command |
| `MSI` | MSI installer file |
| `EXE` | Executable installer |

### Available Categories

- Browsers
- Communication
- Developer Tools
- Media
- Productivity
- Remote Support
- Security
- Utilities
- Custom categories supported

## Adding Repair Actions

Edit `Config/repair-actions.json` and add a new entry:

```json
{
  "name": "Action Display Name",
  "category": "Network",
  "description": "What this action does",
  "commandType": "cmd",
  "command": "ipconfig",
  "arguments": ["/flushdns"],
  "dangerLevel": "safe",
  "requiresAdmin": false,
  "requiresConfirmation": false,
  "rebootRecommended": false,
  "enabled": true
}
```

### Danger Levels

| Level | Description |
|-------|-------------|
| `safe` | Safe to run, minimal risk |
| `advanced` | May affect system state, use with awareness |
| `dangerous` | Significant changes, requires confirmation |

### Command Types

| Type | Description |
|------|-------------|
| `cmd` | Standard command execution |
| `powershell` | PowerShell script block |
| `service` | Service restart |

## Updating Branding

Edit `Config/branding.json` to customize:

```json
{
  "appTitle": "Your Company Workbench",
  "shortName": "YC Workbench",
  "companyName": "Your Company",
  "footerText": "Your Company Internal Utility",
  "tagline": "Your custom tagline",
  "aboutText": "Your about text",
  "primaryColor": "#0072C6",
  "secondaryColor": "#F26522",
  "logoPath": "Assets/your-logo.png"
}
```

## Presets

Presets allow you to define bundles of applications or repairs for common scenarios.

### Application Presets

Edit `Config/presets.json` under `appPresets`:

```json
"CustomPreset": {
  "name": "Custom Preset Name",
  "description": "Description of this preset",
  "applications": [
    "Google Chrome",
    "7-Zip",
    "Notepad++"
  ]
}
```

### Repair Presets

Edit `Config/presets.json` under `repairPresets`:

```json
"CustomRepair": {
  "name": "Custom Repair Sequence",
  "description": "Description of this repair preset",
  "actions": [
    "Flush DNS Cache",
    "Reset Winsock",
    "Release IP",
    "Renew IP"
  ]
}
```

## Command Line Options

### Bootstrap Script

```powershell
# Run with admin elevation
.\bootstrap.ps1 -Admin

# Skip update check
.\bootstrap.ps1 -SkipUpdateCheck

# Custom working directory
.\bootstrap.ps1 -WorkingDirectory "D:\KM-Workbench"

# Launch mode
.\bootstrap.ps1 -Mode GUI          # Full GUI (default)
.\bootstrap.ps1 -Mode AppsOnly     # Applications tab only
.\bootstrap.ps1 -Mode RepairsOnly  # Repairs tab only
```

## Security Considerations

### Execution Policy

The script requires an appropriate execution policy. For one-time execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

To set for current user:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Best Practices

1. **Review before execution**: Always review remote scripts before running
2. **Use HTTPS**: Only host and download from HTTPS URLs
3. **Verify integrity**: Consider implementing hash verification for downloaded files
4. **Admin rights**: The script will prompt for elevation when required
5. **Logging**: All actions are logged to the Logs folder

## Troubleshooting

### Bootstrap fails to download

1. Check internet connectivity
2. Verify the URL is accessible
3. Check if proxy settings are required
4. Try downloading manually first

### Module import fails

1. Ensure all files are in correct directories
2. Check that PowerShell execution policy allows scripts
3. Verify PowerShell version is 5.1 or later

### GUI doesn't appear

1. Check .NET Framework is installed (3.5 and 4.x)
2. Ensure Windows Desktop Experience is available
3. Check for WPF-related errors in the log

### Winget/Chocolatey not found

1. Install Winget from Microsoft Store
2. Install Chocolatey from chocolatey.org
3. These are optional - custom commands still work

## Requirements

- Windows 10/11 (64-bit recommended)
- PowerShell 5.1 or PowerShell 7.x
- .NET Framework 4.6.1 or later
- Internet connection (for remote launch and package downloads)
- Administrator rights (for certain operations)

## Development

### Adding New Modules

1. Create a new `.psm1` file in the `Modules` folder
2. Add functions with the `KM` prefix for consistency
3. Export functions using `Export-ModuleMember`
4. Import the module in `main.ps1`

### Testing Changes

```powershell
# Run locally for testing
.\bootstrap.ps1 -WorkingDirectory "$PWD"

# Force re-download of modules
.\bootstrap.ps1 -SkipUpdateCheck:$false
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

Internal Use Only - Key Methods

## Support

- **Website**: https://wb.keymethods.net/
- **Email**: support@keymethods.net

---

**Key Methods Internal Utility**  
*Install. Repair. Maintain.*
