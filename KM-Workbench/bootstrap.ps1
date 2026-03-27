#requires -Version 5.1
<#
.SYNOPSIS
    Key Methods Workbench - Bootstrap Script
    
.DESCRIPTION
    This bootstrap script downloads and launches the Key Methods Workbench utility.
    It is designed to be invoked remotely via:
        irm https://wb.keymethods.net/bootstrap.ps1 | iex
    
    Or downloaded and executed locally:
        iwr https://wb.keymethods.net/bootstrap.ps1 -OutFile .\bootstrap.ps1
        powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

.COMPANY
    Key Methods

.PRODUCT
    Key Methods Workbench

.VERSION
    1.0.0

.NOTES
    Author: Key Methods IT
    Website: https://wb.keymethods.net
    License: Internal Use Only
    
    This script is transparent and readable. Review before execution.
#>

[CmdletBinding()]
param(
    [switch]$Admin,
    [switch]$SkipUpdateCheck,
    [string]$WorkingDirectory = $null,
    [string]$ConfigUrl = $null,
    [string]$Mode = "GUI"  # GUI, AppsOnly, RepairsOnly
)

#region Configuration
# ============================================================================
# HOSTING CONFIGURATION - CUSTOMIZE THESE URLS FOR YOUR ENVIRONMENT
# ============================================================================

# Primary hosting URL - Change this to your actual hosting location
# Examples:
#   - GitHub Raw: https://raw.githubusercontent.com/yourorg/km-workbench/main/
#   - GitHub Pages: https://yourorg.github.io/km-workbench/
#   - Custom Domain: https://wb.keymethods.net/
# Use environment variable if set, otherwise default URL (PowerShell 5.1 compatible)
if ($env:KM_WORKBENCH_URL) {
    $script:HostedBaseUrl = $env:KM_WORKBENCH_URL
} else {
    $script:HostedBaseUrl = "https://raw.githubusercontent.com/MathHue/Workbench/main/KM-Workbench/"
}

# Ensure trailing slash
if (-not $script:HostedBaseUrl.EndsWith('/')) {
    $script:HostedBaseUrl += '/'
}

# File paths relative to base URL
$script:FileManifest = @{
    "main.ps1" = "main.ps1"
    "Modules/UI.psm1" = "Modules/UI.psm1"
    "Modules/Apps.psm1" = "Modules/Apps.psm1"
    "Modules/Repairs.psm1" = "Modules/Repairs.psm1"
    "Modules/Tweaks.psm1" = "Modules/Tweaks.psm1"
    "Modules/Maintenance.psm1" = "Modules/Maintenance.psm1"
    "Modules/Logging.psm1" = "Modules/Logging.psm1"
    "Modules/Branding.psm1" = "Modules/Branding.psm1"
    "Modules/Helpers.psm1" = "Modules/Helpers.psm1"
    "Config/branding.json" = "Config/branding.json"
    "Config/applications.json" = "Config/applications.json"
    "Config/repair-actions.json" = "Config/repair-actions.json"
    "Config/presets.json" = "Config/presets.json"
    "Config/maintenance-actions.json" = "Config/maintenance-actions.json"
    "Assets/keymethods-logo.png" = "Assets/keymethods-logo.png"
}

$script:AppName = "Key Methods Workbench"
$script:AppVersion = "1.0.0"
# Use provided working directory or default to temp (PowerShell 5.1 compatible)
if ($WorkingDirectory) {
    $script:TempBaseDir = $WorkingDirectory
} else {
    $script:TempBaseDir = "$env:TEMP\KM-Workbench"
}
$script:LogFile = "$script:TempBaseDir\bootstrap.log"

#endregion

#region Helper Functions
# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-BootstrapLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Ensure directory exists
    if (-not (Test-Path $script:TempBaseDir)) {
        New-Item -ItemType Directory -Path $script:TempBaseDir -Force | Out-Null
    }
    
    Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    
    $colorMap = @{
        "Info" = "Cyan"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Success" = "Green"
    }
    
    Write-Host $logEntry -ForegroundColor $colorMap[$Level]
}

