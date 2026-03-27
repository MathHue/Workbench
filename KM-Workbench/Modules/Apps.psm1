# ============================================================================
# Key Methods Workbench - Apps Module
# ============================================================================
# Application installation and management functionality

$script:AppCache = @{}
$script:SupportedProviders = @("Winget", "Chocolatey", "Custom", "MSI", "EXE")

function Get-KMApplicationCatalog {
    <#
    .SYNOPSIS
        Gets the application catalog from configuration.
    
    .PARAMETER Category
        Filter by category.
    
    .PARAMETER Provider
        Filter by provider.
    
    .PARAMETER Search
        Search term for name or description.
    #>
    param(
        [string]$Category = $null,
        [string]$Provider = $null,
        [string]$Search = $null
    )
    
    $configPath = Join-Path $script:ConfigPath "applications.json"
    
    try {
        if (Test-Path $configPath) {
            $apps = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            # Return default catalog if config not found
            $apps = Get-KMDefaultAppCatalog
        }
        
        # Apply filters
        if ($Category) {
            $apps = $apps | Where-Object { $_.category -eq $Category }
        }
        
        if ($Provider) {
            $apps = $apps | Where-Object { $_.provider -eq $Provider }
        }
        
        if ($Search) {
            $apps = $apps | Where-Object { 
                $_.name -like "*$Search*" -or 
                $_.description -like "*$Search*" -or
                $_.tags -contains $Search
            }
        }
        
        return $apps
    }
    catch {
        Write-KMLog -Message "Failed to get application catalog: $_" -Level "Error"
        return @()
    }
}

function Install-KMApplication {
    <#
    .SYNOPSIS
        Installs a single application.
    
    .PARAMETER AppDefinition
        Application definition object.
    
    .PARAMETER Force
        Force installation even if already installed.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AppDefinition,
        
        [switch]$Force
    )
    
    $appName = $AppDefinition.name
    $provider = $AppDefinition.provider
    
    Write-KMLog -Message "Installing $appName using $provider..." -Level "Info"
    
    # Check if already installed (unless Force)
    if (-not $Force) {
        $installed = Test-KMApplicationInstalled -AppDefinition $AppDefinition
        if ($installed) {
            Write-KMLog -Message "$appName is already installed. Use -Force to reinstall." -Level "Warning"
            return @{ Success = $true; AlreadyInstalled = $true; Output = "Already installed" }
        }
    }
    
    $result = @{ Success = $false; Output = ""; Error = "" }
    
    switch ($provider) {
        "Winget" {
            $result = Install-KMAppWinget -AppDefinition $AppDefinition
        }
        "Chocolatey" {
            $result = Install-KMAppChocolatey -AppDefinition $AppDefinition
        }
        "Custom" {
            $result = Install-KMAppCustom -AppDefinition $AppDefinition
        }
        "MSI" {
            $result = Install-KMAppMSI -AppDefinition $AppDefinition
        }
        "EXE" {
            $result = Install-KMAppEXE -AppDefinition $AppDefinition
        }
        default {
            $result.Error = "Unknown provider: $provider"
            Write-KMLog -Message $result.Error -Level "Error"
        }
    }
    
    if ($result.Success) {
        Write-KMLog -Message "$appName installed successfully" -Level "Success"
    }
    else {
        Write-KMLog -Message "Failed to install $appName : $($result.Error)" -Level "Error"
    }
    
    return $result
}

function Install-KMAppWinget {
    param([hashtable]$AppDefinition)
    
    $packageId = $AppDefinition.packageId
    $arguments = @("install", "--id", $packageId, "--accept-source-agreements", "--accept-package-agreements", "-h")
    
    # Add any custom arguments
    if ($AppDefinition.installArguments) {
        $arguments += $AppDefinition.installArguments
    }
    
    return Invoke-KMCommand -Command "winget" -Arguments $arguments -TimeoutSeconds 600
}

function Install-KMAppChocolatey {
    param([hashtable]$AppDefinition)
    
    $packageId = $AppDefinition.packageId
    $arguments = @("install", $packageId, "-y")
    
    if ($AppDefinition.installArguments) {
        $arguments += $AppDefinition.installArguments
    }
    
    return Invoke-KMCommand -Command "choco" -Arguments $arguments -TimeoutSeconds 600
}

function Install-KMAppCustom {
    param([hashtable]$AppDefinition)
    
    if ($AppDefinition.installCommand) {
        return Invoke-KMPowerShell -Command $AppDefinition.installCommand
    }
    else {
        return @{ Success = $false; Error = "No install command specified" }
    }
}

