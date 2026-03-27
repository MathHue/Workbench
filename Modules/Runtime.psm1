function Get-ApplicationCatalog {
    [CmdletBinding()]
    param()

    return @(Get-JsonConfig -Path (Get-AppPath -Name 'ApplicationsConfig'))
}

function Get-RepairCatalog {
    [CmdletBinding()]
    param()

    return @(Get-JsonConfig -Path (Get-AppPath -Name 'RepairsConfig'))
}

function Get-PresetCatalog {
    [CmdletBinding()]
    param()

    return @(Get-JsonConfig -Path (Get-AppPath -Name 'PresetsConfig'))
}

function Get-MaintenanceCatalog {
    [CmdletBinding()]
    param()

    return @(Get-JsonConfig -Path (Get-AppPath -Name 'MaintenanceConfig'))
}

function Get-TweakCatalog {
    [CmdletBinding()]
    param()

    return @(Get-JsonConfig -Path (Get-AppPath -Name 'TweaksConfig'))
}

function Invoke-WorkbenchCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [ValidateSet('Cmd', 'PowerShell', 'ShellExecute')]
        [string]$Shell = 'Cmd'
    )

    $result = [pscustomobject]@{
        Action        = $Action
        Command       = $Command
        Success       = $false
        ExitCode      = -1
        Output        = ''
        Error         = ''
        OutputSummary = ''
        ErrorSummary  = ''
        Message       = ''
    }

    try {
        if ($Shell -eq 'ShellExecute') {
            Start-Process -FilePath $Command | Out-Null
            $result.Success = $true
            $result.ExitCode = 0
            $result.Output = 'Launched.'
            $result.OutputSummary = 'Launched successfully.'
            $result.Message = "$Action launched."
            Write-ActionLog -Result $result
            return $result
        }

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true

        switch ($Shell) {
            'PowerShell' {
                $escapedCommand = $Command.Replace('"', '\"')
                $processInfo.FileName = 'powershell.exe'
                $processInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "{0}"' -f $escapedCommand
            }
            default {
                $processInfo.FileName = 'cmd.exe'
                $processInfo.Arguments = '/c {0}' -f $Command
            }
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $result.ExitCode = $process.ExitCode
        $result.Output = $stdout.Trim()
        $result.Error = $stderr.Trim()
        $result.Success = ($process.ExitCode -eq 0)
        $result.OutputSummary = if ([string]::IsNullOrWhiteSpace($result.Output)) { 'No output.' } else { $result.Output.Substring(0, [Math]::Min(300, $result.Output.Length)) }
        $result.ErrorSummary = if ([string]::IsNullOrWhiteSpace($result.Error)) { '' } else { $result.Error.Substring(0, [Math]::Min(300, $result.Error.Length)) }
        $result.Message = if ($result.Success) { "$Action completed successfully." } else { "$Action failed with exit code $($result.ExitCode)." }
    }
    catch {
        $result.Error = $_.Exception.Message
        $result.ErrorSummary = $_.Exception.Message
        $result.Message = "$Action failed to start."
    }

    Write-ActionLog -Result $result
    return $result
}

function Get-AppInstallCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$App,

        [ValidateSet('Install', 'Uninstall')]
        [string]$Operation
    )

    switch ($App.provider) {
        'Winget' {
            if ($Operation -eq 'Install') {
                return [pscustomobject]@{ Shell = 'Cmd'; Command = 'winget install --id "{0}" --exact --accept-package-agreements --accept-source-agreements --silent' -f $App.packageId }
            }

            return [pscustomobject]@{ Shell = 'Cmd'; Command = 'winget uninstall --id "{0}" --exact --silent' -f $App.packageId }
        }
        'Chocolatey' {
            if ($Operation -eq 'Install') {
                return [pscustomobject]@{ Shell = 'Cmd'; Command = 'choco install {0} -y' -f $App.packageId }
            }

            return [pscustomobject]@{ Shell = 'Cmd'; Command = 'choco uninstall {0} -y' -f $App.packageId }
        }
        default {
            return [pscustomobject]@{
                Shell   = if ($App.shell) { $App.shell } else { 'PowerShell' }
                Command = if ($Operation -eq 'Install') { $App.installCommand } else { $App.uninstallCommand }
            }
        }
    }
}

function Invoke-ApplicationAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$App,

        [ValidateSet('Install', 'Uninstall')]
        [string]$Operation
    )

    $definition = Get-AppInstallCommand -App $App -Operation $Operation
    return Invoke-WorkbenchCommand -Action ('{0} {1}' -f $Operation, $App.name) -Command $definition.Command -Shell $definition.Shell
}

function Invoke-RepairAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Repair
    )

    return Invoke-WorkbenchCommand -Action $Repair.name -Command $Repair.command -Shell $Repair.shell
}

function Invoke-TweakAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Tweak
    )

    $result = Invoke-WorkbenchCommand -Action $Tweak.name -Command $Tweak.command -Shell $Tweak.shell
    if ($result.Success) {
        Invoke-WorkbenchCommand -Action 'Refresh Explorer' -Command "Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Process explorer.exe" -Shell 'PowerShell' | Out-Null
    }
    return $result
}

function Invoke-MaintenanceAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$ActionItem
    )

    return Invoke-WorkbenchCommand -Action $ActionItem.name -Command $ActionItem.command -Shell $ActionItem.shell
}

function Invoke-UpgradeSupportedPackages {
    [CmdletBinding()]
    param()

    $results = @()

    if (Test-CommandAvailable -Name 'winget.exe') {
        $results += Invoke-WorkbenchCommand -Action 'Upgrade all winget packages' -Command 'winget upgrade --all --accept-package-agreements --accept-source-agreements --silent' -Shell 'Cmd'
    }

    if (Test-CommandAvailable -Name 'choco.exe') {
        $results += Invoke-WorkbenchCommand -Action 'Upgrade all chocolatey packages' -Command 'choco upgrade all -y' -Shell 'Cmd'
    }

    return $results
}

function Open-LogsFolder {
    [CmdletBinding()]
    param()

    $logsPath = Get-AppPath -Name 'Logs'
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $logsPath) | Out-Null
    $result = [pscustomobject]@{
        Action        = 'Open Logs Folder'
        Command       = $logsPath
        Success       = $true
        ExitCode      = 0
        Output        = 'Launched.'
        Error         = ''
        OutputSummary = 'Logs folder opened.'
        ErrorSummary  = ''
        Message       = 'Logs folder opened.'
    }
    Write-ActionLog -Result $result
    return $result
}

Export-ModuleMember -Function Get-ApplicationCatalog, Get-RepairCatalog, Get-PresetCatalog, Get-MaintenanceCatalog, Get-TweakCatalog, Invoke-WorkbenchCommand, Invoke-ApplicationAction, Invoke-RepairAction, Invoke-TweakAction, Invoke-MaintenanceAction, Invoke-UpgradeSupportedPackages, Open-LogsFolder
