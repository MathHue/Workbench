#requires -Version 5.1
<#
.SYNOPSIS
    Key Methods Workbench - Main Application Entry Point

.DESCRIPTION
    This is the main entry point for the Key Methods Workbench GUI application.
    It is invoked by bootstrap.ps1 after downloading all required components.

.PARAMETER WorkingDirectory
    The working directory where all Workbench files are located.

.PARAMETER IsAdmin
    Indicates whether the script is running with administrator privileges.

.PARAMETER BootstrapVersion
    The version of the bootstrap script that launched this application.

.PARAMETER HostedBaseUrl
    The base URL where Workbench files are hosted.

.PARAMETER Mode
    Launch mode: GUI, AppsOnly, or RepairsOnly.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,
    
    [Parameter(Mandatory = $true)]
    [bool]$IsAdmin,
    
    [Parameter(Mandatory = $true)]
    [string]$BootstrapVersion,
    
    [Parameter(Mandatory = $true)]
    [string]$HostedBaseUrl,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("GUI", "AppsOnly", "RepairsOnly")]
    [string]$Mode = "GUI"
)

#region Initialization
# ============================================================================
# INITIALIZATION
# ============================================================================

$script:AppVersion = "1.0.0"
$script:ConfigPath = Join-Path $WorkingDirectory "Config"
$script:ModulePath = Join-Path $WorkingDirectory "Modules"
$script:AssetPath = Join-Path $WorkingDirectory "Assets"
$script:LogPath = Join-Path $WorkingDirectory "Logs"
$script:IsAdmin = $IsAdmin
$script:HostedBaseUrl = $HostedBaseUrl

# Helper function to convert PSCustomObject to Hashtable (PowerShell 5.1 compatible)
function Convert-JsonToHashtable {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)
    
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @()
            foreach ($item in $InputObject) {
                $converted = Convert-JsonToHashtable $item
                $collection += $converted
            }
            return $collection
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $hash = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $hash[$prop.Name] = Convert-JsonToHashtable $prop.Value
            }
            return $hash
        }
        else {
            return $InputObject
        }
    }
}

# Helper function to convert JSON array to ArrayList of PSCustomObjects (simpler approach)
function Convert-JsonToObjects {
    param([string]$JsonFile)
    
    if (-not (Test-Path $JsonFile)) { return @() }
    
    $content = Get-Content $JsonFile -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return @() }
    
    # Simply return the objects from ConvertFrom-Json - they work fine as PSCustomObject
    return $content | ConvertFrom-Json
}

function Get-KMBrandingValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Fallback
    )

    $value = $script:Branding.$Name
    if ([string]::IsNullOrWhiteSpace([string]$value)) {
        return $Fallback
    }

    return [string]$value
}

# Load configuration files - use PSCustomObjects directly (simpler and more reliable)
$script:Branding = @{}
$script:Applications = @()
$script:RepairActions = @()
$script:MaintenanceActions = @()
$script:Presets = @{}

try {
    $brandingFile = Join-Path $script:ConfigPath "branding.json"
    if (Test-Path $brandingFile) {
        $script:Branding = Get-Content $brandingFile -Raw | ConvertFrom-Json
    }
}
catch {
    Write-Warning "Failed to load branding configuration: $_"
}

try {
    $appsFile = Join-Path $script:ConfigPath "applications.json"
    if (Test-Path $appsFile) {
        $script:Applications = @(Get-Content $appsFile -Raw | ConvertFrom-Json)
    }
}
catch {
    Write-Warning "Failed to load applications configuration: $_"
}

try {
    $repairsFile = Join-Path $script:ConfigPath "repair-actions.json"
    if (Test-Path $repairsFile) {
        $script:RepairActions = @(Get-Content $repairsFile -Raw | ConvertFrom-Json)
    }
}
catch {
    Write-Warning "Failed to load repair actions configuration: $_"
}

try {
    $maintenanceFile = Join-Path $script:ConfigPath "maintenance-actions.json"
    if (Test-Path $maintenanceFile) {
        $script:MaintenanceActions = @(Get-Content $maintenanceFile -Raw | ConvertFrom-Json)
    }
}
catch {
    Write-Warning "Failed to load maintenance actions configuration: $_"
}

try {
    $presetsFile = Join-Path $script:ConfigPath "presets.json"
    if (Test-Path $presetsFile) {
        $script:Presets = Get-Content $presetsFile -Raw | ConvertFrom-Json
    }
}
catch {
    Write-Warning "Failed to load presets configuration: $_"
}

# Import all modules
$modules = @("Helpers.psm1", "Logging.psm1", "Branding.psm1", "Apps.psm1", "Repairs.psm1", "Tweaks.psm1", "Maintenance.psm1", "UI.psm1")
foreach ($module in $modules) {
    $moduleFile = Join-Path $script:ModulePath $module
    if (Test-Path $moduleFile) {
        Import-Module $moduleFile -Force
    }
}

#endregion

#region WPF UI Implementation
# ============================================================================
# WPF UI IMPLEMENTATION
# ============================================================================

# Check if we are in STA mode (required for WPF)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Warning "PowerShell is not running in STA mode. WPF requires STA mode."
    Write-Host "Please run PowerShell with the -STA parameter or use the local launch method." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
}
catch {
    Write-Error "Failed to load WPF assemblies. Ensure .NET Framework is installed."
    Write-Error "Details: $_"
    Read-Host "Press Enter to exit"
    exit 1
}
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Initialize logging
Initialize-KMLogging -LogPath $script:LogPath
Write-KMLog -Message "Key Methods Workbench v$script:AppVersion started" -Level "Info"
Write-KMLog -Message "Working Directory: $WorkingDirectory" -Level "Info"
Write-KMLog -Message "Admin Rights: $IsAdmin" -Level "Info"
Write-KMLog -Message "Launch Mode: $Mode" -Level "Info"

