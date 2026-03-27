# ============================================================================
# Key Methods Workbench - Branding Module
# ============================================================================
# Branding and theming functionality

$script:BrandingConfig = @{
    AppTitle = "Key Methods Workbench"
    ShortName = "KM Workbench"
    CompanyName = "Key Methods"
    FooterText = "Key Methods Internal Utility"
    Tagline = "Install. Repair. Maintain."
    AboutText = "Key Methods Workbench is an internal technician utility for workstation setup, application deployment, Windows remediation, and maintenance workflows."
    PrimaryColor = "#0072C6"
    SecondaryColor = "#F26522"
    WarningColor = "#FFC107"
    SuccessColor = "#28A745"
    ErrorColor = "#DC3545"
    LogoPath = "Assets/keymethods-logo.png"
    BootstrapUrl = "https://wb.keymethods.net/"
    WebsiteUrl = "https://wb.keymethods.net/"
    Version = "1.0.0"
}

function Get-KMBranding {
    <#
    .SYNOPSIS
        Gets the current branding configuration.
    
    .PARAMETER Key
        Optional specific key to retrieve.
    #>
    param(
        [string]$Key = $null
    )
    
    if ($Key) {
        return $script:BrandingConfig[$Key]
    }
    
    return $script:BrandingConfig
}

function Set-KMBranding {
    <#
    .SYNOPSIS
        Sets a branding configuration value.
    
    .PARAMETER Key
        Configuration key.
    
    .PARAMETER Value
        Value to set.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    
    $script:BrandingConfig[$Key] = $Value
}

function Import-KMBranding {
    <#
    .SYNOPSIS
        Imports branding configuration from a JSON file.
    
    .PARAMETER Path
        Path to the branding JSON file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        if (Test-Path $Path) {
            $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
            foreach ($prop in $config.PSObject.Properties) {
                $script:BrandingConfig[$prop.Name] = $prop.Value
            }
            Write-KMLog -Message "Branding configuration loaded from: $Path" -Level "Info"
            return $true
        }
        else {
            Write-KMLog -Message "Branding file not found: $Path" -Level "Warning"
            return $false
        }
    }
    catch {
        Write-KMLog -Message "Failed to load branding: $_" -Level "Error"
        return $false
    }
}

function Export-KMBranding {
    <#
    .SYNOPSIS
        Exports current branding configuration to a JSON file.
    
    .PARAMETER Path
        Path to save the branding JSON file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        $script:BrandingConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding UTF8
        Write-KMLog -Message "Branding configuration saved to: $Path" -Level "Success"
        return $true
    }
    catch {
        Write-KMLog -Message "Failed to save branding: $_" -Level "Error"
        return $false
    }
}

function Get-KMColor {
    <#
    .SYNOPSIS
        Gets a branded color value.
    
    .PARAMETER ColorName
        Name of the color: Primary, Secondary, Warning, Success, Error.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Primary", "Secondary", "Warning", "Success", "Error", "Background", "Text")]
        [string]$ColorName
    )
    
    switch ($ColorName) {
        "Primary"   { return $script:BrandingConfig.PrimaryColor }
        "Secondary" { return $script:BrandingConfig.SecondaryColor }
        "Warning"   { return $script:BrandingConfig.WarningColor }
        "Success"   { return $script:BrandingConfig.SuccessColor }
        "Error"     { return $script:BrandingConfig.ErrorColor }
        "Background" { return "#1E1E1E" }
        "Text"      { return "#FFFFFF" }
    }
}

function Get-KMAsciiLogo {
    <#
    .SYNOPSIS
        Returns the ASCII art logo for console display.
    #>
    return @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                 ██╗  ██╗███╗   ███╗    ██╗    ██╗██████╗ ██╗             ║
║                 ██║ ██╔╝████╗ ████║    ██║    ██║██╔══██╗██║             ║
║                 █████╔╝ ██╔████╔██║    ██║ █╗ ██║██████╔╝██║             ║
║                 ██╔═██╗ ██║╚██╔╝██║    ██║███╗██║██╔══██╗██║             ║
║                 ██║  ██╗██║ ╚═╝ ██║    ╚███╔███╔╝██║  ██║███████╗        ║
║                 ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝        ║
║                                                                           ║
║                         Key Methods Workbench                             ║
║                        Install. Repair. Maintain.                         ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@
}

#region Export Module Members

Export-ModuleMember -Function @(
    'Get-KMBranding',
    'Set-KMBranding',
    'Import-KMBranding',
    'Export-KMBranding',
    'Get-KMColor',
    'Get-KMAsciiLogo'
)

#endregion
