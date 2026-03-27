$script:AppPaths = @{}

function Initialize-AppPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($RootPath)
    $script:AppPaths = @{
        Root                  = $resolvedRoot
        Assets                = Join-Path -Path $resolvedRoot -ChildPath 'Assets'
        Config                = Join-Path -Path $resolvedRoot -ChildPath 'Config'
        Logs                  = Join-Path -Path $resolvedRoot -ChildPath 'Logs'
        Modules               = Join-Path -Path $resolvedRoot -ChildPath 'Modules'
        BrandingConfig        = Join-Path -Path $resolvedRoot -ChildPath 'Config\branding.json'
        ApplicationsConfig    = Join-Path -Path $resolvedRoot -ChildPath 'Config\applications.json'
        RepairsConfig         = Join-Path -Path $resolvedRoot -ChildPath 'Config\repair-actions.json'
        PresetsConfig         = Join-Path -Path $resolvedRoot -ChildPath 'Config\presets.json'
        MaintenanceConfig     = Join-Path -Path $resolvedRoot -ChildPath 'Config\maintenance-actions.json'
        TweaksConfig          = Join-Path -Path $resolvedRoot -ChildPath 'Config\tweaks.json'
        Logo                  = Join-Path -Path $resolvedRoot -ChildPath 'Assets\keymethods-logo.png'
    }

    foreach ($pathKey in 'Assets', 'Config', 'Logs', 'Modules') {
        Ensure-Directory -Path $script:AppPaths[$pathKey] | Out-Null
    }
}

function Get-AppPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Root', 'Assets', 'Config', 'Logs', 'Modules', 'BrandingConfig', 'ApplicationsConfig', 'RepairsConfig', 'PresetsConfig', 'MaintenanceConfig', 'TweaksConfig', 'Logo')]
        [string]$Name
    )

    if (-not $script:AppPaths.ContainsKey($Name)) {
        throw "Application path '$Name' has not been initialized."
    }

    return $script:AppPaths[$Name]
}

function Ensure-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }

    return $Path
}

function ConvertTo-AbsolutePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$BasePath = (Get-AppPath -Name 'Root')
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $BasePath -ChildPath $Path))
}

function Get-JsonConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return ($raw | ConvertFrom-Json)
}

function Test-CommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Escape-DataViewValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $escaped = $Value -replace "'", "''"
    $escaped = $escaped -replace '\[', '[[]'
    $escaped = $escaped -replace '\*', '[*]'
    $escaped = $escaped -replace '%', '[%]'
    return $escaped
}

function New-ExportPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,

        [Parameter(Mandatory = $true)]
        [string]$Extension
    )

    $fileName = '{0}-{1}.{2}' -f $Prefix, (Get-Date -Format 'yyyyMMdd-HHmmss'), $Extension.TrimStart('.')
    return Join-Path -Path (Get-AppPath -Name 'Logs') -ChildPath $fileName
}

Export-ModuleMember -Function Initialize-AppPaths, Get-AppPath, Ensure-Directory, ConvertTo-AbsolutePath, Get-JsonConfig, Test-CommandAvailable, Escape-DataViewValue, New-ExportPath