function Test-AdminRights {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-Elevated {
    param(
        [string]$ScriptPath,
        [hashtable]$Arguments
    )
    
    Write-BootstrapLog -Level "Warning" -Message "Administrator rights required. Restarting elevated..."
    
    $argList = "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    
    if ($Arguments.Admin) { $argList += " -Admin" }
    if ($Arguments.SkipUpdateCheck) { $argList += " -SkipUpdateCheck" }
    if ($Arguments.WorkingDirectory) { $argList += " -WorkingDirectory `"$($Arguments.WorkingDirectory)`"" }
    if ($Arguments.Mode -ne "GUI") { $argList += " -Mode `"$($Arguments.Mode)`"" }
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait
        exit 0
    }
    catch {
        Write-BootstrapLog -Level "Error" -Message "Failed to restart with elevation: $_"
        exit 1
    }
}

function Test-Prerequisites {
    $results = @{
        PowerShellVersion = $PSVersionTable.PSVersion -ge [version]"5.1"
        DotNetVersion = $true  # PS 5.1 requires .NET
        InternetAccess = $false
        ExecutionPolicy = $false
    }
    
    # Test internet connectivity
    try {
        $testUrl = "$script:HostedBaseUrl`?test=1"
        $null = Invoke-WebRequest -Uri $testUrl -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $results.InternetAccess = $true
    }
    catch {
        # Try alternative test
        try {
            $null = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
            $results.InternetAccess = $true
        }
        catch {
            $results.InternetAccess = $false
        }
    }
    
    # Check execution policy
    $policy = Get-ExecutionPolicy
    $results.ExecutionPolicy = $policy -in @("RemoteSigned", "Unrestricted", "Bypass")
    
    return $results
}

function Invoke-FileDownload {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$Destination,
        
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    $success = $false
    
    # Ensure destination directory exists
    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    while ($retryCount -lt $MaxRetries -and -not $success) {
        try {
            $retryCount++
            Write-BootstrapLog -Level "Info" -Message "Downloading: $Url (Attempt $retryCount/$MaxRetries)"
            
            # Add cache-busting query parameter to force fresh download from GitHub
            $cacheBustUrl = "$Url`?t=$(Get-Date -Format 'yyyyMMddHHmmss')"
            Invoke-WebRequest -Uri $cacheBustUrl -OutFile $Destination -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            
            if (Test-Path $Destination) {
                $fileSize = (Get-Item $Destination).Length
                if ($fileSize -gt 0) {
                    $success = $true
                    Write-BootstrapLog -Level "Success" -Message "Downloaded successfully: $([math]::Round($fileSize/1KB, 2)) KB"
                }
                else {
                    throw "Downloaded file is empty"
                }
            }
            else {
                throw "File not found after download"
            }
        }
        catch {
            Write-BootstrapLog -Level "Warning" -Message "Download failed: $_"
            if ($retryCount -lt $MaxRetries) {
                Start-Sleep -Seconds 2
            }
        }
    }
    
    return $success
}

function Initialize-WorkbenchFiles {
    param(
        [switch]$Force
    )
    
    Write-BootstrapLog -Level "Info" -Message "Initializing Key Methods Workbench files..."
    
    $downloadResults = @{
        Success = @()
        Failed = @()
    }
    
    foreach ($file in $script:FileManifest.GetEnumerator()) {
        $localPath = Join-Path $script:TempBaseDir $file.Key
        $remoteUrl = "$script:HostedBaseUrl$($file.Value)"
        
        # Check if file already exists and is recent (less than 1 hour old)
        $shouldDownload = $Force
        if (-not $Force -and (Test-Path $localPath)) {
            $fileAge = (Get-Date) - (Get-Item $localPath).LastWriteTime
            if ($fileAge.TotalHours -gt 1) {
                $shouldDownload = $true
            }
            else {
                Write-BootstrapLog -Level "Info" -Message "Using cached: $($file.Key)"
                $downloadResults.Success += $file.Key
            }
        }
        else {
            $shouldDownload = $true
        }
        
        if ($shouldDownload) {
            if (Invoke-FileDownload -Url $remoteUrl -Destination $localPath) {
                $downloadResults.Success += $file.Key
            }
            else {
                $downloadResults.Failed += $file.Key
                Write-BootstrapLog -Level "Error" -Message "Failed to download: $($file.Key)"
            }
        }
    }
    
    return $downloadResults
}

function Import-WorkbenchModules {
    $modulePath = Join-Path $script:TempBaseDir "Modules"
    
    $modules = @(
        "Helpers.psm1",
        "Logging.psm1",
        "Branding.psm1",
        "Apps.psm1",
        "Repairs.psm1",
        "Tweaks.psm1",
        "Maintenance.psm1",
        "UI.psm1"
    )
    
    foreach ($module in $modules) {
        $moduleFile = Join-Path $modulePath $module
        if (Test-Path $moduleFile) {
            try {
                Import-Module $moduleFile -Force -ErrorAction Stop
                Write-BootstrapLog -Level "Success" -Message "Loaded module: $module"
            }
            catch {
                Write-BootstrapLog -Level "Error" -Message "Failed to load module $module : $_"
            }
        }
        else {
            Write-BootstrapLog -Level "Warning" -Message "Module not found: $module"
        }
    }
}

function Test-STAThread {
    <#
    .SYNOPSIS
        Checks if running in STA mode (required for WPF GUI).
    #>
    return ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA)
}

