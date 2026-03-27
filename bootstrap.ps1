[CmdletBinding()]
param(
    [switch]$AutoClose,
    [string]$BaseUrl = 'https://raw.githubusercontent.com/MathHue/Workbench/main/KM-Workbench'
)

function Start-WorkbenchProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MainScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$ResolvedRootPath
    )

    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-STA'
        '-File', ('"{0}"' -f $MainScriptPath)
        '-RootPath', ('"{0}"' -f $ResolvedRootPath)
    )

    if ($AutoClose) {
        $arguments += '-AutoClose'
    }

    Start-Process -FilePath 'powershell.exe' -ArgumentList ($arguments -join ' ') | Out-Null
}

function Get-RemoteWorkbenchRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadBaseUrl
    )

    $downloadRoot = Join-Path -Path $env:TEMP -ChildPath ('KM-Workbench-{0}' -f (Get-Date -Format 'yyyyMMddHHmmss'))
    $null = New-Item -Path $downloadRoot -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $downloadRoot 'Assets') -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $downloadRoot 'Config') -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $downloadRoot 'Modules') -ItemType Directory -Force
    $null = New-Item -Path (Join-Path $downloadRoot 'Logs') -ItemType Directory -Force

    $relativeFiles = @(
        'main.ps1'
        'Assets/keymethods-logo.png'
        'Config/branding.json'
        'Config/applications.json'
        'Config/repair-actions.json'
        'Config/presets.json'
        'Config/maintenance-actions.json'
        'Config/tweaks.json'
        'Modules/Helpers.psm1'
        'Modules/Logging.psm1'
        'Modules/Branding.psm1'
        'Modules/SystemInfo.psm1'
        'Modules/Runtime.psm1'
        'Modules/UI.psm1'
    )

    foreach ($relativeFile in $relativeFiles) {
        $sourceUrl = '{0}/{1}' -f $DownloadBaseUrl.TrimEnd('/'), $relativeFile
        $destinationPath = Join-Path -Path $downloadRoot -ChildPath ($relativeFile -replace '/', '\')
        Invoke-WebRequest -Uri $sourceUrl -OutFile $destinationPath -UseBasicParsing
    }

    return $downloadRoot
}

$scriptPath = $MyInvocation.MyCommand.Path
$localRoot = if ($scriptPath) { Split-Path -Parent $scriptPath } else { $null }
$localMain = if ($localRoot) { Join-Path -Path $localRoot -ChildPath 'main.ps1' } else { $null }
$isLocalRun = $localMain -and (Test-Path -LiteralPath $localMain)

if ($isLocalRun) {
    Start-WorkbenchProcess -MainScriptPath $localMain -ResolvedRootPath $localRoot
}
else {
    $remoteRoot = Get-RemoteWorkbenchRoot -DownloadBaseUrl $BaseUrl
    $remoteMain = Join-Path -Path $remoteRoot -ChildPath 'main.ps1'
    Start-WorkbenchProcess -MainScriptPath $remoteMain -ResolvedRootPath $remoteRoot
}
