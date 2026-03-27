# ============================================================================
# Key Methods Workbench - Maintenance Module
# ============================================================================
# Maintenance utilities and system management functions

function Get-KMMaintenanceActions {
    <#
    .SYNOPSIS
        Gets available maintenance actions from configuration.
    #>
    $configPath = Join-Path $script:ConfigPath "maintenance-actions.json"
    
    try {
        if (Test-Path $configPath) {
            return Get-Content $configPath -Raw | ConvertFrom-Json
        }
        else {
            return Get-KMDefaultMaintenanceActions
        }
    }
    catch {
        Write-KMLog -Message "Failed to load maintenance actions: $_" -Level "Error"
        return Get-KMDefaultMaintenanceActions
    }
}

function Start-KMMaintenanceTool {
    <#
    .SYNOPSIS
        Launches a maintenance tool.
    
    .PARAMETER ToolId
        ID of the maintenance tool to launch.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolId
    )
    
    $actions = Get-KMMaintenanceActions
    $tool = $actions | Where-Object { $_.id -eq $ToolId }
    
    if (-not $tool) {
        Write-KMLog -Message "Maintenance tool not found: $ToolId" -Level "Error"
        return @{ Success = $false; Error = "Tool not found" }
    }
    
    Write-KMLog -Message "Launching maintenance tool: $($tool.name)" -Level "Info"
    
    try {
        if ($tool.commandType -eq "shell") {
            Start-Process $tool.shellCommand -ArgumentList $tool.arguments
        }
        elseif ($tool.commandType -eq "powershell" -and $tool.scriptBlock) {
            Invoke-KMPowerShell -Command $tool.scriptBlock | Out-Null
        }
        else {
            Start-Process $tool.command -ArgumentList $tool.arguments
        }
        
        return @{ Success = $true }
    }
    catch {
        Write-KMLog -Message "Failed to launch tool: $_" -Level "Error"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Update-KMPackages {
    <#
    .SYNOPSIS
        Updates all packages using available package managers.
    
    .PARAMETER Provider
        Specific provider to use (Winget, Chocolatey, or All).
    #>
    param(
        [ValidateSet("Winget", "Chocolatey", "All")]
        [string]$Provider = "All"
    )
    
    $results = @{
        Winget = @{ Success = $false; Output = ""; PackagesUpdated = 0 }
        Chocolatey = @{ Success = $false; Output = ""; PackagesUpdated = 0 }
    }
    
    # Winget upgrade all
    if ($Provider -in @("Winget", "All")) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-KMLog -Message "Updating packages via Winget..." -Level "Info"
            $wingetResult = Invoke-KMCommand -Command "winget" -Arguments @("upgrade", "--all", "--accept-source-agreements", "--accept-package-agreements") -TimeoutSeconds 3600
            $results.Winget = @{
                Success = $wingetResult.Success
                Output = $wingetResult.Output
                PackagesUpdated = if ($wingetResult.Success) { "Multiple" } else { 0 }
            }
        }
        else {
            $results.Winget.Output = "Winget not available"
        }
    }
    
    # Chocolatey upgrade all
    if ($Provider -in @("Chocolatey", "All")) {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-KMLog -Message "Updating packages via Chocolatey..." -Level "Info"
            $chocoResult = Invoke-KMCommand -Command "choco" -Arguments @("upgrade", "all", "-y") -TimeoutSeconds 3600
            $results.Chocolatey = @{
                Success = $chocoResult.Success
                Output = $chocoResult.Output
                PackagesUpdated = if ($chocoResult.Success) { "Multiple" } else { 0 }
            }
        }
        else {
            $results.Chocolatey.Output = "Chocolatey not available"
        }
    }
    
    return $results
}

