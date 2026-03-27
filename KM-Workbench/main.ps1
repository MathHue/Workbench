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

# Load configuration files
$script:Branding = @{}
$script:Applications = @()
$script:RepairActions = @()
$script:MaintenanceActions = @()
$script:Presets = @{}

try {
    $brandingFile = Join-Path $script:ConfigPath "branding.json"
    if (Test-Path $brandingFile) {
        $script:Branding = Get-Content $brandingFile -Raw | ConvertFrom-Json -AsHashtable
    }
}
catch {
    Write-Warning "Failed to load branding configuration: $_"
}

try {
    $appsFile = Join-Path $script:ConfigPath "applications.json"
    if (Test-Path $appsFile) {
        $script:Applications = Get-Content $appsFile -Raw | ConvertFrom-Json -AsHashtable
    }
}
catch {
    Write-Warning "Failed to load applications configuration: $_"
}

try {
    $repairsFile = Join-Path $script:ConfigPath "repair-actions.json"
    if (Test-Path $repairsFile) {
        $script:RepairActions = Get-Content $repairsFile -Raw | ConvertFrom-Json -AsHashtable
    }
}
catch {
    Write-Warning "Failed to load repair actions configuration: $_"
}

try {
    $maintenanceFile = Join-Path $script:ConfigPath "maintenance-actions.json"
    if (Test-Path $maintenanceFile) {
        $script:MaintenanceActions = Get-Content $maintenanceFile -Raw | ConvertFrom-Json -AsHashtable
    }
}
catch {
    Write-Warning "Failed to load maintenance actions configuration: $_"
}

