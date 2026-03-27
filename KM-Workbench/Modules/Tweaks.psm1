# ============================================================================
# Key Methods Workbench - Tweaks Module
# ============================================================================
# System tweaks and configuration adjustments

$script:TweakRegistryRoot = "HKCU:\Software\KeyMethods\Workbench\Tweaks"

function Get-KMTweaks {
    <#
    .SYNOPSIS
        Gets available system tweaks.
    #>
    return @(
        @{
            id = "ShowFileExtensions"
            name = "Show File Extensions"
            description = "Always show file extensions in Explorer"
            category = "Explorer"
            requiresAdmin = $false
            currentValue = (Get-KMFileExtensionsVisibility)
        },
        @{
            id = "ShowHiddenFiles"
            name = "Show Hidden Files"
            description = "Show hidden files and folders in Explorer"
            category = "Explorer"
            requiresAdmin = $false
            currentValue = (Get-KMHiddenFilesVisibility)
        },
        @{
            id = "ShowProtectedOSFiles"
            name = "Show Protected OS Files"
            description = "Show protected operating system files"
            category = "Explorer"
            requiresAdmin = $false
            currentValue = (Get-KMProtectedFilesVisibility)
        },
        @{
            id = "DisableFastStartup"
            name = "Disable Fast Startup"
            description = "Turn off Fast Startup (recommended for dual boot)"
            category = "Power"
            requiresAdmin = $true
            currentValue = (Get-KMFastStartupStatus)
        },
        @{
            id = "EnableRDP"
            name = "Enable Remote Desktop"
            description = "Enable Remote Desktop connections"
            category = "Remote"
            requiresAdmin = $true
            currentValue = (Get-KMRDPStatus)
        },
        @{
            id = "EnableRemoteAssistance"
            name = "Enable Remote Assistance"
            description = "Enable Remote Assistance"
            category = "Remote"
            requiresAdmin = $true
            currentValue = (Get-KMRemoteAssistanceStatus)
        }
    )
}