function Install-KMAppMSI {
    param([hashtable]$AppDefinition)
    
    $arguments = @("/i", "`"$($AppDefinition.installerPath)`"", "/qn", "/norestart")
    
    if ($AppDefinition.installArguments) {
        $arguments += $AppDefinition.installArguments
    }
    
    return Invoke-KMCommand -Command "msiexec" -Arguments $arguments -TimeoutSeconds 300
}

function Install-KMAppEXE {
    param([hashtable]$AppDefinition)
    
    $arguments = @()
    
    if ($AppDefinition.installArguments) {
        $arguments = $AppDefinition.installArguments -split " "
    }
    
    return Invoke-KMCommand -Command $AppDefinition.installerPath -Arguments $arguments -TimeoutSeconds 300
}

function Uninstall-KMApplication {
    <#
    .SYNOPSIS
        Uninstalls a single application.
    
    .PARAMETER AppDefinition
        Application definition object.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AppDefinition
    )
    
    $appName = $AppDefinition.name
    $provider = $AppDefinition.provider
    
    Write-KMLog -Message "Uninstalling $appName..." -Level "Info"
    
    $result = @{ Success = $false; Output = ""; Error = "" }
    
    switch ($provider) {
        "Winget" {
            $result = Invoke-KMCommand -Command "winget" -Arguments @("uninstall", "--id", $AppDefinition.packageId, "-h") -TimeoutSeconds 300
        }
        "Chocolatey" {
            $result = Invoke-KMCommand -Command "choco" -Arguments @("uninstall", $AppDefinition.packageId, "-y") -TimeoutSeconds 300
        }
        "Custom" {
            if ($AppDefinition.uninstallCommand) {
                $result = Invoke-KMPowerShell -Command $AppDefinition.uninstallCommand
            }
            else {
                $result.Error = "No uninstall command specified"
            }
        }
        default {
            $result.Error = "Uninstall not supported for provider: $provider"
        }
    }
    
    if ($result.Success) {
        Write-KMLog -Message "$appName uninstalled successfully" -Level "Success"
    }
    else {
        Write-KMLog -Message "Failed to uninstall $appName : $($result.Error)" -Level "Error"
    }
    
    return $result
}

function Test-KMApplicationInstalled {
    <#
    .SYNOPSIS
        Checks if an application is installed.
    
    .PARAMETER AppDefinition
        Application definition object.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$AppDefinition
    )
    
    $packageId = $AppDefinition.packageId
    $provider = $AppDefinition.provider
    
    switch ($provider) {
        "Winget" {
            try {
                $result = winget list --id $packageId 2>&1
                return $result -notmatch "No installed package found"
            }
            catch {
                return $false
            }
        }
        "Chocolatey" {
            try {
                $result = choco list --local-only $packageId 2>&1
                return $result -match "^$packageId"
            }
            catch {
                return $false
            }
        }
        default {
            # For custom/MSI/EXE, check registry
            $regPaths = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            foreach ($path in $regPaths) {
                $app = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                       Where-Object { $_.DisplayName -like "*$($AppDefinition.name)*" }
                if ($app) {
                    return $true
                }
            }
            return $false
        }
    }
}

function Install-KMApplicationBatch {
    <#
    .SYNOPSIS
        Installs multiple applications.
    
    .PARAMETER Applications
        Array of application definitions.
    
    .PARAMETER Preset
        Preset name to use.
    
    .PARAMETER OnProgress
        ScriptBlock to call on progress updates.
    #>
    param(
        [array]$Applications,
        [string]$Preset,
        [scriptblock]$OnProgress = $null
    )
    
    $results = @{
        Total = 0
        Success = 0
        Failed = 0
        AlreadyInstalled = 0
        Details = @()
    }
    
    # Load preset if specified
    if ($Preset) {
        $Applications = Get-KMApplicationsFromPreset -PresetName $Preset
    }
    
    $results.Total = $Applications.Count
    $counter = 0
    
    foreach ($app in $Applications) {
        $counter++
        $percentComplete = ($counter / $results.Total) * 100
        
        if ($OnProgress) {
            & $OnProgress -Activity "Installing Applications" -Status "$counter of $($results.Total): $($app.name)" -PercentComplete $percentComplete
        }
        
        Show-KMProgress -Activity "Installing Applications" -Status "$counter of $($results.Total): $($app.name)" -PercentComplete $percentComplete
        
        $result = Install-KMApplication -AppDefinition $app
        $result.AppName = $app.name
        $results.Details += $result
        
        if ($result.AlreadyInstalled) {
            $results.AlreadyInstalled++
        }
        elseif ($result.Success) {
            $results.Success++
        }
        else {
            $results.Failed++
        }
    }
    
    Hide-KMProgress
    
    Write-KMLog -Message "Batch installation complete. Success: $($results.Success), Failed: $($results.Failed), Already Installed: $($results.AlreadyInstalled)" -Level "Info"
    
    return $results
}

function Get-KMApplicationsFromPreset {
    <#
    .SYNOPSIS
        Gets applications from a preset.
    
    .PARAMETER PresetName
        Name of the preset.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetName
    )
    
    $configPath = Join-Path $script:ConfigPath "presets.json"
    
    try {
        if (Test-Path $configPath) {
            $presets = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            
            if ($presets.appPresets[$PresetName]) {
                $appNames = $presets.appPresets[$PresetName].applications
                $allApps = Get-KMApplicationCatalog
                
                return $allApps | Where-Object { $appNames -contains $_.name }
            }
        }
    }
    catch {
        Write-KMLog -Message "Failed to load preset: $_" -Level "Error"
    }
    
    return @()
}

function Get-KMAppCategories {
    <#
    .SYNOPSIS
        Gets all unique application categories.
    #>
    $apps = Get-KMApplicationCatalog
    return $apps | Select-Object -ExpandProperty category -Unique | Sort-Object
}

function Get-KMDefaultAppCatalog {
    <#
    .SYNOPSIS
        Returns the default application catalog if config file is missing.
    #>
    return @(
        @{ name = "Google Chrome"; category = "Browsers"; provider = "Winget"; packageId = "Google.Chrome"; description = "Fast, secure web browser"; enabled = $true }
        @{ name = "Mozilla Firefox"; category = "Browsers"; provider = "Winget"; packageId = "Mozilla.Firefox"; description = "Privacy-focused browser"; enabled = $true }
        @{ name = "7-Zip"; category = "Utilities"; provider = "Winget"; packageId = "7zip.7zip"; description = "File archiver with high compression"; enabled = $true }
        @{ name = "Adobe Acrobat Reader"; category = "Productivity"; provider = "Winget"; packageId = "Adobe.Acrobat.Reader.64-bit"; description = "PDF viewer"; enabled = $true }
        @{ name = "VLC Media Player"; category = "Media"; provider = "Winget"; packageId = "VideoLAN.VLC"; description = "Versatile media player"; enabled = $true }
        @{ name = "Notepad++"; category = "Developer Tools"; provider = "Winget"; packageId = "Notepad++.Notepad++"; description = "Advanced text editor"; enabled = $true }
        @{ name = "Microsoft Teams"; category = "Communication"; provider = "Winget"; packageId = "Microsoft.Teams"; description = "Collaboration platform"; enabled = $true }
        @{ name = "Zoom"; category = "Communication"; provider = "Winget"; packageId = "Zoom.Zoom"; description = "Video conferencing"; enabled = $true }
        @{ name = "PowerToys"; category = "Utilities"; provider = "Winget"; packageId = "Microsoft.PowerToys"; description = "Windows productivity tools"; enabled = $true }
        @{ name = "Everything"; category = "Utilities"; provider = "Winget"; packageId = "voidtools.Everything"; description = "Instant file search"; enabled = $true }
        @{ name = "Visual Studio Code"; category = "Developer Tools"; provider = "Winget"; packageId = "Microsoft.VisualStudioCode"; description = "Code editor"; enabled = $true }
        @{ name = "Git"; category = "Developer Tools"; provider = "Winget"; packageId = "Git.Git"; description = "Version control"; enabled = $true }
    )
}

function Get-KMInstalledApplications {
    <#
    .SYNOPSIS
        Gets a list of installed applications from the registry.
    #>
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $installedApps = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString |
            Sort-Object DisplayName
    }
    
    return $installedApps
}

function Export-KMInstalledApplications {
    <#
    .SYNOPSIS
        Exports the list of installed applications to a file.
    
    .PARAMETER Path
        Output file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $apps = Get-KMInstalledApplications
    $apps | Export-Csv -Path $Path -NoTypeInformation
    Write-KMLog -Message "Installed applications exported to: $Path" -Level "Success"
}

#region Export Module Members

Export-ModuleMember -Function @(
    'Get-KMApplicationCatalog',
    'Install-KMApplication',
    'Uninstall-KMApplication',
    'Test-KMApplicationInstalled',
    'Install-KMApplicationBatch',
    'Get-KMApplicationsFromPreset',
    'Get-KMAppCategories',
    'Get-KMInstalledApplications',
    'Export-KMInstalledApplications'
)

#endregion
