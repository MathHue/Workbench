# ============================================================================
# Key Methods Workbench - Repairs Module
# ============================================================================
# Windows repair and remediation functionality

$script:RepairCategories = @("Safe", "Advanced", "Dangerous")

function Get-KMRepairActions {
    <#
    .SYNOPSIS
        Gets the repair actions from configuration.
    
    .PARAMETER Category
        Filter by category/danger level.
    
    .PARAMETER RequiresAdmin
        Filter by admin requirement.
    #>
    param(
        [ValidateSet("safe", "advanced", "dangerous")]
        [string]$Category = $null,
        
        [bool]$RequiresAdmin = $null
    )
    
    $configPath = Join-Path $script:ConfigPath "repair-actions.json"
    
    try {
        if (Test-Path $configPath) {
            $actions = Get-Content $configPath -Raw | ConvertFrom-Json
        }
        else {
            $actions = Get-KMDefaultRepairActions
        }
        
        if ($Category) {
            $actions = $actions | Where-Object { $_.dangerLevel -eq $Category }
        }
        
        if ($null -ne $RequiresAdmin) {
            $actions = $actions | Where-Object { $_.requiresAdmin -eq $RequiresAdmin }
        }
        
        return $actions
    }
    catch {
        Write-KMLog -Message "Failed to get repair actions: $_" -Level "Error"
        return @()
    }
}

function Invoke-KMRepair {
    <#
    .SYNOPSIS
        Executes a repair action.
    
    .PARAMETER RepairAction
        Repair action definition.
    
    .PARAMETER ConfirmDangerous
        Confirm dangerous actions.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$RepairAction,
        
        [switch]$ConfirmDangerous
    )
    
    $actionName = $RepairAction.name
    $dangerLevel = $RepairAction.dangerLevel
    $requiresConfirmation = $RepairAction.requiresConfirmation
    
    Write-KMLog -Message "Starting repair: $actionName" -Level "Info"
    
    # Check for confirmation on dangerous actions
    if ($dangerLevel -eq "dangerous" -and $requiresConfirmation -and -not $ConfirmDangerous) {
        $message = "WARNING: This is a DANGEROUS action that may affect system stability.`n`n" +
                   "Action: $actionName`n" +
                   "Description: $($RepairAction.description)`n`n" +
                   "Do you want to continue?"
        
        return @{
            Success = $false
            RequiresConfirmation = $true
            Message = $message
        }
    }
    
    # Check admin requirement
    if ($RepairAction.requiresAdmin -and -not (Test-KMAdminRights)) {
        Write-KMLog -Message "$actionName requires administrator rights" -Level "Error"
        return @{ Success = $false; Error = "Administrator rights required" }
    }
    
    # Execute based on command type
    $result = @{ Success = $false; Output = ""; Error = ""; RequiresReboot = $RepairAction.rebootRecommended }
    
    try {
        switch ($RepairAction.commandType) {
            "cmd" {
                $timeout = if ($RepairAction.timeoutSeconds) { $RepairAction.timeoutSeconds } else { 300 }
                $cmdResult = Invoke-KMCommand -Command $RepairAction.command -Arguments $RepairAction.arguments -TimeoutSeconds $timeout
                $result.Success = $cmdResult.Success
                $result.Output = $cmdResult.Output
                $result.Error = $cmdResult.Error
            }
            "powershell" {
                $psResult = Invoke-KMPowerShell -Command $RepairAction.scriptBlock
                $result.Success = $psResult.Success
                $result.Output = $psResult.Output
                $result.Error = $psResult.Error
            }
            "service" {
                $result.Success = Restart-KMService -ServiceName $RepairAction.serviceName
            }
            default {
                # Default to command execution
                $cmdResult = Invoke-KMCommand -Command $RepairAction.command -Arguments $RepairAction.arguments
                $result.Success = $cmdResult.Success
                $result.Output = $cmdResult.Output
                $result.Error = $cmdResult.Error
            }
        }
    }
    catch {
        $result.Error = $_.Exception.Message
        Write-KMLog -Message "Repair failed: $_" -Level "Error"
    }
    
    if ($result.Success) {
        Write-KMLog -Message "Repair completed: $actionName" -Level "Success"
    }
    else {
        Write-KMLog -Message "Repair failed: $actionName - $($result.Error)" -Level "Error"
    }
    
    return $result
}

