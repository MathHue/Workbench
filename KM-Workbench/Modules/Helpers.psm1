# ============================================================================
# Key Methods Workbench - Helpers Module
# ============================================================================
# Common helper functions used across the Workbench application

#region Administrative Functions

function Test-KMAdminRights {
    <#
    .SYNOPSIS
        Tests if the current PowerShell session has administrator privileges.
    
    .OUTPUTS
        Boolean indicating whether the user is running as administrator.
    #>
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-KMElevated {
    <#
    .SYNOPSIS
        Restarts the current script with administrator privileges.
    
    .PARAMETER ScriptPath
        Path to the script to run elevated.
    
    .PARAMETER Arguments
        Arguments to pass to the script.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [string]$Arguments = ""
    )
    
    Write-KMLog -Message "Requesting elevation..." -Level "Warning"
    
    try {
        $process = Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments" -PassThru -Wait
        return $process.ExitCode
    }
    catch {
        Write-KMLog -Message "Failed to elevate: $_" -Level "Error"
        return 1
    }
}

#endregion

#region Execution Functions

function Invoke-KMCommand {
    <#
    .SYNOPSIS
        Executes a command with proper error handling and output capture.
    
    .PARAMETER Command
        The command or executable to run.
    
    .PARAMETER Arguments
        Array of arguments to pass to the command.
    
    .PARAMETER WorkingDirectory
        Working directory for the command.
    
    .PARAMETER TimeoutSeconds
        Timeout for the command execution.
    
    .PARAMETER UseShellExecute
        Whether to use the shell to execute the command.
    
    .PARAMETER WindowStyle
        Window style for the process.
    
    .OUTPUTS
        Hashtable with Success, ExitCode, Output, and Error properties.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [string[]]$Arguments = @(),
        
        [string]$WorkingDirectory = $PWD,
        
        [int]$TimeoutSeconds = 300,
        
        [switch]$UseShellExecute,
        
        [System.Diagnostics.ProcessWindowStyle]$WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    )
    
    $result = @{
        Success = $false
        ExitCode = -1
        Output = ""
        Error = ""
        Duration = 0
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Command
        $psi.Arguments = $Arguments -join " "
        $psi.WorkingDirectory = $WorkingDirectory
        $psi.UseShellExecute = $UseShellExecute
        $psi.WindowStyle = $WindowStyle
        
        if (-not $UseShellExecute) {
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
        }
        
        Write-KMLog -Message "Executing: $Command $($Arguments -join ' ')" -Level "Info"
        
        $process = [System.Diagnostics.Process]::Start($psi)
        
        if (-not $UseShellExecute) {
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            
            if ($stdout) {
                $result.Output = $stdout
                Write-KMLog -Message "Output: $stdout" -Level "Info"
            }
            
            if ($stderr) {
                $result.Error = $stderr
                Write-KMLog -Message "Error: $stderr" -Level "Warning"
            }
        }
        
        # Wait for process to exit with timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            Write-KMLog -Message "Command timed out after $TimeoutSeconds seconds" -Level "Error"
            $process.Kill()
            $result.Error = "Command timed out after $TimeoutSeconds seconds"
        }
        else {
            $result.ExitCode = $process.ExitCode
            $result.Success = ($process.ExitCode -eq 0)
            
            if ($result.Success) {
                Write-KMLog -Message "Command completed successfully (Exit Code: $($process.ExitCode))" -Level "Success"
            }
            else {
                Write-KMLog -Message "Command failed (Exit Code: $($process.ExitCode))" -Level "Error"
            }
        }
        
        $process.Close()
    }
    catch {
        $result.Error = $_.Exception.Message
        Write-KMLog -Message "Command execution failed: $_" -Level "Error"
    }
    finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.ElapsedMilliseconds
    }
    
    return $result
}

