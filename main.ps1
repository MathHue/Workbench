[CmdletBinding()]
param(
    [switch]$AutoClose,
    [string]$RootPath
)

$ErrorActionPreference = 'Stop'

$script:AppRoot = if ([string]::IsNullOrWhiteSpace($RootPath)) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    [System.IO.Path]::GetFullPath($RootPath)
}

$modulesPath = Join-Path -Path $script:AppRoot -ChildPath 'Modules'

$moduleFiles = @(
    'Helpers.psm1'
    'Logging.psm1'
    'Branding.psm1'
    'SystemInfo.psm1'
    'Runtime.psm1'
    'UI.psm1'
)

foreach ($moduleFile in $moduleFiles) {
    $modulePath = Join-Path -Path $modulesPath -ChildPath $moduleFile
    Import-Module -Name $modulePath -Force
}

Initialize-AppPaths -RootPath $script:AppRoot
Initialize-Log -RootPath $script:AppRoot
Write-Log -Message 'Starting Key Methods Workbench.'

try {
    $branding = Get-Branding -ConfigPath (Get-AppPath -Name 'BrandingConfig')
    Show-WorkbenchShell -Branding $branding -AutoClose:$AutoClose
    Write-Log -Message 'Workbench exited normally.'
}
catch {
    Write-Log -Level Error -Message 'Workbench startup failed.' -ErrorSummary $_.Exception.Message
    throw
}