function Invoke-KMRepairBatch {
    <#
    .SYNOPSIS
        Executes multiple repair actions.
    
    .PARAMETER RepairActions
        Array of repair actions.
    
    .PARAMETER OnProgress
        Progress callback scriptblock.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$RepairActions,
        
        [scriptblock]$OnProgress = $null
    )
    
    $results = @{
        Total = $RepairActions.Count
        Success = 0
        Failed = 0
        RequiresReboot = $false
        Details = @()
    }
    
    $counter = 0
    
    foreach ($action in $RepairActions) {
        $counter++
        $percentComplete = ($counter / $results.Total) * 100
        
        Show-KMProgress -Activity "Running Repairs" -Status "$counter of $($results.Total): $($action.name)" -PercentComplete $percentComplete
        
        if ($OnProgress) {
            & $OnProgress -Activity "Running Repairs" -Status "$counter of $($results.Total): $($action.name)" -PercentComplete $percentComplete
        }
        
        $result = Invoke-KMRepair -RepairAction $action -ConfirmDangerous
        $result.ActionName = $action.name
        $results.Details += $result
        
        if ($result.RequiresReboot) {
            $results.RequiresReboot = $true
        }
        
        if ($result.Success) {
            $results.Success++
        }
        else {
            $results.Failed++
        }
    }
    
    Hide-KMProgress
    
    Write-KMLog -Message "Repair batch complete. Success: $($results.Success), Failed: $($results.Failed)" -Level "Info"
    
    return $results
}

#region Network Repairs

function Repair-KMNetworkStack {
    <#
    .SYNOPSIS
        Performs a comprehensive network stack repair.
    #>
    param(
        [switch]$IncludeWinsock = $true,
        [switch]$IncludeIPReset = $true
    )
    
    Write-KMLog -Message "Starting network stack repair..." -Level "Info"
    
    $results = @{ Success = $true; Actions = @() }
    
    # Flush DNS
    Write-KMLog -Message "Flushing DNS cache..." -Level "Info"
    $dnsResult = Invoke-KMCommand -Command "ipconfig" -Arguments @("/flushdns")
    $results.Actions += @{ Action = "Flush DNS"; Result = $dnsResult }
    
    # Register DNS
    Write-KMLog -Message "Registering DNS..." -Level "Info"
    $regResult = Invoke-KMCommand -Command "ipconfig" -Arguments @("/registerdns")
    $results.Actions += @{ Action = "Register DNS"; Result = $regResult }
    
    # Release and Renew
    Write-KMLog -Message "Releasing and renewing IP..." -Level "Info"
    $releaseResult = Invoke-KMCommand -Command "ipconfig" -Arguments @("/release")
    $renewResult = Invoke-KMCommand -Command "ipconfig" -Arguments @("/renew")
    $results.Actions += @{ Action = "Release IP"; Result = $releaseResult }
    $results.Actions += @{ Action = "Renew IP"; Result = $renewResult }
    
    if ($IncludeWinsock) {
        Write-KMLog -Message "Resetting Winsock..." -Level "Info"
        $winsockResult = Invoke-KMCommand -Command "netsh" -Arguments @("winsock", "reset")
        $results.Actions += @{ Action = "Reset Winsock"; Result = $winsockResult }
        $results.RequiresReboot = $true
    }
    
    if ($IncludeIPReset) {
        Write-KMLog -Message "Resetting IP stack..." -Level "Info"
        $ipResult = Invoke-KMCommand -Command "netsh" -Arguments @("int", "ip", "reset")
        $results.Actions += @{ Action = "Reset IP Stack"; Result = $ipResult }
        $results.RequiresReboot = $true
    }
    
    Write-KMLog -Message "Network stack repair complete" -Level "Success"
    
    return $results
}