function Invoke-KMPowerShell {
    <#
    .SYNOPSIS
        Executes a PowerShell script or command with proper handling.
    
    .PARAMETER ScriptBlock
        ScriptBlock to execute.
    
    .PARAMETER Command
        Command string to execute.
    
    .PARAMETER Arguments
        Arguments to pass.
    #>
    param(
        [scriptblock]$ScriptBlock,
        
        [string]$Command,
        
        [hashtable]$Arguments = @{}
    )
    
    $result = @{
        Success = $false
        Output = $null
        Error = $null
    }
    
    try {
        if ($ScriptBlock) {
            $result.Output = & $ScriptBlock @Arguments
        }
        elseif ($Command) {
            $result.Output = Invoke-Expression $Command
        }
        
        $result.Success = $true
    }
    catch {
        $result.Error = $_
        Write-KMLog -Message "PowerShell execution failed: $_" -Level "Error"
    }
    
    return $result
}

#endregion

#region System Information

function Get-KMSystemInfo {
    <#
    .SYNOPSIS
        Retrieves comprehensive system information.
    
    .OUTPUTS
        Hashtable containing system information.
    #>
    $info = @{}
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $computer = Get-CimInstance Win32_ComputerSystem
        $processor = Get-CimInstance Win32_Processor
        $bios = Get-CimInstance Win32_BIOS
        
        $info.ComputerName = $env:COMPUTERNAME
        $info.Username = $env:USERNAME
        $info.Domain = $env:USERDOMAIN
        $info.OSName = $os.Caption
        $info.OSVersion = $os.Version
        $info.OSArchitecture = $os.OSArchitecture
        $info.InstallDate = $os.InstallDate
        $info.LastBootTime = $os.LastBootUpTime
        $info.TotalMemoryGB = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        $info.AvailableMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $info.Processor = $processor.Name
        $info.ProcessorCores = $processor.NumberOfCores
        $info.BiosVersion = $bios.SMBIOSBIOSVersion
        $info.BiosSerial = $bios.SerialNumber
        $info.IsAdmin = Test-KMAdminRights
        $info.PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        
        # Calculate uptime
        $uptime = (Get-Date) - $os.LastBootUpTime
        $info.Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        
        # Check package managers
        $info.WingetInstalled = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        $info.ChocolateyInstalled = [bool](Get-Command choco -ErrorAction SilentlyContinue)
    }
    catch {
        Write-KMLog -Message "Failed to get system info: $_" -Level "Error"
    }
    
    return $info
}

function Get-KMDiskSpace {
    <#
    .SYNOPSIS
        Gets disk space information for all drives.
    #>
    $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    
    $driveInfo = foreach ($drive in $drives) {
        [PSCustomObject]@{
            Drive = $drive.DeviceID
            Label = $drive.VolumeName
            TotalGB = [math]::Round($drive.Size / 1GB, 2)
            FreeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            UsedGB = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
            PercentFree = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
        }
    }
    
    return $driveInfo
}

#endregion

#region File Operations

function Test-KMPath {
    <#
    .SYNOPSIS
        Tests if a path exists and optionally creates it.
    
    .PARAMETER Path
        Path to test.
    
    .PARAMETER Create
        Create the path if it doesn't exist.
    
    .PARAMETER ItemType
        Type of item to create (Directory or File).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Create,
        
        [ValidateSet("Directory", "File")]
        [string]$ItemType = "Directory"
    )
    
    $exists = Test-Path $Path
    
    if (-not $exists -and $Create) {
        try {
            if ($ItemType -eq "Directory") {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
            else {
                New-Item -ItemType File -Path $Path -Force | Out-Null
            }
            Write-KMLog -Message "Created: $Path" -Level "Info"
            return $true
        }
        catch {
            Write-KMLog -Message "Failed to create $Path : $_" -Level "Error"
            return $false
        }
    }
    
    return $exists
}

function Backup-KMItem {
    <#
    .SYNOPSIS
        Creates a backup of a file or directory.
    
    .PARAMETER Path
        Path to backup.
    
    .PARAMETER BackupDirectory
        Directory to store the backup.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [string]$BackupDirectory = "$env:TEMP\KM-Workbench\Backups"
    )
    
    try {
        if (-not (Test-Path $Path)) {
            Write-KMLog -Message "Cannot backup non-existent path: $Path" -Level "Warning"
            return $false
        }
        
        Test-KMPath -Path $BackupDirectory -Create | Out-Null
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $itemName = Split-Path $Path -Leaf
        $backupName = "$itemName-$timestamp.bak"
        $backupPath = Join-Path $BackupDirectory $backupName
        
        Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
        Write-KMLog -Message "Created backup: $backupPath" -Level "Info"
        
        return $true
    }
    catch {
        Write-KMLog -Message "Backup failed: $_" -Level "Error"
        return $false
    }
}