function Export-KMSystemSummary {
    <#
    .SYNOPSIS
        Exports a comprehensive system summary report.
    
    .PARAMETER OutputPath
        Path to save the report.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-KMLog -Message "Generating system summary report..." -Level "Info"
    
    try {
        $summary = @{
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Domain = $env:USERDOMAIN
            SystemInfo = Get-KMSystemInfo
            DiskSpace = Get-KMDiskSpace
            InstalledApps = (Get-KMInstalledApplications | Select-Object -First 50)
            NetworkInfo = @{
                PublicIP = Get-KMPublicIP
                Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | 
                    Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress
            }
        }
        
        $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
        
        Write-KMLog -Message "System summary exported to: $OutputPath" -Level "Success"
        return @{ Success = $true; Path = $OutputPath }
    }
    catch {
        Write-KMLog -Message "Failed to export system summary: $_" -Level "Error"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Start-KMDiskCleanup {
    <#
    .SYNOPSIS
        Launches the Windows Disk Cleanup utility.
    #>
    try {
        Write-KMLog -Message "Starting Disk Cleanup..." -Level "Info"
        Start-Process cleanmgr -ArgumentList "/sageset:1"
        return @{ Success = $true }
    }
    catch {
        Write-KMLog -Message "Failed to start Disk Cleanup: $_" -Level "Error"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-KMDefaultMaintenanceActions {
    <#
    .SYNOPSIS
        Returns the default maintenance actions if config file is missing.
    #>
    return @(
        @{
            id = "diskcleanup"
            name = "Disk Cleanup"
            description = "Launch Windows Disk Cleanup utility"
            command = "cleanmgr"
            arguments = @()
            requiresAdmin = $false
        },
        @{
            id = "startupapps"
            name = "Startup Apps"
            description = "Manage startup applications"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start ms-settings:startupapps")
            requiresAdmin = $false
        },
        @{
            id = "services"
            name = "Services"
            description = "Open Services management console"
            command = "services.msc"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "devicemanager"
            name = "Device Manager"
            description = "Open Device Manager"
            command = "devmgmt.msc"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "programs"
            name = "Programs & Features"
            description = "Open Programs and Features"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start appwiz.cpl")
            requiresAdmin = $false
        },
        @{
            id = "windowsupdate"
            name = "Windows Update"
            description = "Open Windows Update settings"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start ms-settings:windowsupdate")
            requiresAdmin = $false
        },
        @{
            id = "eventviewer"
            name = "Event Viewer"
            description = "Open Event Viewer"
            command = "eventvwr.msc"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "taskscheduler"
            name = "Task Scheduler"
            description = "Open Task Scheduler"
            command = "taskschd.msc"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "taskmanager"
            name = "Task Manager"
            description = "Open Task Manager"
            command = "taskmgr"
            arguments = @()
            requiresAdmin = $false
        },
        @{
            id = "systeminfo"
            name = "System Information"
            description = "Open System Information"
            command = "msinfo32"
            arguments = @()
            requiresAdmin = $false
        },
        @{
            id = "perfmon"
            name = "Performance Monitor"
            description = "Open Performance Monitor"
            command = "perfmon"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "resmon"
            name = "Resource Monitor"
            description = "Open Resource Monitor"
            command = "resmon"
            arguments = @()
            requiresAdmin = $true
        },
        @{
            id = "control"
            name = "Control Panel"
            description = "Open Control Panel"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start control")
            requiresAdmin = $false
        },
        @{
            id = "network"
            name = "Network Connections"
            description = "Open Network Connections"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start ncpa.cpl")
            requiresAdmin = $false
        },
        @{
            id = "firewall"
            name = "Windows Firewall"
            description = "Open Windows Firewall settings"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start firewall.cpl")
            requiresAdmin = $true
        },
        @{
            id = "power"
            name = "Power Options"
            description = "Open Power Options"
            command = "shell"
            shellCommand = "powershell"
            arguments = @("-Command", "start powercfg.cpl")
            requiresAdmin = $false
        }
    )
}

function Get-KMStartupItems {
    <#
    .SYNOPSIS
        Gets startup items from various locations.
    #>
    $startupItems = @()
    
    # Registry startup locations
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
            foreach ($prop in $items.PSObject.Properties) {
                if ($prop.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
                    $startupItems += [PSCustomObject]@{
                        Name = $prop.Name
                        Command = $prop.Value
                        Location = $path
                        Type = "Registry"
                    }
                }
            }
        }
    }
    
    # Startup folders
    $startupFolders = @(
        "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    
    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            $items = Get-ChildItem $folder -File
            foreach ($item in $items) {
                $startupItems += [PSCustomObject]@{
                    Name = $item.BaseName
                    Command = $item.FullName
                    Location = $folder
                    Type = "Folder"
                }
            }
        }
    }
    
    return $startupItems | Sort-Object Name
}

function Test-KMDiskHealth {
    <#
    .SYNOPSIS
        Checks disk health using WMI.
    #>
    try {
        $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $health = @()
        
        foreach ($disk in $disks) {
            $volume = Get-Volume -DriveLetter $disk.DeviceID[0] -ErrorAction SilentlyContinue
            $health += [PSCustomObject]@{
                Drive = $disk.DeviceID
                HealthStatus = $volume.HealthStatus
                OperationalStatus = $volume.OperationalStatus -join ", "
                SizeGB = [math]::Round($disk.Size / 1GB, 2)
                FreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                PercentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
            }
        }
        
        return $health
    }
    catch {
        Write-KMLog -Message "Failed to check disk health: $_" -Level "Error"
        return @()
    }
}

function Get-KMEventLogSummary {
    <#
    .SYNOPSIS
        Gets a summary of recent critical events.
    
    .PARAMETER Hours
        Number of hours to look back.
    #>
    param(
        [int]$Hours = 24
    )
    
    $startTime = (Get-Date).AddHours(-$Hours)
    $summary = @{
        Critical = 0
        Error = 0
        Warning = 0
        RecentEvents = @()
    }
    
    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'System', 'Application'
            Level = 1, 2, 3  # Critical, Error, Warning
            StartTime = $startTime
        } -ErrorAction SilentlyContinue | Select-Object -First 20
        
        foreach ($event in $events) {
            switch ($event.Level) {
                1 { $summary.Critical++ }
                2 { $summary.Error++ }
                3 { $summary.Warning++ }
            }
            
            $summary.RecentEvents += [PSCustomObject]@{
                TimeCreated = $event.TimeCreated
                Level = $event.LevelDisplayName
                LogName = $event.LogName
                Source = $event.ProviderName
                Message = $event.Message.Substring(0, [Math]::Min(100, $event.Message.Length))
            }
        }
    }
    catch {
        Write-KMLog -Message "Failed to get event log summary: $_" -Level "Warning"
    }
    
    return $summary
}

#region Export Module Members

Export-ModuleMember -Function @(
    'Get-KMMaintenanceActions',
    'Start-KMMaintenanceTool',
    'Update-KMPackages',
    'Export-KMSystemSummary',
    'Start-KMDiskCleanup',
    'Get-KMDefaultMaintenanceActions',
    'Get-KMStartupItems',
    'Test-KMDiskHealth',
    'Get-KMEventLogSummary'
)

#endregion