function Reset-KMWindowsUpdate {
    <#
    .SYNOPSIS
        Resets Windows Update components.
    #>
    
    Write-KMLog -Message "Starting Windows Update reset..." -Level "Warning"
    
    $results = @{ Success = $true; Actions = @(); RequiresReboot = $true }
    
    # Stop Windows Update services
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    
    foreach ($service in $services) {
        Write-KMLog -Message "Stopping service: $service" -Level "Info"
        $stopResult = Invoke-KMCommand -Command "net" -Arguments @("stop", $service)
        $results.Actions += @{ Action = "Stop $service"; Result = $stopResult }
    }
    
    # Rename SoftwareDistribution folders
    $folders = @(
        "$env:SystemRoot\SoftwareDistribution",
        "$env:SystemRoot\System32\catroot2"
    )
    
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            $backupName = "$folder.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-KMLog -Message "Backing up $folder to $backupName" -Level "Info"
            try {
                Rename-Item -Path $folder -NewName $backupName -Force
                Write-KMLog -Message "Renamed $folder" -Level "Success"
            }
            catch {
                Write-KMLog -Message "Failed to rename $folder : $_" -Level "Error"
                $results.Success = $false
            }
        }
    }
    
    # Restart services
    foreach ($service in ($services | Sort-Object { $_ -eq "msiserver" })) {
        Write-KMLog -Message "Starting service: $service" -Level "Info"
        $startResult = Invoke-KMCommand -Command "net" -Arguments @("start", $service)
        $results.Actions += @{ Action = "Start $service"; Result = $startResult }
    }
    
    Write-KMLog -Message "Windows Update reset complete. Reboot recommended." -Level "Success"
    
    return $results
}

#endregion

#region System File Repairs

function Repair-KMSystemFiles {
    <#
    .SYNOPSIS
        Runs SFC and DISM repairs.
    #>
    param(
        [switch]$IncludeDismCleanup = $false
    )
    
    Write-KMLog -Message "Starting system file repair..." -Level "Info"
    
    $results = @{ Success = $true; Actions = @() }
    
    # DISM CheckHealth
    Write-KMLog -Message "Running DISM CheckHealth..." -Level "Info"
    $dismCheck = Invoke-KMCommand -Command "DISM" -Arguments @("/Online", "/Cleanup-Image", "/CheckHealth") -TimeoutSeconds 300
    $results.Actions += @{ Action = "DISM CheckHealth"; Result = $dismCheck }
    
    # DISM ScanHealth
    Write-KMLog -Message "Running DISM ScanHealth..." -Level "Info"
    $dismScan = Invoke-KMCommand -Command "DISM" -Arguments @("/Online", "/Cleanup-Image", "/ScanHealth") -TimeoutSeconds 600
    $results.Actions += @{ Action = "DISM ScanHealth"; Result = $dismScan }
    
    # DISM RestoreHealth
    Write-KMLog -Message "Running DISM RestoreHealth..." -Level "Info"
    $dismRestore = Invoke-KMCommand -Command "DISM" -Arguments @("/Online", "/Cleanup-Image", "/RestoreHealth") -TimeoutSeconds 1800
    $results.Actions += @{ Action = "DISM RestoreHealth"; Result = $dismRestore }
    
    if ($IncludeDismCleanup) {
        Write-KMLog -Message "Running DISM Component Cleanup..." -Level "Info"
        $dismCleanup = Invoke-KMCommand -Command "DISM" -Arguments @("/Online", "/Cleanup-Image", "/StartComponentCleanup") -TimeoutSeconds 600
        $results.Actions += @{ Action = "DISM Component Cleanup"; Result = $dismCleanup }
    }
    
    # SFC Scan
    Write-KMLog -Message "Running SFC /scannow..." -Level "Info"
    $sfc = Invoke-KMCommand -Command "sfc" -Arguments @("/scannow") -TimeoutSeconds 1800
    $results.Actions += @{ Action = "SFC Scan"; Result = $sfc }
    
    Write-KMLog -Message "System file repair complete" -Level "Success"
    
    return $results
}

#endregion

#region Default Repair Actions