#endregion

#region Network Functions

function Test-KMInternetConnection {
    <#
    .SYNOPSIS
        Tests internet connectivity.
    
    .PARAMETER TestUrl
        URL to test against.
    
    .PARAMETER TimeoutSeconds
        Timeout for the test.
    #>
    param(
        [string]$TestUrl = "https://www.google.com",
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $TestUrl -Method Head -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-KMPublicIP {
    <#
    .SYNOPSIS
        Gets the public IP address.
    #>
    try {
        $ip = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10 -ErrorAction Stop
        return $ip
    }
    catch {
        Write-KMLog -Message "Failed to get public IP: $_" -Level "Warning"
        return $null
    }
}

#endregion

#region Registry Helpers

function Get-KMRegistryValue {
    <#
    .SYNOPSIS
        Safely gets a registry value.
    
    .PARAMETER Path
        Registry path.
    
    .PARAMETER Name
        Value name.
    
    .PARAMETER DefaultValue
        Default value if not found.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [object]$DefaultValue = $null
    )
    
    try {
        $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $value.$Name
    }
    catch {
        return $DefaultValue
    }
}

function Set-KMRegistryValue {
    <#
    .SYNOPSIS
        Safely sets a registry value.
    
    .PARAMETER Path
        Registry path.
    
    .PARAMETER Name
        Value name.
    
    .PARAMETER Value
        Value to set.
    
    .PARAMETER Type
        Registry value type.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [object]$Value,
        
        [ValidateSet("String", "DWord", "QWord", "Binary", "MultiString", "ExpandString")]
        [string]$Type = "DWord"
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-KMLog -Message "Set registry: $Path\$Name = $Value" -Level "Info"
        return $true
    }
    catch {
        Write-KMLog -Message "Failed to set registry value: $_" -Level "Error"
        return $false
    }
}

#endregion

#region Service Helpers

function Restart-KMService {
    <#
    .SYNOPSIS
        Safely restarts a Windows service.
    
    .PARAMETER ServiceName
        Name of the service.
    
    .PARAMETER TimeoutSeconds
        Timeout for restart operation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        
        [int]$TimeoutSeconds = 60
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        
        if ($service.Status -eq "Running") {
            Write-KMLog -Message "Stopping service: $ServiceName" -Level "Info"
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds($TimeoutSeconds))
        }
        
        Write-KMLog -Message "Starting service: $ServiceName" -Level "Info"
        Start-Service -Name $ServiceName -ErrorAction Stop
        $service.WaitForStatus("Running", [TimeSpan]::FromSeconds($TimeoutSeconds))
        
        Write-KMLog -Message "Service $ServiceName restarted successfully" -Level "Success"
        return $true
    }
    catch {
        Write-KMLog -Message "Failed to restart service $ServiceName : $_" -Level "Error"
        return $false
    }
}

#endregion

#region Progress Functions

function Show-KMProgress {
    <#
    .SYNOPSIS
        Displays a simple progress dialog for long-running operations.
    
    .PARAMETER Activity
        Activity description.
    
    .PARAMETER Status
        Current status.
    
    .PARAMETER PercentComplete
        Percentage complete.
    #>
    param(
        [string]$Activity = "Working...",
        [string]$Status = "",
        [int]$PercentComplete = -1
    )
    
    if ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
    else {
        Write-Progress -Activity $Activity -Status $Status
    }
}

function Hide-KMProgress {
    <#
    .SYNOPSIS
        Hides the progress bar.
    #>
    Write-Progress -Activity "*" -Completed
}

#endregion

#region Export Module Members

Export-ModuleMember -Function @(
    'Test-KMAdminRights',
    'Invoke-KMElevated',
    'Invoke-KMCommand',
    'Invoke-KMPowerShell',
    'Get-KMSystemInfo',
    'Get-KMDiskSpace',
    'Test-KMPath',
    'Backup-KMItem',
    'Test-KMInternetConnection',
    'Get-KMPublicIP',
    'Get-KMRegistryValue',
    'Set-KMRegistryValue',
    'Restart-KMService',
    'Show-KMProgress',
    'Hide-KMProgress'
)

#endregion
