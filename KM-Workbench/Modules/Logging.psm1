# ============================================================================
# Key Methods Workbench - Logging Module
# ============================================================================
# Centralized logging functionality for the Workbench application

$script:LogFile = $null
$script:LogDirectory = $null
$script:LogBuffer = [System.Collections.ArrayList]::new()
$script:MaxBufferSize = 100

function Initialize-KMLogging {
    <#
    .SYNOPSIS
        Initializes the logging system.
    
    .PARAMETER LogPath
        Directory path for log files.
    
    .PARAMETER LogFileName
        Optional custom log file name.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        
        [string]$LogFileName = $null
    )
    
    $script:LogDirectory = $LogPath
    
    # Ensure log directory exists
    if (-not (Test-Path $script:LogDirectory)) {
        New-Item -ItemType Directory -Path $script:LogDirectory -Force | Out-Null
    }
    
    # Generate log filename if not provided
    if (-not $LogFileName) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $LogFileName = "KM-Workbench-$timestamp.log"
    }
    
    $script:LogFile = Join-Path $script:LogDirectory $LogFileName
    
    # Create log file with header
    $header = @"
================================================================================
Key Methods Workbench Log File
Session Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Log File: $script:LogFile
================================================================================

"@
    
    Set-Content -Path $script:LogFile -Value $header -Encoding UTF8
    
    Write-Host "Logging initialized: $script:LogFile" -ForegroundColor Green
}

function Write-KMLog {
    <#
    .SYNOPSIS
        Writes a log entry to the current log file.
    
    .PARAMETER Message
        The message to log.
    
    .PARAMETER Level
        Log level: Info, Warning, Error, Success, Debug.
    
    .PARAMETER NoConsole
        Don't write to console (only to file).
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Level = "Info",
        
        [switch]$NoConsole
    )
    
    process {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$($Level.ToUpper().PadRight(7))] $Message"
        
        # Write to file if initialized
        if ($script:LogFile -and (Test-Path (Split-Path $script:LogFile))) {
            Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        
        # Add to buffer for UI display
        $null = $script:LogBuffer.Add($logEntry)
        if ($script:LogBuffer.Count -gt $script:MaxBufferSize) {
            $script:LogBuffer.RemoveAt(0)
        }
        
        # Write to console unless suppressed
        if (-not $NoConsole) {
            switch ($Level) {
                "Info"    { Write-Host $logEntry -ForegroundColor Cyan }
                "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
                "Error"   { Write-Host $logEntry -ForegroundColor Red }
                "Success" { Write-Host $logEntry -ForegroundColor Green }
                "Debug"   { Write-Host $logEntry -ForegroundColor Gray }
            }
        }
    }
}

function Get-KMLogContent {
    <#
    .SYNOPSIS
        Gets the current log content.
    
    .PARAMETER FromBuffer
        Return from memory buffer instead of file.
    
    .PARAMETER Lines
        Number of lines to return (from end).
    #>
    param(
        [switch]$FromBuffer,
        [int]$Lines = 0
    )
    
    if ($FromBuffer) {
        return $script:LogBuffer -join "`r`n"
    }
    
    if ($script:LogFile -and (Test-Path $script:LogFile)) {
        if ($Lines -gt 0) {
            return Get-Content -Path $script:LogFile -Tail $Lines -Encoding UTF8 -Raw
        }
        else {
            return Get-Content -Path $script:LogFile -Encoding UTF8 -Raw
        }
    }
    
    return "No log file initialized."
}

function Get-KMLogFilePath {
    <#
    .SYNOPSIS
        Returns the current log file path.
    #>
    return $script:LogFile
}

function Clear-KMLogs {
    <#
    .SYNOPSIS
        Clears the current log file and buffer.
    #>
    $script:LogBuffer.Clear()
    
    if ($script:LogFile -and (Test-Path $script:LogFile)) {
        $header = @"
================================================================================
Key Methods Workbench Log File
Session Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Log File: $script:LogFile
================================================================================

Log cleared at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"@
        $header | Set-Content -Path $script:LogFile -Encoding UTF8
    }
    
    Write-KMLog -Message "Log cleared" -Level "Info" -NoConsole
}

function Export-KMLogs {
    <#
    .SYNOPSIS
        Exports logs to a specified file path.
    
    .PARAMETER DestinationPath
        Path to export logs to.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    try {
        $content = Get-KMLogContent
        $content | Set-Content -Path $DestinationPath -Encoding UTF8 -Force
        Write-KMLog -Message "Logs exported to: $DestinationPath" -Level "Success"
        return $true
    }
    catch {
        Write-KMLog -Message "Failed to export logs: $_" -Level "Error"
        return $false
    }
}

function Get-KMLogFiles {
    <#
    .SYNOPSIS
        Lists all log files in the log directory.
    #>
    if ($script:LogDirectory -and (Test-Path $script:LogDirectory)) {
        return Get-ChildItem -Path $script:LogDirectory -Filter "KM-Workbench-*.log" | 
               Sort-Object LastWriteTime -Descending |
               Select-Object Name, LastWriteTime, @{N="SizeKB";E={[math]::Round($_.Length/1KB,2)}}
    }
    return @()
}

function Remove-KMOldLogs {
    <#
    .SYNOPSIS
        Removes log files older than specified days.
    
    .PARAMETER Days
        Age in days for log files to remove.
    #>
    param(
        [int]$Days = 30
    )
    
    if ($script:LogDirectory -and (Test-Path $script:LogDirectory)) {
        $cutoff = (Get-Date).AddDays(-$Days)
        $oldLogs = Get-ChildItem -Path $script:LogDirectory -Filter "KM-Workbench-*.log" | 
                   Where-Object { $_.LastWriteTime -lt $cutoff }
        
        foreach ($log in $oldLogs) {
            Remove-Item -Path $log.FullName -Force
            Write-KMLog -Message "Removed old log file: $($log.Name)" -Level "Info"
        }
        
        return $oldLogs.Count
    }
    return 0
}

#region Export Module Members

Export-ModuleMember -Function @(
    'Initialize-KMLogging',
    'Write-KMLog',
    'Get-KMLogContent',
    'Get-KMLogFilePath',
    'Clear-KMLogs',
    'Export-KMLogs',
    'Get-KMLogFiles',
    'Remove-KMOldLogs'
)

#endregion