# Load the XAML UI
function Initialize-MainWindow {
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Key Methods Workbench" 
        Height="750" Width="1100" 
        MinHeight="600" MinWidth="900"
        WindowStartupLocation="CenterScreen"
        Background="#FF0F141A">
    
    <Window.Resources>
        <SolidColorBrush x:Key="PrimaryBlue" Color="#0A83D8"/>
        <SolidColorBrush x:Key="PrimaryOrange" Color="#F26522"/>
        <SolidColorBrush x:Key="LightBackground" Color="#FF11161D"/>
        <SolidColorBrush x:Key="LighterBackground" Color="#FF181D23"/>
        <SolidColorBrush x:Key="DarkBackground" Color="#FF243548"/>
        <SolidColorBrush x:Key="DarkerBackground" Color="#FF0D1218"/>
        <SolidColorBrush x:Key="BorderColor" Color="#FF2D3640"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#FFF4F6F8"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#FF9DAAB7"/>
        <SolidColorBrush x:Key="SuccessGreen" Color="#FF46C37B"/>
        <SolidColorBrush x:Key="WarningYellow" Color="#FFF4B942"/>
        <SolidColorBrush x:Key="DangerRed" Color="#FFE25656"/>
        
        <!-- Style for Navigation Buttons -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="15,10"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="FontFamily" Value="Bahnschrift SemiCondensed"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="NavBorder"
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{StaticResource PrimaryBlue}"
                                BorderThickness="1">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="Center"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="NavBorder" Property="Background" Value="#FF1D2430"/>
                            </Trigger>
                            <Trigger Property="Tag" Value="Selected">
                                <Setter TargetName="NavBorder" Property="Background" Value="{StaticResource DarkBackground}"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                                <Setter TargetName="NavBorder" Property="BorderBrush" Value="{StaticResource PrimaryOrange}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Style for Action Buttons -->
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource PrimaryBlue}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontFamily" Value="Bahnschrift SemiCondensed"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="10"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                            VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.92"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.6"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Style for Warning/Orange Buttons -->
        <Style x:Key="WarningButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="{StaticResource PrimaryOrange}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.92"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Style for Danger/Red Buttons -->
        <Style x:Key="DangerButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="{StaticResource DangerRed}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.92"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Style for CheckBoxes -->
        <Style x:Key="DarkCheckBoxStyle" TargetType="CheckBox">
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
        
        <!-- Style for TextBoxes -->
        <Style x:Key="DarkTextBoxStyle" TargetType="TextBox">
            <Setter Property="Background" Value="{StaticResource DarkerBackground}"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource PrimaryBlue}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        
        <!-- Style for ListViews -->
        <Style x:Key="DarkListViewStyle" TargetType="ListView">
            <Setter Property="Background" Value="{StaticResource LighterBackground}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderColor}"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        
        <!-- Style for GroupBoxes -->
        <Style x:Key="DarkGroupBoxStyle" TargetType="GroupBox">
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderColor}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Background" Value="{StaticResource LighterBackground}"/>
        </Style>
    </Window.Resources>
    
    <Border Background="{StaticResource LightBackground}">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Header -->
            <Border Grid.Row="0" Background="{StaticResource LighterBackground}" BorderBrush="{StaticResource BorderColor}" BorderThickness="0,0,0,1">
                <Grid Margin="15,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    
                    <!-- Logo Placeholder -->
                    <Image x:Name="LogoImage" Grid.Column="0" Width="200" Height="40" Margin="0,0,15,0" HorizontalAlignment="Left"/>
                    
                    <!-- Title -->
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock Text="Key Methods Workbench" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" FontFamily="Bahnschrift SemiCondensed"/>
                        <TextBlock Text="Install. Repair. Maintain." FontSize="12" Foreground="{StaticResource TextSecondary}"/>
                    </StackPanel>
                    
                    <!-- Admin Badge -->
                    <Border x:Name="AdminBadge" Grid.Column="2" Background="{StaticResource PrimaryOrange}" CornerRadius="3" Padding="10,5" Visibility="Collapsed">
                        <TextBlock Text="ADMIN MODE" FontSize="10" FontWeight="Bold" Foreground="White"/>
                    </Border>
                </Grid>
            </Border>
            
            <!-- Main Content -->
            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="200"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <!-- Navigation Sidebar -->
                <Border Grid.Column="0" Background="{StaticResource LighterBackground}" BorderBrush="{StaticResource BorderColor}" BorderThickness="0,0,1,0">
                    <StackPanel x:Name="NavigationPanel" Margin="0,10">
                        <Button x:Name="NavHome" Content="Home" Style="{StaticResource NavButtonStyle}" Tag="Selected"/>
                        <Button x:Name="NavApps" Content="Applications" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavRepairs" Content="Repairs" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavTweaks" Content="Tweaks" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavMaintenance" Content="Maintenance" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavLogs" Content="Logs" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavAbout" Content="About" Style="{StaticResource NavButtonStyle}"/>
                    </StackPanel>
                </Border>
                
                <!-- Content Area -->
                <Border Grid.Column="1" Background="{StaticResource LightBackground}">
                    <Grid x:Name="ContentGrid" Margin="20">
                        
                        <!-- HOME TAB -->
                        <Grid x:Name="TabHome" Visibility="Visible">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <TextBlock Grid.Row="0" Text="Welcome to Key Methods Workbench" FontSize="22" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,20"/>
                            
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    
                                    <!-- Left Column: System Info -->
                                    <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                        <GroupBox Header="System Information" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Hostname:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysHostname" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="OS Version:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysOSVersion" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Current User:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysUsername" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Uptime:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysUptime" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Separator Margin="0,10" Background="{StaticResource LightBackground}"/>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Admin Rights:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysAdminStatus" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Winget:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysWingetStatus" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                                <Grid Margin="0,5">
                                                    <TextBlock Text="Chocolatey:" Foreground="{StaticResource TextSecondary}" FontSize="12"/>
                                                    <TextBlock x:Name="SysChocoStatus" Text="-" Foreground="{StaticResource TextPrimary}" FontSize="12" HorizontalAlignment="Right"/>
                                                </Grid>
                                            </StackPanel>
                                        </GroupBox>
                                    </StackPanel>
                                    
                                    <!-- Right Column: Quick Actions & Presets -->
                                    <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                        <GroupBox Header="Quick Actions" Style="{StaticResource DarkGroupBoxStyle}" Margin="0,0,0,10">
                                            <WrapPanel Margin="10">
                                                <Button x:Name="QuickFlushDNS" Content="Flush DNS" Style="{StaticResource ActionButtonStyle}" Margin="5"/>
                                                <Button x:Name="QuickGPUpdate" Content="GPUpdate" Style="{StaticResource ActionButtonStyle}" Margin="5"/>
                                                <Button x:Name="QuickRestartExplorer" Content="Restart Explorer" Style="{StaticResource WarningButtonStyle}" Margin="5"/>
                                            </WrapPanel>
                                        </GroupBox>
                                        
                                        <GroupBox Header="Quick Presets" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <Button x:Name="PresetNewWorkstation" Content="New Workstation Setup" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                                <Button x:Name="PresetBasicUser" Content="Basic User PC" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                                <Button x:Name="PresetTechBench" Content="Technician Bench Build" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                            </StackPanel>
                                        </GroupBox>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>
                        </Grid>
                        
                        <!-- APPLICATIONS TAB -->
                        <Grid x:Name="TabApps" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <TextBlock Grid.Row="0" Text="Application Installer" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                            
                            <!-- Search and Filter -->
                            <Grid Grid.Row="1" Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBox x:Name="AppSearchBox" Grid.Column="0" Style="{StaticResource DarkTextBoxStyle}" Text="Search applications..."/>
                                <ComboBox x:Name="AppCategoryFilter" Grid.Column="1" Width="150" Margin="10,0,0,0" SelectedIndex="0"/>
                            </Grid>
                            
                            <!-- App List -->
                            <ListView x:Name="AppListView" Grid.Row="2" Style="{StaticResource DarkListViewStyle}" Margin="0,0,0,10">
                                <ListView.View>
                                    <GridView>
                                        <GridViewColumn Width="30">
                                            <GridViewColumn.CellTemplate>
                                                <DataTemplate>
                                                    <CheckBox IsChecked="{Binding IsSelected}" Style="{StaticResource DarkCheckBoxStyle}"/>
                                                </DataTemplate>
                                            </GridViewColumn.CellTemplate>
                                        </GridViewColumn>
                                        <GridViewColumn Header="Name" Width="200" DisplayMemberBinding="{Binding Name}"/>
                                        <GridViewColumn Header="Category" Width="120" DisplayMemberBinding="{Binding Category}"/>
                                        <GridViewColumn Header="Provider" Width="80" DisplayMemberBinding="{Binding Provider}"/>
                                        <GridViewColumn Header="Status" Width="90" DisplayMemberBinding="{Binding InstalledStatus}"/>
                                        <GridViewColumn Header="Description" Width="250" DisplayMemberBinding="{Binding Description}"/>
                                    </GridView>
                                </ListView.View>
                            </ListView>
                            
                            <!-- Action Bar -->
                            <Grid Grid.Row="3">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" Orientation="Horizontal">
                                    <Button x:Name="AppSelectAll" Content="Select All" Style="{StaticResource ActionButtonStyle}" Margin="0,0,5,0"/>
                                    <Button x:Name="AppSelectNone" Content="Select None" Style="{StaticResource ActionButtonStyle}" Margin="0,0,5,0"/>
                                    <Button x:Name="AppSelectRecommended" Content="Select Recommended" Style="{StaticResource ActionButtonStyle}"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2" Orientation="Horizontal">
                                    <Button x:Name="AppInstallSelected" Content="Install Selected" Style="{StaticResource ActionButtonStyle}" Margin="0,0,5,0"/>
                                    <Button x:Name="AppUninstallSelected" Content="Uninstall Selected" Style="{StaticResource WarningButtonStyle}"/>
                                </StackPanel>
                            </Grid>
                        </Grid>
                        
                        <!-- REPAIRS TAB -->
                        <Grid x:Name="TabRepairs" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
                                <TextBlock Text="Windows Repairs" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                <ComboBox x:Name="RepairLevelFilter" Width="150" Margin="20,0,0,0" SelectedIndex="0" VerticalAlignment="Center"/>
                            </StackPanel>
                            
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <StackPanel x:Name="RepairsContainer">
                                    <!-- Safe Repairs Section -->
                                    <GroupBox x:Name="SafeRepairsGroup" Header="Safe Repairs" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="SafeRepairsPanel" Margin="10" Background="{StaticResource LighterBackground}"/>
                                    </GroupBox>
                                    
                                    <!-- Advanced Repairs Section -->
                                    <GroupBox x:Name="AdvancedRepairsGroup" Header="Advanced Repairs (Use with caution)" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="AdvancedRepairsPanel" Margin="10" Background="{StaticResource LighterBackground}"/>
                                    </GroupBox>
                                    
                                    <!-- Dangerous Repairs Section -->
                                    <GroupBox Header="⚠️ Dangerous Repairs (Confirmation Required)" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="DangerousRepairsPanel" Margin="10" Background="{StaticResource LighterBackground}"/>
                                    </GroupBox>
                                </StackPanel>
                            </ScrollViewer>
                            
                            <Grid Grid.Row="2" Margin="0,10,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="RepairRunSelected" Grid.Column="1" Content="Run Selected Repairs" Style="{StaticResource ActionButtonStyle}"/>
                            </Grid>
                        </Grid>
                        
                        <!-- TWEAKS TAB -->
                        <Grid x:Name="TabTweaks" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            
                            <TextBlock Grid.Row="0" Text="System Tweaks" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                            
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    
                                    <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                        <GroupBox Header="Explorer Settings" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <CheckBox x:Name="TweakShowFileExtensions" Content="Show file extensions" Style="{StaticResource DarkCheckBoxStyle}"/>
                                                <CheckBox x:Name="TweakShowHiddenFiles" Content="Show hidden files" Style="{StaticResource DarkCheckBoxStyle}"/>
                                                <CheckBox x:Name="TweakShowProtectedFiles" Content="Show protected OS files" Style="{StaticResource DarkCheckBoxStyle}"/>
                                            </StackPanel>
                                        </GroupBox>
                                        
                                        <GroupBox Header="Power Options" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <CheckBox x:Name="TweakDisableFastStartup" Content="Disable Fast Startup" Style="{StaticResource DarkCheckBoxStyle}"/>
                                            </StackPanel>
                                        </GroupBox>
                                    </StackPanel>
                                    
                                    <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                        <GroupBox Header="Remote Access" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <CheckBox x:Name="TweakEnableRDP" Content="Enable Remote Desktop" Style="{StaticResource DarkCheckBoxStyle}"/>
                                                <CheckBox x:Name="TweakEnableRemoteAssistance" Content="Enable Remote Assistance" Style="{StaticResource DarkCheckBoxStyle}"/>
                                            </StackPanel>
                                        </GroupBox>
                                        
                                        <Button x:Name="TweaksApply" Content="Apply Selected Tweaks" Style="{StaticResource ActionButtonStyle}" Margin="0,20,0,0" HorizontalAlignment="Right"/>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>
                        </Grid>
                        
                        <!-- MAINTENANCE TAB -->
                        <Grid x:Name="TabMaintenance" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            
                            <TextBlock Grid.Row="0" Text="Maintenance Utilities" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" Margin="0,0,0,10"/>
                            
                            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    
                                    <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                        <GroupBox Header="Windows Tools" Style="{StaticResource DarkGroupBoxStyle}">
                                            <WrapPanel x:Name="MaintenanceToolsPanel" Margin="10" Background="{StaticResource LighterBackground}"/>
                                        </GroupBox>
                                        
                                        <GroupBox Header="Package Managers" Style="{StaticResource DarkGroupBoxStyle}">
                                            <WrapPanel x:Name="MaintenancePackagePanel" Margin="10">
                                                <Button x:Name="MaintWingetUpgrade" Content="Upgrade All (Winget)" Style="{StaticResource ActionButtonStyle}" Margin="5"/>
                                                <Button x:Name="MaintChocoUpgrade" Content="Upgrade All (Chocolatey)" Style="{StaticResource ActionButtonStyle}" Margin="5"/>
                                            </WrapPanel>
                                        </GroupBox>
                                    </StackPanel>
                                    
                                    <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                        <GroupBox Header="Export &amp; Reports" Style="{StaticResource DarkGroupBoxStyle}">
                                            <StackPanel Margin="10">
                                                <Button x:Name="MaintExportSystem" Content="Export System Summary" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                                <Button x:Name="MaintExportApps" Content="Export Installed Apps" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                                <Button x:Name="MaintExportLogs" Content="Export Logs" Style="{StaticResource ActionButtonStyle}" Margin="0,5" HorizontalAlignment="Stretch"/>
                                            </StackPanel>
                                        </GroupBox>
                                    </StackPanel>
                                </Grid>
                            </ScrollViewer>
                        </Grid>
                        
                        <!-- LOGS TAB -->
                        <Grid x:Name="TabLogs" Visibility="Collapsed">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            
                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="Output Log" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" VerticalAlignment="Center"/>
                                <StackPanel Grid.Column="1" Orientation="Horizontal">
                                    <Button x:Name="LogRefresh" Content="Refresh" Style="{StaticResource ActionButtonStyle}" Margin="0,0,5,0"/>
                                    <Button x:Name="LogClear" Content="Clear" Style="{StaticResource WarningButtonStyle}" Margin="0,0,5,0"/>
                                    <Button x:Name="LogExport" Content="Export" Style="{StaticResource ActionButtonStyle}"/>
                                </StackPanel>
                            </Grid>
                            
                            <TextBox x:Name="LogOutput" Grid.Row="1" Style="{StaticResource DarkTextBoxStyle}" 
                                     IsReadOnly="True" 
                                     VerticalScrollBarVisibility="Auto"
                                     HorizontalScrollBarVisibility="Auto"
                                     FontFamily="Consolas"
                                     FontSize="11"/>
                            
                            <StatusBar Grid.Row="2" Background="{StaticResource LighterBackground}" Margin="0,5,0,0">
                                <TextBlock x:Name="StatusBarText" Text="Ready" Foreground="{StaticResource TextSecondary}" FontSize="11"/>
                            </StatusBar>
                        </Grid>
                        
                        <!-- ABOUT TAB -->
                        <Grid x:Name="TabAbout" Visibility="Collapsed">
                            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="600">
                                <Image x:Name="AboutLogo" Width="300" Height="60" Margin="0,0,0,20" HorizontalAlignment="Center"/>
                                <TextBlock Text="Key Methods Workbench" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextPrimary}" TextAlignment="Center"/>
                                <TextBlock Text="Version 1.0.0" FontSize="14" Foreground="{StaticResource TextSecondary}" TextAlignment="Center" Margin="0,5"/>
                                <TextBlock Text="Install. Repair. Maintain." FontSize="14" FontStyle="Italic" Foreground="{StaticResource PrimaryOrange}" TextAlignment="Center" Margin="0,10"/>
                                <TextBlock TextWrapping="Wrap" TextAlignment="Center" Margin="0,20" Foreground="{StaticResource TextSecondary}">
                                    Key Methods Workbench is an internal technician utility for workstation setup, application deployment, Windows remediation, and maintenance workflows.
                                </TextBlock>
                                <Separator Margin="0,20" Background="{StaticResource LightBackground}"/>
                                <TextBlock Text="Key Methods Internal Utility" FontSize="11" Foreground="{StaticResource TextSecondary}" TextAlignment="Center"/>
                                <TextBlock x:Name="AboutUrl" Text="https://wb.keymethods.net" FontSize="11" Foreground="{StaticResource PrimaryBlue}" TextAlignment="Center" Margin="0,5" Cursor="Hand"/>
                            </StackPanel>
                        </Grid>
                        
                    </Grid>
                </Border>
            </Grid>
            
            <!-- Footer -->
            <Border Grid.Row="2" Background="{StaticResource LighterBackground}" BorderBrush="{StaticResource BorderColor}" BorderThickness="0,1,0,0">
                <Grid Margin="15,8">
                    <TextBlock Text="Key Methods Internal Utility" Foreground="{StaticResource TextSecondary}" FontSize="10" HorizontalAlignment="Left"/>
                    <TextBlock x:Name="FooterVersion" Text="v1.0.0" Foreground="{StaticResource TextSecondary}" FontSize="10" HorizontalAlignment="Right"/>
                </Grid>
            </Border>
            
        </Grid>
    </Border>
