function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsVersionLabel {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    return '{0} ({1})' -f $os.Caption, $os.Version
}

function Get-UptimeLabel {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    return '{0}d {1}h {2}m' -f [int]$uptime.TotalDays, $uptime.Hours, $uptime.Minutes
}

function Get-SystemSummary {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        ComputerName       = $env:COMPUTERNAME
        CurrentUser        = ('{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
        WindowsVersion     = Get-WindowsVersionLabel
        Uptime             = Get-UptimeLabel
        AdminStatus        = if (Test-IsAdministrator) { 'Yes' } else { 'No' }
        WingetDetected     = if (Test-CommandAvailable -Name 'winget.exe') { 'Yes' } else { 'No' }
        ChocolateyDetected = if (Test-CommandAvailable -Name 'choco.exe') { 'Yes' } else { 'No' }
        Timestamp          = Get-Date
    }
}

function Export-SystemSummary {
    [CmdletBinding()]
    param()

    $summary = Get-SystemSummary
    $destinationPath = New-ExportPath -Prefix 'system-summary' -Extension 'txt'

    $lines = @(
        'Key Methods Workbench System Summary'
        ('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        ''
        ('Computer Name: {0}' -f $summary.ComputerName)
        ('Current User: {0}' -f $summary.CurrentUser)
        ('Windows Version: {0}' -f $summary.WindowsVersion)
        ('Uptime: {0}' -f $summary.Uptime)
        ('Admin Status: {0}' -f $summary.AdminStatus)
        ('Winget Detected: {0}' -f $summary.WingetDetected)
        ('Chocolatey Detected: {0}' -f $summary.ChocolateyDetected)
    )

    Set-Content -LiteralPath $destinationPath -Value $lines -Encoding UTF8
    return $destinationPath
}

function Get-InstalledApplicationInventory {
    [CmdletBinding()]
    param()

    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }

    return $results | Sort-Object DisplayName -Unique
}

function Export-InstalledApplications {
    [CmdletBinding()]
    param()

    $destinationPath = New-ExportPath -Prefix 'installed-apps' -Extension 'csv'
    Get-InstalledApplicationInventory | Export-Csv -LiteralPath $destinationPath -NoTypeInformation -Encoding UTF8
    return $destinationPath
}

Export-ModuleMember -Function Test-IsAdministrator, Get-SystemSummary, Export-SystemSummary, Export-InstalledApplications
