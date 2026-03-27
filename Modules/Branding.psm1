function Get-Branding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $config = Get-JsonConfig -Path $ConfigPath
    $resolvedLogoPath = ConvertTo-AbsolutePath -Path $config.logoPath

    [pscustomobject]@{
        AppName         = $config.appName
        Tagline         = $config.tagline
        CompanyName     = $config.companyName
        WindowTitle     = $config.windowTitle
        Version         = $config.version
        WebsiteUrl      = $config.websiteUrl
        BootstrapUrl    = $config.bootstrapUrl
        SupportText     = $config.supportText
        LogoPath        = $resolvedLogoPath
        HasLogo         = [bool](Test-Path -LiteralPath $resolvedLogoPath)
        AccentColor     = $config.colors.accent
        WarningColor    = $config.colors.warning
        BackgroundColor = $config.colors.background
        SurfaceColor    = $config.colors.surface
        SurfaceAltColor = $config.colors.surfaceAlt
        TextColor       = $config.colors.text
        MutedTextColor  = $config.colors.mutedText
        AboutTitle      = $config.about.headline
        AboutBody       = $config.about.body
    }
}

function Get-BrandImageSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit()
    $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bitmap.UriSource = New-Object System.Uri($Path, [System.UriKind]::Absolute)
    $bitmap.EndInit()
    $bitmap.Freeze()

    return $bitmap
}

Export-ModuleMember -Function Get-Branding, Get-BrandImageSource