try {
    $presetsFile = Join-Path $script:ConfigPath "presets.json"
    if (Test-Path $presetsFile) {
        $script:Presets = Get-Content $presetsFile -Raw | ConvertFrom-Json -AsHashtable
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

Add-Type -AssemblyName PresentationFramework
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
        Background="#FF1E1E1E">
    
    <Window.Resources>
        <!-- Colors based on Key Methods branding -->
        <SolidColorBrush x:Key="PrimaryBlue" Color="#0072C6"/>
        <SolidColorBrush x:Key="PrimaryOrange" Color="#F26522"/>
        <SolidColorBrush x:Key="DarkBackground" Color="#FF1E1E1E"/>
        <SolidColorBrush x:Key="DarkerBackground" Color="#FF151515"/>
        <SolidColorBrush x:Key="LightBackground" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="TextSecondary" Color="#FFAAAAAA"/>
        <SolidColorBrush x:Key="SuccessGreen" Color="#FF28A745"/>
        <SolidColorBrush x:Key="WarningYellow" Color="#FFFFC107"/>
        <SolidColorBrush x:Key="DangerRed" Color="#FFDC3545"/>
        
        <!-- Style for Navigation Buttons -->
        <Style x:Key="NavButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="15,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                BorderBrush="{StaticResource PrimaryBlue}"
                                BorderThickness="4,0,0,0"
                                Opacity="0">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                            VerticalAlignment="Center"
                                            Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{StaticResource LightBackground}"/>
                            </Trigger>
                            <Trigger Property="Tag" Value="Selected">
                                <Setter Property="Background" Value="{StaticResource LightBackground}"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                                <Setter TargetName="Border" Property="Opacity" Value="1"/>
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
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="4"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center"
                                            VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#005A9E"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#FF555555"/>
                    <Setter Property="Opacity" Value="0.6"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Style for Warning/Orange Buttons -->
        <Style x:Key="WarningButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="{StaticResource PrimaryOrange}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#D35400"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Style for Danger/Red Buttons -->
        <Style x:Key="DangerButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="{StaticResource DangerRed}"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#C82333"/>
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
            <Setter Property="FontSize" Value="12"/>
        </Style>
        
        <!-- Style for ListViews -->
        <Style x:Key="DarkListViewStyle" TargetType="ListView">
            <Setter Property="Background" Value="{StaticResource DarkerBackground}"/>
            <Setter Property="BorderBrush" Value="{StaticResource LightBackground}"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        
        <!-- Style for GroupBoxes -->
        <Style x:Key="DarkGroupBoxStyle" TargetType="GroupBox">
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="BorderBrush" Value="{StaticResource LightBackground}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
    </Window.Resources>
    
    <Border Background="{StaticResource DarkBackground}">
        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Header -->
            <Border Grid.Row="0" Background="{StaticResource DarkerBackground}" BorderBrush="{StaticResource LightBackground}" BorderThickness="0,0,0,1">
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
                        <TextBlock Text="Key Methods Workbench" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextPrimary}"/>
                        <TextBlock Text="Install. Repair. Maintain." FontSize="11" Foreground="{StaticResource TextSecondary}" FontStyle="Italic"/>
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
                <Border Grid.Column="0" Background="{StaticResource DarkerBackground}" BorderBrush="{StaticResource LightBackground}" BorderThickness="0,0,1,0">
                    <StackPanel x:Name="NavigationPanel" Margin="0,10">
                        <Button x:Name="NavHome" Content="🏠 Home" Style="{StaticResource NavButtonStyle}" Tag="Selected"/>
                        <Button x:Name="NavApps" Content="📦 Applications" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavRepairs" Content="🔧 Repairs" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavTweaks" Content="⚡ Tweaks" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavMaintenance" Content="🛠️ Maintenance" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavLogs" Content="📋 Logs" Style="{StaticResource NavButtonStyle}"/>
                        <Button x:Name="NavAbout" Content="ℹ️ About" Style="{StaticResource NavButtonStyle}"/>
                    </StackPanel>
                </Border>
                
                <!-- Content Area -->
                <Border Grid.Column="1" Background="{StaticResource DarkBackground}">
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
                                        <GridViewColumn Header="Description" Width="*" DisplayMemberBinding="{Binding Description}"/>
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
                                    <GroupBox Header="Safe Repairs" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="SafeRepairsPanel" Margin="10"/>
                                    </GroupBox>
                                    
                                    <!-- Advanced Repairs Section -->
                                    <GroupBox Header="Advanced Repairs (Use with caution)" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="AdvancedRepairsPanel" Margin="10"/>
                                    </GroupBox>
                                    
                                    <!-- Dangerous Repairs Section -->
                                    <GroupBox Header="⚠️ Dangerous Repairs (Confirmation Required)" Style="{StaticResource DarkGroupBoxStyle}">
                                        <WrapPanel x:Name="DangerousRepairsPanel" Margin="10"/>
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
                                            <WrapPanel x:Name="MaintenanceToolsPanel" Margin="10"/>
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
                            
                            <StatusBar Grid.Row="2" Background="{StaticResource DarkerBackground}" Margin="0,5,0,0">
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
            <Border Grid.Row="2" Background="{StaticResource DarkerBackground}" BorderBrush="{StaticResource LightBackground}" BorderThickness="0,1,0,0">
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
    
    # Initialize Maintenance Tab
    Initialize-MaintenanceTab -Window $Window -Config $script:MaintenanceActions
    
    # Initialize Logs Tab
    Initialize-LogsTab -Window $Window
    
    # Quick Actions handlers
    $Window.FindName("QuickFlushDNS").Add_Click({
        Write-KMLog -Message "Running: ipconfig /flushdns" -Level "Info"
        $result = Invoke-KMCommand -Command "ipconfig" -Arguments @("/flushdns")
        if ($result.Success) {
            [System.Windows.MessageBox]::Show("DNS cache flushed successfully.", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Failed to flush DNS cache.`n`n$($result.Output)", "Error", "OK", "Error")
        }
    })
    
    $Window.FindName("QuickGPUpdate").Add_Click({
        Write-KMLog -Message "Running: gpupdate /force" -Level "Info"
        $result = Invoke-KMCommand -Command "gpupdate" -Arguments @("/force")
        if ($result.Success) {
            [System.Windows.MessageBox]::Show("Group Policy updated successfully.", "Success", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Group Policy update completed with warnings.`n`n$($result.Output)", "Warning", "OK", "Warning")
        }
    })
    
    $Window.FindName("QuickRestartExplorer").Add_Click({
        $confirm = [System.Windows.MessageBox]::Show("This will restart Windows Explorer. Continue?", "Confirm", "YesNo", "Warning")
        if ($confirm -eq "Yes") {
            Write-KMLog -Message "Restarting Windows Explorer" -Level "Warning"
            Stop-Process -Name explorer -Force
            Start-Sleep -Seconds 2
            Start-Process explorer
            Write-KMLog -Message "Explorer restarted" -Level "Success"
        }
    })
    
    # Footer version
    $Window.FindName("FooterVersion").Text = "v$script:AppVersion"
    
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
    $categoryFilter = $Window.FindName("AppCategoryFilter")
    
    # Populate categories
    $categories = @("All Categories") + ($Config | Select-Object -ExpandProperty Category -Unique | Sort-Object)
    $categoryFilter.ItemsSource = $categories
    
    # Create observable collection for apps
    $appCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
    
    foreach ($app in $Config) {
        $appObj = New-Object PSObject -Property @{
            Name = $app.name
            Category = $app.category
            Provider = $app.provider
            Description = $app.description
            PackageId = $app.packageId
            IsSelected = $false
        }
        $appCollection.Add($appObj)
    }
    
    $appListView.ItemsSource = $appCollection
}

function Initialize-RepairsTab {
    param(
        [System.Windows.Window]$Window,
        [array]$Config
    )
    
    $safePanel = $Window.FindName("SafeRepairsPanel")
    $advancedPanel = $Window.FindName("AdvancedRepairsPanel")
    $dangerousPanel = $Window.FindName("DangerousRepairsPanel")
    
    # Clear existing
    $safePanel.Children.Clear()
    $advancedPanel.Children.Clear()
    $dangerousPanel.Children.Clear()
    
    foreach ($action in $Config) {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $action.name
        $checkbox.ToolTip = $action.description
        $checkbox.Tag = $action
        $checkbox.Style = $Window.FindResource("DarkCheckBoxStyle")
        $checkbox.Margin = "5"
        
        switch ($action.dangerLevel) {
            "safe" { $safePanel.Children.Add($checkbox) }
            "advanced" { $advancedPanel.Children.Add($checkbox) }
            "dangerous" { $dangerousPanel.Children.Add($checkbox) }
        }
    }
    
    # Run Selected button
    $Window.FindName("RepairRunSelected").Add_Click({
        $selectedActions = @()
        
        foreach ($panel in @($safePanel, $advancedPanel, $dangerousPanel)) {
            foreach ($child in $panel.Children) {
                if ($child.IsChecked -eq $true) {
                    $selectedActions += $child.Tag
                }
            }
        }
        
        if ($selectedActions.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No repair actions selected.", "Information", "OK", "Information")
            return
        }
        
        # Check for dangerous actions
        $dangerous = $selectedActions | Where-Object { $_.dangerLevel -eq "dangerous" }
        if ($dangerous) {
            $dangerList = $dangerous | ForEach-Object { "• $($_.name)" } | Out-String
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
        
        # Execute actions
        foreach ($action in $selectedActions) {
            Write-KMLog -Message "Running repair: $($action.name)" -Level "Info"
            $result = Invoke-KMCommand -Command $action.command -Arguments $action.arguments
            if ($result.Success) {
                Write-KMLog -Message "$($action.name) completed successfully" -Level "Success"
            } else {
                Write-KMLog -Message "$($action.name) failed: $($result.Error)" -Level "Error"
            }
        }
        
        [System.Windows.MessageBox]::Show("Selected repairs completed. Check the Logs tab for details.", "Complete", "OK", "Information")
    })
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
        
        $button.Add_Click({
            Write-KMLog -Message "Launching: $($action.name)" -Level "Info"
            try {
                if ($action.command -eq "shell" -and $action.shellCommand) {
                    Start-Process $action.shellCommand -ArgumentList $action.arguments
                } else {
                    Start-Process $action.command -ArgumentList $action.arguments
                }
            }
            catch {
                Write-KMLog -Message "Failed to launch $($action.name): $_" -Level "Error"
            }
        })
        
        $toolsPanel.Children.Add($button)
    }
}

function Initialize-LogsTab {
    param(
        [System.Windows.Window]$Window
    )
    
    $logOutput = $Window.FindName("LogOutput")
    $statusBar = $Window.FindName("StatusBarText")
    
    # Function to refresh logs
    $refreshLogs = {
        $logContent = Get-KMLogContent
        $logOutput.Text = $logContent
        $logOutput.ScrollToEnd()
        $statusBar.Text = "Last updated: $(Get-Date -Format 'HH:mm:ss')"
    }
    
    # Initial load
    & $refreshLogs
    
    # Button handlers
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