</Window>
"@

    # Parse XAML
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()
    
    return $window
}

function Set-KMStatus {
    param(
        [System.Windows.Window]$Window,
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $statusBar = $Window.FindName("StatusBarText")
    if (-not $statusBar) { return }

    $statusBar.Text = $Message
    switch ($Level) {
        "Success" { $statusBar.Foreground = $Window.FindResource("SuccessGreen") }
        "Warning" { $statusBar.Foreground = $Window.FindResource("WarningYellow") }
        "Error" { $statusBar.Foreground = $Window.FindResource("DangerRed") }
        default { $statusBar.Foreground = $Window.FindResource("TextSecondary") }
    }
}

function Refresh-KMLogs {
    param([System.Windows.Window]$Window)

    $logOutput = $Window.FindName("LogOutput")
    if ($logOutput) {
        $logOutput.Text = Get-KMLogContent
        $logOutput.ScrollToEnd()
    }
}

#endregion

#region Main Application Logic
# ============================================================================
# MAIN APPLICATION LOGIC
# ============================================================================

function Start-MainApplication {
    param(
        [System.Windows.Window]$Window
    )
    
    # Get UI elements
    $navButtons = @{
        Home = $Window.FindName("NavHome")
        Apps = $Window.FindName("NavApps")
        Repairs = $Window.FindName("NavRepairs")
        Tweaks = $Window.FindName("NavTweaks")
        Maintenance = $Window.FindName("NavMaintenance")
        Logs = $Window.FindName("NavLogs")
        About = $Window.FindName("NavAbout")
    }
    
    $tabs = @{
        Home = $Window.FindName("TabHome")
        Apps = $Window.FindName("TabApps")
        Repairs = $Window.FindName("TabRepairs")
        Tweaks = $Window.FindName("TabTweaks")
        Maintenance = $Window.FindName("TabMaintenance")
        Logs = $Window.FindName("TabLogs")
        About = $Window.FindName("TabAbout")
    }
    
    # Show admin badge if running as admin
    $adminBadge = $Window.FindName("AdminBadge")
    if ($script:IsAdmin) {
        $adminBadge.Visibility = "Visible"
    }

    $Window.Title = Get-KMBrandingValue -Name "appTitle" -Fallback "Key Methods Workbench"
    $Window.FindName("FooterVersion").Text = "v$(Get-KMBrandingValue -Name 'version' -Fallback $script:AppVersion)"
    $Window.FindName("AboutUrl").Text = Get-KMBrandingValue -Name "websiteUrl" -Fallback $script:HostedBaseUrl
    $Window.FindName("AboutUrl").Add_MouseLeftButtonUp({
        Start-Process $Window.FindName("AboutUrl").Text
    })
    
    # Load logo
    $logoImage = $Window.FindName("LogoImage")
    $aboutLogo = $Window.FindName("AboutLogo")
    $logoPath = Join-Path $script:AssetPath "keymethods-logo.png"
    
    try {
        if (Test-Path $logoPath) {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = New-Object System.Uri($logoPath)
            $bitmap.EndInit()
            $logoImage.Source = $bitmap
            $aboutLogo.Source = $bitmap
        }
    }
    catch {
        Write-Warning "Failed to load logo: $_"
    }
    
    # Populate System Info
    $Window.FindName("SysHostname").Text = $env:COMPUTERNAME
    $Window.FindName("SysOSVersion").Text = (Get-CimInstance Win32_OperatingSystem).Caption
    $Window.FindName("SysUsername").Text = $env:USERNAME
    
    # Calculate uptime
    $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $lastBoot
    $Window.FindName("SysUptime").Text = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
    
    $Window.FindName("SysAdminStatus").Text = if ($script:IsAdmin) { "Yes" } else { "No" }
    $Window.FindName("SysAdminStatus").Foreground = if ($script:IsAdmin) { 
        [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(40, 167, 69)) 
    } else { 
        [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(255, 193, 7)) 
    }
    
    # Check package managers
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    $Window.FindName("SysWingetStatus").Text = if ($winget) { "Installed" } else { "Not Found" }
    $Window.FindName("SysChocoStatus").Text = if ($choco) { "Installed" } else { "Not Found" }
    
    # Navigation handler
    $switchTab = {
        param($targetTab)
        
        # Hide all tabs
        foreach ($tab in $tabs.Values) {
            $tab.Visibility = "Collapsed"
        }
        
        # Show target tab
        $tabs[$targetTab].Visibility = "Visible"
        
        # Update nav button states
        foreach ($button in $navButtons.GetEnumerator()) {
            if ($button.Key -eq $targetTab) {
                $button.Value.Tag = "Selected"
            } else {
                $button.Value.Tag = $null
            }
        }
        
        Write-KMLog -Message "Switched to $targetTab tab" -Level "Info"
    }
    
    # Bind navigation buttons
    $navButtons.Home.Add_Click({ & $switchTab "Home" })
    $navButtons.Apps.Add_Click({ & $switchTab "Apps" })
    $navButtons.Repairs.Add_Click({ & $switchTab "Repairs" })
    $navButtons.Tweaks.Add_Click({ & $switchTab "Tweaks" })
    $navButtons.Maintenance.Add_Click({ & $switchTab "Maintenance" })
    $navButtons.Logs.Add_Click({ & $switchTab "Logs" })
    $navButtons.About.Add_Click({ & $switchTab "About" })
    
    # Initialize Applications Tab
    Initialize-ApplicationsTab -Window $Window -Config $script:Applications
    
    # Initialize Repairs Tab
    Initialize-RepairsTab -Window $Window -Config $script:RepairActions
    
    # Initialize Tweaks Tab
    Initialize-TweaksTab -Window $Window

    # Initialize Maintenance Tab
    Initialize-MaintenanceTab -Window $Window -Config $script:MaintenanceActions
    
    # Initialize Logs Tab
    Initialize-LogsTab -Window $Window
    
    # Quick Actions handlers
    $Window.FindName("QuickFlushDNS").Add_Click({
        $result = Invoke-KMRepair -RepairAction (ConvertTo-KMHashtable ($script:RepairActions | Where-Object { $_.name -eq "Flush DNS Cache" } | Select-Object -First 1))
        if ($result.Success) {
            Set-KMStatus -Window $Window -Message "DNS cache flushed successfully." -Level "Success"
        } else {
            Set-KMStatus -Window $Window -Message "Failed to flush DNS cache." -Level "Error"
        }
        Refresh-KMLogs -Window $Window
    })
    
    $Window.FindName("QuickGPUpdate").Add_Click({
        $result = Invoke-KMRepair -RepairAction (ConvertTo-KMHashtable ($script:RepairActions | Where-Object { $_.name -eq "GPUpdate /Force" } | Select-Object -First 1))
        if ($result.Success) {
            Set-KMStatus -Window $Window -Message "Group Policy refreshed successfully." -Level "Success"
        } else {
            Set-KMStatus -Window $Window -Message "Group Policy refresh failed." -Level "Warning"
        }
        Refresh-KMLogs -Window $Window
    })
    
    $Window.FindName("QuickRestartExplorer").Add_Click({
        $confirm = [System.Windows.MessageBox]::Show("This will restart Windows Explorer. Continue?", "Confirm", "YesNo", "Warning")
        if ($confirm -eq "Yes") {
            $result = Invoke-KMRepair -RepairAction (ConvertTo-KMHashtable ($script:RepairActions | Where-Object { $_.name -eq "Restart Explorer" } | Select-Object -First 1))
            if ($result.Success) {
                Set-KMStatus -Window $Window -Message "Explorer restarted." -Level "Success"
            }
            else {
                Set-KMStatus -Window $Window -Message "Explorer restart failed." -Level "Error"
            }
            Refresh-KMLogs -Window $Window
        }
    })
    
    # Preset button handlers
    $Window.FindName("PresetNewWorkstation").Add_Click({
        & $switchTab "Apps"
        $Window.FindName("AppSelectRecommended").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        Set-KMStatus -Window $Window -Message "New Workstation preset loaded into Applications." -Level "Success"
    })
    
    $Window.FindName("PresetBasicUser").Add_Click({
        & $switchTab "Apps"
        $preset = $script:Presets.appPresets.BasicUserPC
        if ($preset) {
            $Window.FindName("AppSelectNone").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
            foreach ($item in $Window.FindName("AppListView").ItemsSource) {
                $item.IsSelected = $preset.applications -contains $item.Name
            }
            $Window.FindName("AppListView").Items.Refresh()
        }
        Set-KMStatus -Window $Window -Message "Basic User preset loaded into Applications." -Level "Success"
    })
    
    $Window.FindName("PresetTechBench").Add_Click({
        & $switchTab "Apps"
        $preset = $script:Presets.appPresets.TechBench
        if ($preset) {
            $Window.FindName("AppSelectNone").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
            foreach ($item in $Window.FindName("AppListView").ItemsSource) {
                $item.IsSelected = $preset.applications -contains $item.Name
            }
            $Window.FindName("AppListView").Items.Refresh()
        }
        Set-KMStatus -Window $Window -Message "Tech Bench preset loaded into Applications." -Level "Success"
    })
    
    $Window.FindName("MaintWingetUpgrade").Add_Click({
        $result = Update-KMPackages -Provider "Winget"
        Set-KMStatus -Window $Window -Message $(if ($result.Winget.Success) { "Winget upgrade completed." } else { "Winget upgrade did not complete successfully." }) -Level $(if ($result.Winget.Success) { "Success" } else { "Warning" })
        Refresh-KMLogs -Window $Window
    })

    $Window.FindName("MaintChocoUpgrade").Add_Click({
        $result = Update-KMPackages -Provider "Chocolatey"
        Set-KMStatus -Window $Window -Message $(if ($result.Chocolatey.Success) { "Chocolatey upgrade completed." } else { "Chocolatey upgrade did not complete successfully." }) -Level $(if ($result.Chocolatey.Success) { "Success" } else { "Warning" })
        Refresh-KMLogs -Window $Window
    })

    $Window.FindName("MaintExportSystem").Add_Click({
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.FileName = "KM-System-Summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $saveDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"

        if ($saveDialog.ShowDialog() -eq $true) {
            $result = Export-KMSystemSummary -OutputPath $saveDialog.FileName
            Set-KMStatus -Window $Window -Message $(if ($result.Success) { "System summary exported." } else { "System summary export failed." }) -Level $(if ($result.Success) { "Success" } else { "Error" })
        }
    })

    $Window.FindName("MaintExportApps").Add_Click({
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.FileName = "KM-Installed-Apps-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        $saveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"

        if ($saveDialog.ShowDialog() -eq $true) {
            Export-KMInstalledApplications -Path $saveDialog.FileName
            Set-KMStatus -Window $Window -Message "Installed applications exported." -Level "Success"
        }
    })

    $Window.FindName("MaintExportLogs").Add_Click({
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.FileName = "KM-Workbench-Logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $saveDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"

        if ($saveDialog.ShowDialog() -eq $true) {
            $success = Export-KMLogs -DestinationPath $saveDialog.FileName
            Set-KMStatus -Window $Window -Message $(if ($success) { "Logs exported." } else { "Log export failed." }) -Level $(if ($success) { "Success" } else { "Error" })
        }
    })
    
    # Show window
    $Window.ShowDialog() | Out-Null
}

#endregion

#region Initialization Functions

function Initialize-ApplicationsTab {
    param(
        [System.Windows.Window]$Window,
        [array]$Config
    )

    $appListView = $Window.FindName("AppListView")
    $searchBox = $Window.FindName("AppSearchBox")
    $categoryFilter = $Window.FindName("AppCategoryFilter")
    $presetButton = $Window.FindName("AppSelectRecommended")

    if (-not $appListView) {
        return
    }

    $categories = @(
        "All Categories"
        @(
            $Config |
                Where-Object {
                    $_.enabled -ne $false -and
                    $_.PSObject.Properties.Match("category").Count -gt 0 -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.category)
                } |
                ForEach-Object { [string]$_.category } |
                Sort-Object -Unique
        )
    )
    $categoryFilter.ItemsSource = $categories
    $categoryFilter.SelectedIndex = 0

    $appCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]

    foreach ($app in ($Config | Where-Object { $_.enabled -ne $false })) {
        $installedStatus = "Available"
        try {
            if (Test-KMApplicationInstalled -AppDefinition (ConvertTo-KMHashtable $app)) {
                $installedStatus = "Installed"
            }
        }
        catch {
            $installedStatus = "Unknown"
        }

        $appObj = New-Object PSObject -Property @{
            Name = $app.name
            Category = $app.category
            Provider = $app.provider
            Description = $app.description
            PackageId = $app.packageId
            InstalledStatus = $installedStatus
            Definition = $app
            IsSelected = $false
        }
        [void]$appCollection.Add($appObj)
    }

    $appListView.ItemsSource = $appCollection
    $appView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($appCollection)

    $applyFilter = {
        $search = if ($searchBox) { $searchBox.Text.Trim().ToLowerInvariant() } else { "" }
        $category = [string]$categoryFilter.SelectedItem

        $appView.Filter = {
            param($item)

            if ($category -and $category -ne "All Categories" -and $item.Category -ne $category) {
                return $false
            }

            if ([string]::IsNullOrWhiteSpace($search)) {
                return $true
            }

            return (($item.Name + " " + $item.Description + " " + $item.Provider + " " + $item.Category).ToLowerInvariant().Contains($search))
        }

        $appView.Refresh()
        Set-KMStatus -Window $Window -Message "$(@($appCollection | Where-Object { $_.IsSelected }).Count) app(s) selected." -Level "Info"
    }

    if ($searchBox) {
        $searchBox.Text = ""
        $searchBox.Add_TextChanged({ & $applyFilter })
    }
    $categoryFilter.Add_SelectionChanged({ & $applyFilter })

    $Window.FindName("AppSelectAll").Add_Click({
        foreach ($app in $appCollection) { $app.IsSelected = $true }
        $appListView.Items.Refresh()
        Set-KMStatus -Window $Window -Message "$(@($appCollection).Count) app(s) selected." -Level "Info"
    })

    $Window.FindName("AppSelectNone").Add_Click({
        foreach ($app in $appCollection) { $app.IsSelected = $false }
        $appListView.Items.Refresh()
        Set-KMStatus -Window $Window -Message "Application selection cleared." -Level "Info"
    })

    $presetButton.Add_Click({
        $presetName = if ($script:Presets.appPresets.KeyMethodsStandard) { "KeyMethodsStandard" } else { "NewWorkstation" }
        $preset = $script:Presets.appPresets.$presetName
        if ($preset) {
            foreach ($app in $appCollection) {
                $app.IsSelected = $preset.applications -contains $app.Name
            }
            $appListView.Items.Refresh()
            Set-KMStatus -Window $Window -Message "Preset '$($preset.name)' applied to the application list." -Level "Success"
        }
    })

    $Window.FindName("AppInstallSelected").Add_Click({
        $selectedApps = @($appCollection | Where-Object { $_.IsSelected })
        if ($selectedApps.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No applications selected.", "Information", "OK", "Information") | Out-Null
            return
        }

        $confirm = [System.Windows.MessageBox]::Show("Install $($selectedApps.Count) application(s)?", "Confirm Installation", "YesNo", "Question")
        if ($confirm -eq "Yes") {
            $successCount = 0
            $alreadyCount = 0
            $failedCount = 0

            foreach ($app in $selectedApps) {
                $result = Install-KMApplication -AppDefinition (ConvertTo-KMHashtable $app.Definition)
                if ($result.AlreadyInstalled) {
                    $alreadyCount++
                    $app.InstalledStatus = "Installed"
                }
                elseif ($result.Success) {
                    $successCount++
                    $app.InstalledStatus = "Installed"
                }
                else {
                    $failedCount++
                }
            }

            $appListView.Items.Refresh()
            Set-KMStatus -Window $Window -Message "Install complete. Success: $successCount. Already installed: $alreadyCount. Failed: $failedCount." -Level $(if ($failedCount -gt 0) { "Warning" } else { "Success" })
            Refresh-KMLogs -Window $Window
        }
    })

    $Window.FindName("AppUninstallSelected").Add_Click({
        $selectedApps = @($appCollection | Where-Object { $_.IsSelected })
        if ($selectedApps.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No applications selected.", "Information", "OK", "Information") | Out-Null
            return
        }

        $confirm = [System.Windows.MessageBox]::Show("Uninstall $($selectedApps.Count) application(s)?", "Confirm Uninstall", "YesNo", "Warning")
        if ($confirm -eq "Yes") {
            $successCount = 0
            $failedCount = 0

            foreach ($app in $selectedApps) {
                $result = Uninstall-KMApplication -AppDefinition (ConvertTo-KMHashtable $app.Definition)
                if ($result.Success) {
                    $successCount++
                    $app.InstalledStatus = "Available"
                }
                else {
                    $failedCount++
                }
            }

            $appListView.Items.Refresh()
            Set-KMStatus -Window $Window -Message "Uninstall complete. Success: $successCount. Failed: $failedCount." -Level $(if ($failedCount -gt 0) { "Warning" } else { "Success" })
            Refresh-KMLogs -Window $Window
        }
    })

    & $applyFilter
}