function Get-KMDefaultRepairActions {
    return @(
        # Safe Repairs
        @{
            name = "Flush DNS Cache"
            category = "Network"
            description = "Clears the DNS resolver cache"
            command = "ipconfig"
            arguments = @("/flushdns")
            dangerLevel = "safe"
            requiresAdmin = $false
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Register DNS"
            category = "Network"
            description = "Refreshes all DHCP leases and re-registers DNS names"
            command = "ipconfig"
            arguments = @("/registerdns")
            dangerLevel = "safe"
            requiresAdmin = $false
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Release IP"
            category = "Network"
            description = "Releases the current IP address"
            command = "ipconfig"
            arguments = @("/release")
            dangerLevel = "safe"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Renew IP"
            category = "Network"
            description = "Renews the IP address from DHCP"
            command = "ipconfig"
            arguments = @("/renew")
            dangerLevel = "safe"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "GPUpdate /Force"
            category = "System"
            description = "Forces a Group Policy update"
            command = "gpupdate"
            arguments = @("/force")
            dangerLevel = "safe"
            requiresAdmin = $false
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Clear Temp Files"
            category = "Maintenance"
            description = "Removes temporary files"
            command = "powershell"
            scriptBlock = "Remove-Item -Path '$env:TEMP\*' -Recurse -Force -ErrorAction SilentlyContinue"
            dangerLevel = "safe"
            requiresAdmin = $false
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Restart Print Spooler"
            category = "Services"
            description = "Restarts the print spooler service"
            commandType = "service"
            serviceName = "spooler"
            dangerLevel = "safe"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        @{
            name = "Restart BITS"
            category = "Services"
            description = "Restarts Background Intelligent Transfer Service"
            commandType = "service"
            serviceName = "bits"
            dangerLevel = "safe"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            enabled = $true
        },
        
        # Advanced Repairs
        @{
            name = "Reset Winsock"
            category = "Network"
            description = "Resets the Windows Socket catalog"
            command = "netsh"
            arguments = @("winsock", "reset")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $true
            enabled = $true
        },
        @{
            name = "Reset IP Stack"
            category = "Network"
            description = "Resets the TCP/IP stack"
            command = "netsh"
            arguments = @("int", "ip", "reset")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $true
            enabled = $true
        },
        @{
            name = "DISM CheckHealth"
            category = "System Files"
            description = "Checks the health of the Windows image"
            command = "DISM"
            arguments = @("/Online", "/Cleanup-Image", "/CheckHealth")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            timeoutSeconds = 300
            enabled = $true
        },
        @{
            name = "DISM ScanHealth"
            category = "System Files"
            description = "Scans the Windows image for corruption"
            command = "DISM"
            arguments = @("/Online", "/Cleanup-Image", "/ScanHealth")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            timeoutSeconds = 600
            enabled = $true
        },
        @{
            name = "DISM RestoreHealth"
            category = "System Files"
            description = "Repairs the Windows image"
            command = "DISM"
            arguments = @("/Online", "/Cleanup-Image", "/RestoreHealth")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            timeoutSeconds = 1800
            enabled = $true
        },
        @{
            name = "SFC Scan"
            category = "System Files"
            description = "Scans and repairs system files"
            command = "sfc"
            arguments = @("/scannow")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            timeoutSeconds = 1800
            enabled = $true
        },
        @{
            name = "CHKDSK Scan"
            category = "Disk"
            description = "Checks disk for errors (read-only scan)"
            command = "chkdsk"
            arguments = @("/scan")
            dangerLevel = "advanced"
            requiresAdmin = $true
            requiresConfirmation = $false
            rebootRecommended = $false
            timeoutSeconds = 600
            enabled = $true
        },
        
        # Dangerous Repairs
        @{
            name = "CHKDSK /F"
            category = "Disk"
            description = "Fixes disk errors (requires reboot)"
            command = "chkdsk"
            arguments = @("/f")
            dangerLevel = "dangerous"
            requiresAdmin = $true
            requiresConfirmation = $true
            rebootRecommended = $true
            warningText = "This will check and fix file system errors. A reboot is required."
            enabled = $true
        },
        @{
            name = "CHKDSK /R"
            category = "Disk"
            description = "Locates bad sectors and recovers readable info"
            command = "chkdsk"
            arguments = @("/r")
            dangerLevel = "dangerous"
            requiresAdmin = $true
            requiresConfirmation = $true
            rebootRecommended = $true
            warningText = "This is a deep disk scan that may take hours. A reboot is required."
            enabled = $true
        },
        @{
            name = "Reset Windows Update"
            category = "System"
            description = "Completely resets Windows Update components"
            commandType = "powershell"
            scriptBlock = "Reset-KMWindowsUpdate | Out-String"
            dangerLevel = "dangerous"
            requiresAdmin = $true
            requiresConfirmation = $true
            rebootRecommended = $true
            warningText = "This will stop Windows Update services and reset the update cache."
            enabled = $true
        }
    )
}

#endregion

#region Export Module Members

Export-ModuleMember -Function @(
    'Get-KMRepairActions',
    'Invoke-KMRepair',
    'Invoke-KMRepairBatch',
    'Repair-KMNetworkStack',
    'Reset-KMWindowsUpdate',
    'Repair-KMSystemFiles'
)

#endregion