function Show-Banner {
    Clear-Host
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                 ██╗  ██╗███╗   ███╗    ██╗    ██╗██████╗ ██╗             ║
║                 ██║ ██╔╝████╗ ████║    ██║    ██║██╔══██╗██║             ║
║                 █████╔╝ ██╔████╔██║    ██║ █╗ ██║██████╔╝██║             ║
║                 ██╔═██╗ ██║╚██╔╝██║    ██║███╗██║██╔══██╗██║             ║
║                 ██║  ██╗██║ ╚═╝ ██║    ╚███╔███╔╝██║  ██║███████╗        ║
║                 ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝        ║
║                                                                           ║
║                    Key Methods Workbench v$script:AppVersion                           ║
║                        Install. Repair. Maintain.                         ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-Host "  Remote URL: $script:HostedBaseUrl" -ForegroundColor Gray
    Write-Host "  Working Directory: $script:TempBaseDir" -ForegroundColor Gray
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "  Admin Rights: $(if (Test-AdminRights) { 'Yes' } else { 'No' })" -ForegroundColor Gray
    Write-Host ""
}

function Show-Usage {
    Write-Host @"

USAGE:
------
Remote Launch (One-liner):
    irm https://wb.keymethods.net/bootstrap.ps1 | iex

Remote Launch with Admin:
    irm https://wb.keymethods.net/bootstrap.ps1 | iex; Start-Workbench -Admin

Download and Run Locally:
    iwr https://wb.keymethods.net/bootstrap.ps1 -OutFile .\bootstrap.ps1
    powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

SAFER ALTERNATIVE (Recommended for production):
    1. Download the script:
       iwr https://wb.keymethods.net/bootstrap.ps1 -OutFile .\bootstrap.ps1
    
    2. Review the script:
       notepad .\bootstrap.ps1
    
    3. Execute:
       powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1

PARAMETERS:
    -Admin                  : Request administrator elevation
    -SkipUpdateCheck        : Skip version check
    -WorkingDirectory <path>: Custom working directory
    -Mode <GUI|AppsOnly|RepairsOnly> : Launch mode

"@ -ForegroundColor Yellow
}

#endregion