function Apply-KMTweak {
    <#
    .SYNOPSIS
        Applies a system tweak.
    
    .PARAMETER TweakId
        ID of the tweak to apply.
    
    .PARAMETER Enable
        Enable or disable the tweak.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakId,
        
        [bool]$Enable = $true
    )
    
    Write-KMLog -Message "Applying tweak: $TweakId = $Enable" -Level "Info"
    
    $result = @{ Success = $false; RequiresRestart = $false }
    
    try {
        switch ($TweakId) {
            "ShowFileExtensions" {
                Set-KMFileExtensionsVisibility -Enabled $Enable
                $result.Success = $true
            }
            "ShowHiddenFiles" {
                Set-KMHiddenFilesVisibility -Enabled $Enable
                $result.Success = $true
            }
            "ShowProtectedOSFiles" {
                Set-KMProtectedFilesVisibility -Enabled $Enable
                $result.Success = $true
            }
            "DisableFastStartup" {
                Set-KMFastStartupStatus -Enabled (-not $Enable)
                $result.Success = $true
                $result.RequiresRestart = $true
            }
            "EnableRDP" {
                Set-KMRDPStatus -Enabled $Enable
                $result.Success = $true
            }
            "EnableRemoteAssistance" {
                Set-KMRemoteAssistanceStatus -Enabled $Enable
                $result.Success = $true
            }
            default {
                Write-KMLog -Message "Unknown tweak: $TweakId" -Level "Error"
                $result.Error = "Unknown tweak ID"
            }
        }
    }
    catch {
        Write-KMLog -Message "Failed to apply tweak $TweakId : $_" -Level "Error"
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

#region Explorer Tweaks

function Get-KMFileExtensionsVisibility {
    $value = Get-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -DefaultValue 1
    return ($value -eq 0)
}

function Set-KMFileExtensionsVisibility {
    param([bool]$Enabled)
    Set-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value ([int](-not $Enabled)) -Type DWord
    Restart-KMExplorer
}

function Get-KMHiddenFilesVisibility {
    $value = Get-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -DefaultValue 2
    return ($value -eq 1)
}

function Set-KMHiddenFilesVisibility {
    param([bool]$Enabled)
    $value = if ($Enabled) { 1 } else { 2 }
    Set-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value $value -Type DWord
    Restart-KMExplorer
}

function Get-KMProtectedFilesVisibility {
    $value = Get-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -DefaultValue 0
    return ($value -eq 1)
}

function Set-KMProtectedFilesVisibility {
    param([bool]$Enabled)
    Set-KMRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value ([int]$Enabled) -Type DWord
    Restart-KMExplorer
}

#endregion

#region Power Tweaks

function Get-KMFastStartupStatus {
    # Returns $true if fast startup is enabled
    $value = Get-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -DefaultValue 1
    return ($value -eq 1)
}

function Set-KMFastStartupStatus {
    param([bool]$Enabled)
    Set-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value ([int]$Enabled) -Type DWord
}

#endregion

#region Remote Access Tweaks

function Get-KMRDPStatus {
    $value = Get-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -DefaultValue 1
    return ($value -eq 0)
}

function Set-KMRDPStatus {
    param([bool]$Enabled)
    
    # Enable/disable RDP
    Set-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value ([int](-not $Enabled)) -Type DWord
    
    # Enable NLA (Network Level Authentication)
    if ($Enabled) {
        Set-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1 -Type DWord
    }
    
    # Configure firewall
    if ($Enabled) {
        Invoke-KMCommand -Command "netsh" -Arguments @("advfirewall", "firewall", "set", "rule", "group=`"remote desktop`"", "new", "enable=Yes")
    }
}

function Get-KMRemoteAssistanceStatus {
    $value = Get-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -DefaultValue 0
    return ($value -eq 1)
}

function Set-KMRemoteAssistanceStatus {
    param([bool]$Enabled)
    Set-KMRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value ([int]$Enabled) -Type DWord
}

#endregion

#region Utility Functions

function Restart-KMExplorer {
    <#
    .SYNOPSIS
        Restarts Windows Explorer to apply changes.
    #>
    try {
        Write-KMLog -Message "Restarting Explorer to apply changes..." -Level "Info"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer
    }
    catch {
        Write-KMLog -Message "Failed to restart Explorer: $_" -Level "Error"
    }
}

function Test-KMTweakPrerequisites {
    <#
    .SYNOPSIS
        Tests if prerequisites for a tweak are met.
    
    .PARAMETER TweakId
        Tweak ID to test.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakId
    )
    
    $tweak = Get-KMTweaks | Where-Object { $_.id -eq $TweakId }
    
    if (-not $tweak) {
        return @{ CanApply = $false; Reason = "Unknown tweak" }
    }
    
    if ($tweak.requiresAdmin -and -not (Test-KMAdminRights)) {
        return @{ CanApply = $false; Reason = "Administrator rights required" }
    }
    
    return @{ CanApply = $true }
}

#endregion

#region Export Module Members

Export-ModuleMember -Function @(
    'Get-KMTweaks',
    'Apply-KMTweak',
    'Get-KMFileExtensionsVisibility',
    'Set-KMFileExtensionsVisibility',
    'Get-KMHiddenFilesVisibility',
    'Set-KMHiddenFilesVisibility',
    'Get-KMProtectedFilesVisibility',
    'Set-KMProtectedFilesVisibility',
    'Get-KMFastStartupStatus',
    'Set-KMFastStartupStatus',
    'Get-KMRDPStatus',
    'Set-KMRDPStatus',
    'Get-KMRemoteAssistanceStatus',
    'Set-KMRemoteAssistanceStatus',
    'Restart-KMExplorer',
    'Test-KMTweakPrerequisites'
)

#endregion