function Initialize-RepairsTab {
    param(
        [System.Windows.Window]$Window,
        [array]$Config
    )

    $safePanel = $Window.FindName("SafeRepairsPanel")
    $advancedPanel = $Window.FindName("AdvancedRepairsPanel")
    $dangerousPanel = $Window.FindName("DangerousRepairsPanel")
    $safeGroup = if ($Window.FindName("SafeRepairsGroup")) { $Window.FindName("SafeRepairsGroup") } else { $safePanel }
    $advancedGroup = if ($Window.FindName("AdvancedRepairsGroup")) { $Window.FindName("AdvancedRepairsGroup") } else { $advancedPanel }
    $dangerousGroup = if ($Window.FindName("DangerousRepairsGroup")) { $Window.FindName("DangerousRepairsGroup") } else { $dangerousPanel }

    if (-not $safePanel) {
        return
    }

    $safePanel.Children.Clear()
    $advancedPanel.Children.Clear()
    $dangerousPanel.Children.Clear()

    $repairCheckboxes = @()
    foreach ($action in $Config) {
        if ($action.enabled -eq $false) { continue }

        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $action.name
        $checkbox.Tag = $action
        $checkbox.Margin = "5"
        $checkbox.Foreground = [System.Windows.Media.Brushes]::White
        $checkbox.ToolTip = [string]::Join(
            [Environment]::NewLine,
            @(
                [string]$action.description
                "Category: $($action.category)"
                "Admin required: $($action.requiresAdmin)"
            )
        )

        $targetPanel = switch ([string]$action.dangerLevel) {
            "safe" { $safePanel; break }
            "advanced" { $advancedPanel; break }
            "dangerous" { $dangerousPanel; break }
            default { $safePanel }
        }

        try {
            [void]$targetPanel.Children.Add($checkbox)
        }
        catch {
            Write-KMLog -Message "Skipped repair UI element for '$($action.name)': $_" -Level "Warning"
            continue
        }

        $repairCheckboxes += $checkbox
    }

    $levelFilter = $Window.FindName("RepairLevelFilter")
    $levelFilter.ItemsSource = @("All Levels", "Safe Only", "Include Advanced", "Dangerous Only")
    $levelFilter.SelectedIndex = 0
    $levelFilter.Add_SelectionChanged({
        switch ([string]$levelFilter.SelectedItem) {
            "Safe Only" {
                $safeGroup.Visibility = "Visible"
                $advancedGroup.Visibility = "Collapsed"
                $dangerousGroup.Visibility = "Collapsed"
            }
            "Include Advanced" {
                $safeGroup.Visibility = "Visible"
                $advancedGroup.Visibility = "Visible"
                $dangerousGroup.Visibility = "Collapsed"
            }
            "Dangerous Only" {
                $safeGroup.Visibility = "Collapsed"
                $advancedGroup.Visibility = "Collapsed"
                $dangerousGroup.Visibility = "Visible"
            }
            default {
                $safeGroup.Visibility = "Visible"
                $advancedGroup.Visibility = "Visible"
                $dangerousGroup.Visibility = "Visible"
            }
        }
    })

    $Window.FindName("RepairRunSelected").Add_Click({
        $selectedActions = @($repairCheckboxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
        if ($selectedActions.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No repair actions selected.", "Information", "OK", "Information") | Out-Null
            return
        }

        $dangerous = @($selectedActions | Where-Object { $_.dangerLevel -eq "dangerous" })
        if ($dangerous) {
            $dangerList = ($dangerous | ForEach-Object { $_.name }) -join "`n"
            $confirm = [System.Windows.MessageBox]::Show(
                "The following dangerous actions are selected and require confirmation:`n`n$dangerList`n`nAre you sure you want to continue?",
                "Confirm Dangerous Actions",
                "YesNo",
                "Warning"
            )
            if ($confirm -ne "Yes") {
                return
            }
        }

        $successCount = 0
        $failedCount = 0
        $rebootRecommended = $false
        foreach ($action in $selectedActions) {
            $result = Invoke-KMRepair -RepairAction (ConvertTo-KMHashtable $action) -ConfirmDangerous
            if ($result.Success) {
                $successCount++
                if ($result.RequiresReboot) {
                    $rebootRecommended = $true
                }
            }
            else {
                $failedCount++
            }
        }

        Set-KMStatus -Window $Window -Message "Repairs completed. Success: $successCount. Failed: $failedCount$(if ($rebootRecommended) { '. Reboot recommended.' } else { '.' })" -Level $(if ($failedCount -gt 0) { "Warning" } else { "Success" })
        Refresh-KMLogs -Window $Window
    })
}

function Initialize-TweaksTab {
    param(
        [System.Windows.Window]$Window
    )

    $mapping = @{
        TweakShowFileExtensions = "ShowFileExtensions"
        TweakShowHiddenFiles = "ShowHiddenFiles"
        TweakShowProtectedFiles = "ShowProtectedOSFiles"
        TweakDisableFastStartup = "DisableFastStartup"
        TweakEnableRDP = "EnableRDP"
        TweakEnableRemoteAssistance = "EnableRemoteAssistance"
    }

    $refreshTweaks = {
        $tweakState = @{}
        foreach ($tweak in Get-KMTweaks) {
            $tweakState[$tweak.id] = $tweak.currentValue
        }

        foreach ($entry in $mapping.GetEnumerator()) {
            $control = $Window.FindName($entry.Key)
            if ($control) {
                $control.IsChecked = [bool]$tweakState[$entry.Value]
            }
        }
    }

    $Window.FindName("TweaksApply").Add_Click({
        $failed = @()
        $restartRecommended = $false

        foreach ($entry in $mapping.GetEnumerator()) {
            $control = $Window.FindName($entry.Key)
            $result = Apply-KMTweak -TweakId $entry.Value -Enable ([bool]$control.IsChecked)
            if (-not $result.Success) {
                $failed += $entry.Value
            }
            if ($result.RequiresRestart) {
                $restartRecommended = $true
            }
        }

        & $refreshTweaks

        if ($failed.Count -gt 0) {
            Set-KMStatus -Window $Window -Message "Some tweaks failed: $($failed -join ', ')." -Level "Warning"
        }
        else {
            Set-KMStatus -Window $Window -Message $(if ($restartRecommended) { "Tweaks applied. Restart recommended." } else { "Tweaks applied successfully." }) -Level "Success"
        }

        Refresh-KMLogs -Window $Window
    })

    & $refreshTweaks
}

function Initialize-MaintenanceTab {
    param(
        [System.Windows.Window]$Window,
        [array]$Config
    )
    
    $toolsPanel = $Window.FindName("MaintenanceToolsPanel")
    
    foreach ($action in $Config) {
        $button = New-Object System.Windows.Controls.Button
        $button.Content = $action.name
        $button.ToolTip = $action.description
        $button.Style = $Window.FindResource("ActionButtonStyle")
        $button.Margin = "5"
        $toolId = [string]$action.id
        $toolName = [string]$action.name

        $button.Add_Click({
            if ($toolId -in @("restartcomputer", "shutdowncomputer")) {
                $confirm = [System.Windows.MessageBox]::Show("Run '$toolName'?", "Confirm Maintenance Action", "YesNo", "Warning")
                if ($confirm -ne "Yes") {
                    return
                }
            }

            $result = Start-KMMaintenanceTool -ToolId $toolId
            if ($result.Success) {
                Set-KMStatus -Window $Window -Message "$toolName launched." -Level "Success"
            }
            else {
                Set-KMStatus -Window $Window -Message "Failed to launch $toolName." -Level "Error"
            }

            Refresh-KMLogs -Window $Window
        }.GetNewClosure())
        
        [void]$toolsPanel.Children.Add($button)
    }
}

function Initialize-LogsTab {
    param(
        [System.Windows.Window]$Window
    )
    
    $refreshLogs = {
        Refresh-KMLogs -Window $Window
        Set-KMStatus -Window $Window -Message "Logs refreshed at $(Get-Date -Format 'HH:mm:ss')." -Level "Info"
    }

    & $refreshLogs

    $Window.FindName("LogRefresh").Add_Click($refreshLogs)
    
    $Window.FindName("LogClear").Add_Click({
        $confirm = [System.Windows.MessageBox]::Show("Clear all logs?", "Confirm", "YesNo", "Warning")
        if ($confirm -eq "Yes") {
            Clear-KMLogs
            & $refreshLogs
        }
    })
    
    $Window.FindName("LogExport").Add_Click({
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.FileName = "KM-Workbench-Logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $saveDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        
        if ($saveDialog.ShowDialog() -eq $true) {
            Get-KMLogContent | Set-Content -Path $saveDialog.FileName
            [System.Windows.MessageBox]::Show("Logs exported to:`n$($saveDialog.FileName)", "Export Complete", "OK", "Information")
        }
    })
}

#endregion

#region Entry Point
# ============================================================================
# ENTRY POINT
# ============================================================================

try {
    Write-Host "Initializing Key Methods Workbench GUI..." -ForegroundColor Cyan
    
    # Create and show window
    $window = Initialize-MainWindow
    Start-MainApplication -Window $window
}
catch {
    Write-Error "Failed to start application: $_"
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
finally {
    Write-KMLog -Message "Key Methods Workbench session ended" -Level "Info"
}

#endregion