#region Main Execution
# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-Workbench {
    [CmdletBinding()]
    param(
        [switch]$Admin,
        [switch]$SkipUpdateCheck
    )
    
    # Check STA mode for WPF GUI
    if (-not (Test-STAThread)) {
        Clear-Host
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                         THREAD MODE WARNING                               ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  Key Methods Workbench requires STA (Single Threaded Apartment) mode.     ║
║  You are currently running in MTA mode, which is incompatible with WPF.   ║
║                                                                           ║
║  SOLUTIONS:                                                               ║
║                                                                           ║
║  1. Download and run locally (RECOMMENDED):                               ║
║     iwr $script:HostedBaseUrl/bootstrap.ps1 -OutFile .\bootstrap.ps1      ║
║     powershell -STA -ExecutionPolicy Bypass -File .\bootstrap.ps1         ║
║                                                                           ║
║  2. Or launch PowerShell in STA mode first:                               ║
║     powershell -STA                                                       ║
║     Then run: irm $script:HostedBaseUrl/bootstrap.ps1 | iex               ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow
        return
    }
    
    # Show banner
    Show-Banner
    
    # Check if admin is required but not present
    if ($Admin -and -not (Test-AdminRights)) {
        # Re-launch as admin
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            # If invoked via IEX, save to temp file
            $scriptPath = "$script:TempBaseDir\bootstrap.ps1"
            $MyInvocation.MyCommand.ScriptContents | Set-Content -Path $scriptPath -Force
        }
        
        $args = @{
            Admin = $Admin
            SkipUpdateCheck = $SkipUpdateCheck
            WorkingDirectory = $script:TempBaseDir
        }
        
        Restart-Elevated -ScriptPath $scriptPath -Arguments $args
        return
    }
    
    # Test prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Cyan
    $prereqs = Test-Prerequisites
    
    if (-not $prereqs.PowerShellVersion) {
        Write-BootstrapLog -Level "Error" -Message "PowerShell 5.1 or later is required."
        exit 1
    }
    
    if (-not $prereqs.InternetAccess) {
        Write-BootstrapLog -Level "Warning" -Message "Internet connectivity may be limited. Some features may not work."
    }
    
    if (-not $prereqs.ExecutionPolicy) {
        Write-BootstrapLog -Level "Warning" -Message "Execution policy may prevent script execution. Current policy: $(Get-ExecutionPolicy)"
        Write-Host "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Yellow
    }
    
    # Initialize files
    Write-Host "`nDownloading Workbench components..." -ForegroundColor Cyan
    $fileResults = Initialize-WorkbenchFiles -Force:(-not $SkipUpdateCheck)
    
    if ($fileResults.Failed.Count -gt 0) {
        Write-BootstrapLog -Level "Warning" -Message "Some files failed to download. The application may not function correctly."
        foreach ($failed in $fileResults.Failed) {
            Write-Host "  ✗ $failed" -ForegroundColor Red
        }
    }
    
    Write-Host "`nDownloaded $($fileResults.Success.Count) files successfully." -ForegroundColor Green
    
    # Import modules
    Write-Host "`nLoading modules..." -ForegroundColor Cyan
    Import-WorkbenchModules
    
    # Launch main application
    Write-Host "`nStarting Key Methods Workbench..." -ForegroundColor Cyan
    $mainScript = Join-Path $script:TempBaseDir "main.ps1"
    
    Write-Host "Main script path: $mainScript" -ForegroundColor Gray
    
    if (Test-Path $mainScript) {
        try {
            # Create argument hashtable for main script
            $mainArgs = @{
                WorkingDirectory = $script:TempBaseDir
                IsAdmin = (Test-AdminRights)
                BootstrapVersion = $script:AppVersion
                HostedBaseUrl = $script:HostedBaseUrl
                Mode = $Mode
            }
            
            Write-Host "Launching main script with args: $(($mainArgs.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')" -ForegroundColor Gray
            
            # Dot-source the main script
            . $mainScript @mainArgs
        }
        catch {
            Write-BootstrapLog -Level "Error" -Message "Failed to launch main application: $_"
            Write-Host "`nError details: $_" -ForegroundColor Red
            Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
            Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    else {
        Write-BootstrapLog -Level "Error" -Message "Main application script not found: $mainScript"
        Write-Host "ERROR: Main script not found at: $mainScript" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

#endregion

# ============================================================================
# ENTRY POINT
# ============================================================================

try {
    # If the script was invoked with -? or -Help, show usage
    if ($args -contains '-?' -or $args -contains '-Help' -or $args -contains '--help') {
        Show-Usage
        exit 0
    }

    # Start the workbench
    Start-Workbench -Admin:$Admin -SkipUpdateCheck:$SkipUpdateCheck
}
catch {
    Write-Host "`nCRITICAL ERROR: $_" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    Write-Host "`nPlease ensure you are using PowerShell 5.1 or later." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}
