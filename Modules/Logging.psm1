function Initialize-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $logsPath = Join-Path -Path $RootPath -ChildPath 'Logs'
    if (-not (Test-Path -LiteralPath $logsPath)) {
        New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
    }

    $script:SessionLogPath = Join-Path -Path $logsPath -ChildPath ('kmworkbench-session-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -Path $script:SessionLogPath -ItemType File -Force | Out-Null
    Write-Log -Message 'Session log initialized.' -Action 'InitializeLog'
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Info', 'Warn', 'Error')]
        [string]$Level = 'Info',

        [string]$Action = 'General',

        [string]$Command = '',

        [string]$Success = '',

        [string]$OutputSummary = '',

        [string]$ErrorSummary = ''
    )

    if (-not $script:SessionLogPath) {
        throw 'Session log has not been initialized.'
    }

    $parts = @(
        ('timestamp={0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        ('level={0}' -f $Level.ToUpperInvariant())
        ('action={0}' -f $Action)
        ('message={0}' -f ($Message -replace '\r?\n', ' '))
        ('command={0}' -f ($Command -replace '\r?\n', ' '))
        ('success={0}' -f $Success)
        ('output={0}' -f ($OutputSummary -replace '\r?\n', ' '))
        ('error={0}' -f ($ErrorSummary -replace '\r?\n', ' '))
    )

    Add-Content -LiteralPath $script:SessionLogPath -Value ($parts -join ' | ')
}

function Write-ActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Result
    )

    $level = if ($Result.Success) { 'Info' } else { 'Error' }
    Write-Log -Level $level -Message $Result.Message -Action $Result.Action -Command $Result.Command -Success $Result.Success -OutputSummary $Result.OutputSummary -ErrorSummary $Result.ErrorSummary
}

function Get-SessionLogPath {
    [CmdletBinding()]
    param()

    return $script:SessionLogPath
}

function Get-SessionLogContent {
    [CmdletBinding()]
    param()

    if (-not $script:SessionLogPath -or -not (Test-Path -LiteralPath $script:SessionLogPath)) {
        return ''
    }

    return Get-Content -LiteralPath $script:SessionLogPath -Raw
}

function Export-CurrentSessionLog {
    [CmdletBinding()]
    param()

    $destinationPath = New-ExportPath -Prefix 'kmworkbench-session-export' -Extension 'log'
    Copy-Item -LiteralPath (Get-SessionLogPath) -Destination $destinationPath -Force
    return $destinationPath
}

Export-ModuleMember -Function Initialize-Log, Write-Log, Write-ActionLog, Get-SessionLogPath, Get-SessionLogContent, Export-CurrentSessionLog
