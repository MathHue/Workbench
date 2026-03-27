Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Data

function Show-WorkbenchShell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Branding,

        [switch]$AutoClose
    )

    $appCatalog = Get-ApplicationCatalog
    $repairCatalog = Get-RepairCatalog
    $presetCatalog = Get-PresetCatalog
    $maintenanceCatalog = Get-MaintenanceCatalog
    $tweakCatalog = Get-TweakCatalog

    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Key Methods Workbench"
        Width="1380"
        Height="900"
        MinWidth="1180"
        MinHeight="760"
        WindowStartupLocation="CenterScreen"
        Background="#161A1F">
    <Grid Background="#161A1F">
        <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="40" />
        </Grid.RowDefinitions>
        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="240" />
                <ColumnDefinition Width="*" />
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="#11161B" BorderBrush="#27303A" BorderThickness="0,0,1,0">
                <DockPanel LastChildFill="True">
                    <StackPanel DockPanel.Dock="Top" Margin="18,24,18,16">
                        <Border Background="#20262D" CornerRadius="14" Padding="14">
                            <Grid>
                                <Image x:Name="BrandLogo" Height="48" Stretch="Uniform" />
                                <TextBlock x:Name="BrandFallbackText" Visibility="Collapsed" Foreground="#F5F7FA" FontSize="20" FontWeight="SemiBold" TextAlignment="Center" VerticalAlignment="Center" Text="Key Methods" />
                            </Grid>
                        </Border>
                        <TextBlock x:Name="NavAppName" Margin="0,18,0,0" Foreground="#F5F7FA" FontSize="28" FontWeight="SemiBold" Text="Key Methods Workbench" />
                        <TextBlock x:Name="NavTagline" Margin="0,6,0,0" Foreground="#AAB6C3" FontSize="14" TextWrapping="Wrap" Text="Install. Repair. Maintain." />
                    </StackPanel>
                    <StackPanel DockPanel.Dock="Top" Margin="14,10,14,0">
                        <Button x:Name="NavHome" Content="Home" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavApplications" Content="Applications" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavRepairs" Content="Repairs" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavTweaks" Content="Tweaks" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavMaintenance" Content="Maintenance" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavLogs" Content="Logs" Height="40" Margin="0,0,0,8" />
                        <Button x:Name="NavAbout" Content="About" Height="40" Margin="0,0,0,8" />
                    </StackPanel>
                    <TextBlock x:Name="CompanyText" DockPanel.Dock="Bottom" Margin="18,18,18,22" Foreground="#7F93A8" FontSize="13" Text="Key Methods" />
                </DockPanel>
            </Border>
            <Grid Grid.Column="1" Margin="18">
                <Border Background="#20262D" CornerRadius="24" Padding="26">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto" />
                            <RowDefinition Height="*" />
                        </Grid.RowDefinitions>
                        <StackPanel Grid.Row="0" Margin="0,0,0,18">
                            <TextBlock x:Name="PageTitle" Foreground="#F5F7FA" FontSize="30" FontWeight="SemiBold" Text="Home" />
                            <TextBlock x:Name="PageSubtitle" Margin="0,6,0,0" Foreground="#AAB6C3" FontSize="14" TextWrapping="Wrap" Text="Install. Repair. Maintain." />
                        </StackPanel>
                        <Grid Grid.Row="1">
                            <Grid x:Name="HomePage">
                                <ScrollViewer VerticalScrollBarVisibility="Auto">
                                    <StackPanel>
                                        <WrapPanel Margin="0,0,0,18">
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="185"><StackPanel><TextBlock Text="Computer Name" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileComputerName" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" TextWrapping="Wrap" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="185"><StackPanel><TextBlock Text="Current User" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileCurrentUser" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" TextWrapping="Wrap" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="260"><StackPanel><TextBlock Text="Windows Version" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileWindowsVersion" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" TextWrapping="Wrap" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="160"><StackPanel><TextBlock Text="Uptime" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileUptime" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="160"><StackPanel><TextBlock Text="Admin" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileAdminStatus" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="170"><StackPanel><TextBlock Text="Winget" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileWinget" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" /></StackPanel></Border>
                                            <Border Background="#27303A" CornerRadius="14" Padding="16" Margin="0,0,14,14" Width="170"><StackPanel><TextBlock Text="Chocolatey" Foreground="#AAB6C3" FontSize="12" /><TextBlock x:Name="TileChocolatey" Margin="0,8,0,0" Foreground="#F5F7FA" FontSize="17" FontWeight="SemiBold" Text="-" /></StackPanel></Border>
                                        </WrapPanel>
                                        <Border Background="#1B2128" CornerRadius="18" Padding="20">
                                            <StackPanel>
                                                <TextBlock Text="Quick Actions" Foreground="#F5F7FA" FontSize="20" FontWeight="SemiBold" />
                                                <WrapPanel Margin="0,18,0,0">
                                                    <Button x:Name="HomeApplicationsButton" Content="Launch Applications Tab" Width="200" Height="42" Margin="0,0,12,12" />
                                                    <Button x:Name="HomeRepairsButton" Content="Launch Repairs Tab" Width="180" Height="42" Margin="0,0,12,12" />
                                                    <Button x:Name="HomeRecommendedRepairsButton" Content="Run Recommended Repairs" Width="220" Height="42" Margin="0,0,12,12" />
                                                    <Button x:Name="HomeExportSummaryButton" Content="Export System Summary" Width="190" Height="42" Margin="0,0,12,12" />
                                                </WrapPanel>
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                            <Grid x:Name="ApplicationsPage" Visibility="Collapsed">
                                <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
                                <WrapPanel Grid.Row="0" Margin="0,0,0,12">
                                    <TextBox x:Name="AppSearchBox" Width="240" Height="34" Margin="0,0,12,12" />
                                    <ComboBox x:Name="AppCategoryFilter" Width="180" Height="34" Margin="0,0,12,12" />
                                    <ComboBox x:Name="AppPresetFilter" Width="220" Height="34" Margin="0,0,12,12" />
                                    <Button x:Name="ApplyPresetButton" Content="Apply Preset" Width="120" Height="34" Margin="0,0,12,12" />
                                </WrapPanel>
                                <DataGrid x:Name="ApplicationsGrid" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal" RowBackground="#27303A" AlternatingRowBackground="#2C3540" Background="#1B2128" Foreground="#F5F7FA" BorderBrush="#3A4653" Margin="0,0,0,12">
                                    <DataGrid.Columns>
                                        <DataGridCheckBoxColumn Binding="{Binding IsSelected}" Header="Select" Width="70" />
                                        <DataGridTextColumn Binding="{Binding Name}" Header="App name" Width="180" />
                                        <DataGridTextColumn Binding="{Binding Category}" Header="Category" Width="140" />
                                        <DataGridTextColumn Binding="{Binding Provider}" Header="Provider" Width="120" />
                                        <DataGridTextColumn Binding="{Binding Description}" Header="Description" Width="*" />
                                    </DataGrid.Columns>
                                </DataGrid>
                                <WrapPanel Grid.Row="2">
                                    <Button x:Name="InstallSelectedAppsButton" Content="Install Selected" Width="140" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="UninstallSelectedAppsButton" Content="Uninstall Selected" Width="150" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="SelectRecommendedAppsButton" Content="Select Recommended" Width="150" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="RefreshAppsButton" Content="Refresh App List" Width="140" Height="38" />
                                </WrapPanel>
                            </Grid>
                            <Grid x:Name="RepairsPage" Visibility="Collapsed">
                                <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
                                <WrapPanel Grid.Row="0" Margin="0,0,0,12">
                                    <TextBox x:Name="RepairSearchBox" Width="240" Height="34" Margin="0,0,12,12" />
                                    <ComboBox x:Name="RepairGroupFilter" Width="180" Height="34" Margin="0,0,12,12" />
                                </WrapPanel>
                                <DataGrid x:Name="RepairsGrid" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal" RowBackground="#27303A" AlternatingRowBackground="#2C3540" Background="#1B2128" Foreground="#F5F7FA" BorderBrush="#3A4653" Margin="0,0,0,12">
                                    <DataGrid.Columns>
                                        <DataGridCheckBoxColumn Binding="{Binding IsSelected}" Header="Select" Width="70" />
                                        <DataGridTextColumn Binding="{Binding Name}" Header="Repair action" Width="180" />
                                        <DataGridTextColumn Binding="{Binding Group}" Header="Group" Width="100" />
                                        <DataGridTextColumn Binding="{Binding Reboot}" Header="Reboot" Width="100" />
                                        <DataGridTextColumn Binding="{Binding Description}" Header="Description" Width="260" />
                                        <DataGridTextColumn Binding="{Binding Command}" Header="Command" Width="*" />
                                    </DataGrid.Columns>
                                </DataGrid>
                                <WrapPanel Grid.Row="2">
                                    <Button x:Name="RunRepairsButton" Content="Run Selected Repairs" Width="170" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="PreviewRepairsButton" Content="Preview Selected Commands" Width="190" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="SelectRecommendedRepairsButton" Content="Select Recommended Repairs" Width="190" Height="38" />
                                </WrapPanel>
                            </Grid>
                            <Grid x:Name="TweaksPage" Visibility="Collapsed">
                                <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /><RowDefinition Height="Auto" /></Grid.RowDefinitions>
                                <TextBlock Grid.Row="0" Margin="0,0,0,12" Foreground="#AAB6C3" Text="Practical Windows tweaks only. Core Microsoft security protections are not modified." TextWrapping="Wrap" />
                                <DataGrid x:Name="TweaksGrid" Grid.Row="1" AutoGenerateColumns="False" CanUserAddRows="False" CanUserDeleteRows="False" HeadersVisibility="Column" GridLinesVisibility="Horizontal" RowBackground="#27303A" AlternatingRowBackground="#2C3540" Background="#1B2128" Foreground="#F5F7FA" BorderBrush="#3A4653" Margin="0,0,0,12">
                                    <DataGrid.Columns>
                                        <DataGridCheckBoxColumn Binding="{Binding IsSelected}" Header="Select" Width="70" />
                                        <DataGridTextColumn Binding="{Binding Name}" Header="Tweak" Width="200" />
                                        <DataGridTextColumn Binding="{Binding Risk}" Header="Risk" Width="120" />
                                        <DataGridTextColumn Binding="{Binding Description}" Header="Description" Width="*" />
                                    </DataGrid.Columns>
                                </DataGrid>
                                <WrapPanel Grid.Row="2">
                                    <Button x:Name="ApplyTweaksButton" Content="Apply Selected Tweaks" Width="170" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="SelectRecommendedTweaksButton" Content="Select Recommended" Width="150" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="ClearTweakSelectionButton" Content="Clear Selection" Width="130" Height="38" />
                                </WrapPanel>
                            </Grid>
                            <Grid x:Name="MaintenancePage" Visibility="Collapsed">
                                <ScrollViewer VerticalScrollBarVisibility="Auto">
                                    <StackPanel>
                                        <TextBlock Foreground="#AAB6C3" Margin="0,0,0,14" Text="Built-in Windows tools and common maintenance helpers." />
                                        <WrapPanel x:Name="MaintenanceButtonsPanel" Margin="0,0,0,18" />
                                        <Border Background="#1B2128" CornerRadius="18" Padding="20">
                                            <WrapPanel>
                                                <Button x:Name="UpgradePackagesButton" Content="Upgrade All Supported Packages" Width="230" Height="42" Margin="0,0,12,12" />
                                                <Button x:Name="ExportInstalledAppsButton" Content="Export Installed Apps List" Width="200" Height="42" Margin="0,0,12,12" />
                                                <Button x:Name="MaintenanceExportSummaryButton" Content="Export System Summary" Width="180" Height="42" Margin="0,0,12,12" />
                                                <Button x:Name="OpenLogsFolderButton" Content="Open Logs Folder" Width="150" Height="42" Margin="0,0,12,12" />
                                            </WrapPanel>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                            <Grid x:Name="LogsPage" Visibility="Collapsed">
                                <Grid.RowDefinitions><RowDefinition Height="Auto" /><RowDefinition Height="*" /></Grid.RowDefinitions>
                                <WrapPanel Grid.Row="0" Margin="0,0,0,12">
                                    <Button x:Name="RefreshLogsButton" Content="Refresh Logs" Width="120" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="LogsOpenFolderButton" Content="Open Log Folder" Width="140" Height="38" Margin="0,0,12,0" />
                                    <Button x:Name="ExportSessionLogButton" Content="Export Current Session Log" Width="190" Height="38" />
                                </WrapPanel>
                                <TextBox x:Name="LogViewerTextBox" Grid.Row="1" IsReadOnly="True" AcceptsReturn="True" AcceptsTab="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" TextWrapping="NoWrap" FontFamily="Consolas" Background="#13171C" Foreground="#F5F7FA" BorderBrush="#3A4653" />
                            </Grid>
                            <Grid x:Name="AboutPage" Visibility="Collapsed">
                                <ScrollViewer VerticalScrollBarVisibility="Auto">
                                    <StackPanel>
                                        <TextBlock x:Name="AboutTitleText" Foreground="#F5F7FA" FontSize="24" FontWeight="SemiBold" Text="Key Methods Workbench" />
                                        <TextBlock x:Name="AboutSubtitleText" Margin="0,8,0,0" Foreground="#AAB6C3" FontSize="14" Text="Key Methods Internal Utility" />
                                        <Border Background="#1B2128" CornerRadius="18" Padding="20" Margin="0,18,0,0">
                                            <StackPanel>
                                                <TextBlock x:Name="AboutVersionText" Foreground="#F5F7FA" FontSize="16" Margin="0,0,0,10" />
                                                <TextBlock x:Name="AboutSupportText" Foreground="#F5F7FA" TextWrapping="Wrap" Margin="0,0,0,16" />
                                                <TextBlock x:Name="AboutWebsiteText" Foreground="#8EC5FF" TextWrapping="Wrap" Margin="0,0,0,10" />
                                                <TextBlock x:Name="AboutBootstrapText" Foreground="#F0B06A" TextWrapping="Wrap" />
                                            </StackPanel>
                                        </Border>
                                    </StackPanel>
                                </ScrollViewer>
                            </Grid>
                        </Grid>
                    </Grid>
                </Border>
            </Grid>
        </Grid>
        <Border Grid.Row="1" Background="#11161B" BorderBrush="#27303A" BorderThickness="1,1,0,0">
            <TextBlock x:Name="StatusText" Margin="16,0,16,0" VerticalAlignment="Center" Foreground="#F5F7FA" Text="Ready." />
        </Border>
    </Grid>
</Window>
'@

    $xmlReader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($xmlReader)

    $names = @(
        'BrandLogo', 'BrandFallbackText', 'NavAppName', 'NavTagline', 'CompanyText',
        'NavHome', 'NavApplications', 'NavRepairs', 'NavTweaks', 'NavMaintenance', 'NavLogs', 'NavAbout',
        'PageTitle', 'PageSubtitle', 'HomePage', 'ApplicationsPage', 'RepairsPage', 'TweaksPage', 'MaintenancePage', 'LogsPage', 'AboutPage',
        'TileComputerName', 'TileCurrentUser', 'TileWindowsVersion', 'TileUptime', 'TileAdminStatus', 'TileWinget', 'TileChocolatey',
        'HomeApplicationsButton', 'HomeRepairsButton', 'HomeRecommendedRepairsButton', 'HomeExportSummaryButton',
        'AppSearchBox', 'AppCategoryFilter', 'AppPresetFilter', 'ApplyPresetButton', 'ApplicationsGrid', 'InstallSelectedAppsButton', 'UninstallSelectedAppsButton', 'SelectRecommendedAppsButton', 'RefreshAppsButton',
        'RepairSearchBox', 'RepairGroupFilter', 'RepairsGrid', 'RunRepairsButton', 'PreviewRepairsButton', 'SelectRecommendedRepairsButton',
        'TweaksGrid', 'ApplyTweaksButton', 'SelectRecommendedTweaksButton', 'ClearTweakSelectionButton',
        'MaintenanceButtonsPanel', 'UpgradePackagesButton', 'ExportInstalledAppsButton', 'MaintenanceExportSummaryButton', 'OpenLogsFolderButton',
        'RefreshLogsButton', 'LogsOpenFolderButton', 'ExportSessionLogButton', 'LogViewerTextBox',
        'AboutTitleText', 'AboutSubtitleText', 'AboutVersionText', 'AboutSupportText', 'AboutWebsiteText', 'AboutBootstrapText',
        'StatusText'
    )

    $ui = @{}
    foreach ($name in $names) {
        $ui[$name] = $window.FindName($name)
    }

    $window.Title = $Branding.WindowTitle
    $ui.NavAppName.Text = $Branding.AppName
    $ui.NavTagline.Text = $Branding.Tagline
    $ui.CompanyText.Text = $Branding.CompanyName
    $ui.PageSubtitle.Text = $Branding.Tagline

    if ($Branding.HasLogo) {
        $ui.BrandLogo.Source = Get-BrandImageSource -Path $Branding.LogoPath
        $ui.BrandFallbackText.Visibility = 'Collapsed'
    }
    else {
        $ui.BrandLogo.Visibility = 'Collapsed'
        $ui.BrandFallbackText.Visibility = 'Visible'
        $ui.BrandFallbackText.Text = $Branding.CompanyName
    }

    $navButtons = @($ui.NavHome, $ui.NavApplications, $ui.NavRepairs, $ui.NavTweaks, $ui.NavMaintenance, $ui.NavLogs, $ui.NavAbout)
    foreach ($button in $navButtons) {
        $button.Foreground = [System.Windows.Media.Brushes]::White
        $button.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#20262D')
        $button.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#36414D')
        $button.BorderThickness = '1'
        $button.FontSize = 14
        $button.FontWeight = 'SemiBold'
    }

    $standardButtonBackground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Branding.AccentColor)
    $warningButtonBackground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Branding.WarningColor)
    $neutralButtonBackground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#313B46')

    $standardButtons = @(
        $ui.HomeApplicationsButton, $ui.HomeRepairsButton, $ui.HomeExportSummaryButton,
        $ui.InstallSelectedAppsButton, $ui.UninstallSelectedAppsButton, $ui.SelectRecommendedAppsButton, $ui.RefreshAppsButton, $ui.ApplyPresetButton,
        $ui.RunRepairsButton, $ui.PreviewRepairsButton, $ui.SelectRecommendedRepairsButton,
        $ui.ApplyTweaksButton, $ui.SelectRecommendedTweaksButton, $ui.ClearTweakSelectionButton,
        $ui.UpgradePackagesButton, $ui.ExportInstalledAppsButton, $ui.MaintenanceExportSummaryButton, $ui.OpenLogsFolderButton,
        $ui.RefreshLogsButton, $ui.LogsOpenFolderButton, $ui.ExportSessionLogButton
    )

    foreach ($button in $standardButtons) {
        $button.Foreground = [System.Windows.Media.Brushes]::White
        $button.Background = $standardButtonBackground
        $button.BorderBrush = $standardButtonBackground
        $button.BorderThickness = '0'
    }

    $ui.HomeRecommendedRepairsButton.Background = $warningButtonBackground
    $ui.HomeRecommendedRepairsButton.BorderBrush = $warningButtonBackground
    $ui.HomeRecommendedRepairsButton.Foreground = [System.Windows.Media.Brushes]::White

    $ui.AboutTitleText.Text = $Branding.AboutTitle
    $ui.AboutVersionText.Text = 'Version: {0}' -f $Branding.Version
    $ui.AboutSupportText.Text = '{0}{1}{1}{2}' -f $Branding.SupportText, [Environment]::NewLine, $Branding.AboutBody
    $ui.AboutWebsiteText.Text = 'Website URL: {0}' -f $Branding.WebsiteUrl
    $ui.AboutBootstrapText.Text = 'Bootstrap URL: {0}' -f $Branding.BootstrapUrl

    $appTable = New-Object System.Data.DataTable
    [void]$appTable.Columns.Add('IsSelected', [bool])
    [void]$appTable.Columns.Add('Id', [string])
    [void]$appTable.Columns.Add('Name', [string])
    [void]$appTable.Columns.Add('Category', [string])
    [void]$appTable.Columns.Add('Provider', [string])
    [void]$appTable.Columns.Add('Description', [string])
    [void]$appTable.Columns.Add('Recommended', [bool])

    $repairTable = New-Object System.Data.DataTable
    [void]$repairTable.Columns.Add('IsSelected', [bool])
    [void]$repairTable.Columns.Add('Id', [string])
    [void]$repairTable.Columns.Add('Name', [string])
    [void]$repairTable.Columns.Add('Group', [string])
    [void]$repairTable.Columns.Add('Description', [string])
    [void]$repairTable.Columns.Add('Command', [string])
    [void]$repairTable.Columns.Add('Recommended', [bool])
    [void]$repairTable.Columns.Add('Reboot', [string])

    $tweakTable = New-Object System.Data.DataTable
    [void]$tweakTable.Columns.Add('IsSelected', [bool])
    [void]$tweakTable.Columns.Add('Id', [string])
    [void]$tweakTable.Columns.Add('Name', [string])
    [void]$tweakTable.Columns.Add('Risk', [string])
    [void]$tweakTable.Columns.Add('Description', [string])
    [void]$tweakTable.Columns.Add('Recommended', [bool])

    $loadData = {
        $appTable.Rows.Clear()
        foreach ($app in $appCatalog) {
            $row = $appTable.NewRow()
            $row.IsSelected = $false
            $row.Id = $app.id
            $row.Name = $app.name
            $row.Category = $app.category
            $row.Provider = $app.provider
            $row.Description = $app.description
            $row.Recommended = [bool]$app.recommended
            [void]$appTable.Rows.Add($row)
        }

        $repairTable.Rows.Clear()
        foreach ($repair in $repairCatalog) {
            $row = $repairTable.NewRow()
            $row.IsSelected = $false
            $row.Id = $repair.id
            $row.Name = $repair.name
            $row.Group = $repair.group
            $row.Description = $repair.description
            $row.Command = $repair.command
            $row.Recommended = [bool]$repair.recommended
            $row.Reboot = $repair.reboot
            [void]$repairTable.Rows.Add($row)
        }

        $tweakTable.Rows.Clear()
        foreach ($tweak in $tweakCatalog) {
            $row = $tweakTable.NewRow()
            $row.IsSelected = $false
            $row.Id = $tweak.id
            $row.Name = $tweak.name
            $row.Risk = $tweak.risk
            $row.Description = $tweak.description
            $row.Recommended = [bool]$tweak.recommended
            [void]$tweakTable.Rows.Add($row)
        }
    }

    & $loadData

    $ui.ApplicationsGrid.ItemsSource = $appTable.DefaultView
    $ui.RepairsGrid.ItemsSource = $repairTable.DefaultView
    $ui.TweaksGrid.ItemsSource = $tweakTable.DefaultView
    $ui.AppSearchBox.Text = ''
    $ui.RepairSearchBox.Text = ''

    $ui.AppCategoryFilter.Items.Add('All Categories') | Out-Null
    foreach ($category in ($appCatalog | Select-Object -ExpandProperty category -Unique | Sort-Object)) {
        $ui.AppCategoryFilter.Items.Add($category) | Out-Null
    }
    $ui.AppCategoryFilter.SelectedIndex = 0

    $ui.AppPresetFilter.Items.Add('No Preset') | Out-Null
    foreach ($preset in $presetCatalog) {
        $ui.AppPresetFilter.Items.Add($preset.name) | Out-Null
    }
    $ui.AppPresetFilter.SelectedIndex = 0

    $ui.RepairGroupFilter.Items.Add('All Groups') | Out-Null
    foreach ($group in @('Safe', 'Advanced', 'Dangerous')) {
        $ui.RepairGroupFilter.Items.Add($group) | Out-Null
    }
    $ui.RepairGroupFilter.SelectedIndex = 0

    $setStatus = {
        param(
            [string]$Message,
            [string]$Level
        )

        $ui.StatusText.Text = $Message
        switch ($Level) {
            'Error' { $ui.StatusText.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FF9191') }
            'Warn' { $ui.StatusText.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Branding.WarningColor) }
            default { $ui.StatusText.Foreground = [System.Windows.Media.Brushes]::White }
        }
    }

    $showPage = {
        param([string]$PageName)

        $pages = @{
            Home = $ui.HomePage
            Applications = $ui.ApplicationsPage
            Repairs = $ui.RepairsPage
            Tweaks = $ui.TweaksPage
            Maintenance = $ui.MaintenancePage
            Logs = $ui.LogsPage
            About = $ui.AboutPage
        }

        foreach ($key in $pages.Keys) {
            $pages[$key].Visibility = if ($key -eq $PageName) { 'Visible' } else { 'Collapsed' }
        }

        foreach ($button in $navButtons) {
            $button.Background = $neutralButtonBackground
        }

        switch ($PageName) {
            'Home' { $ui.NavHome.Background = $standardButtonBackground }
            'Applications' { $ui.NavApplications.Background = $standardButtonBackground }
            'Repairs' { $ui.NavRepairs.Background = $standardButtonBackground }
            'Tweaks' { $ui.NavTweaks.Background = $standardButtonBackground }
            'Maintenance' { $ui.NavMaintenance.Background = $standardButtonBackground }
            'Logs' { $ui.NavLogs.Background = $standardButtonBackground }
            'About' { $ui.NavAbout.Background = $standardButtonBackground }
        }

        $ui.PageTitle.Text = $PageName
        $ui.PageSubtitle.Text = switch ($PageName) {
            'Home' { $Branding.Tagline }
            'Applications' { 'Config-driven app installs, removals, and presets.' }
            'Repairs' { 'Safe, advanced, and dangerous repair actions with command visibility.' }
            'Tweaks' { 'Technician-friendly Windows tweaks with sensible warnings.' }
            'Maintenance' { 'Launch system tools and export maintenance data.' }
            'Logs' { 'Live session log viewer and log exports.' }
            default { 'Internal utility details and bootstrap information.' }
        }

        if ($PageName -eq 'Logs') {
            $ui.LogViewerTextBox.Text = Get-SessionLogContent
            $ui.LogViewerTextBox.ScrollToEnd()
        }
    }

    $updateSummaryTiles = {
        $summary = Get-SystemSummary
        $ui.TileComputerName.Text = $summary.ComputerName
        $ui.TileCurrentUser.Text = $summary.CurrentUser
        $ui.TileWindowsVersion.Text = $summary.WindowsVersion
        $ui.TileUptime.Text = $summary.Uptime
        $ui.TileAdminStatus.Text = $summary.AdminStatus
        $ui.TileWinget.Text = $summary.WingetDetected
        $ui.TileChocolatey.Text = $summary.ChocolateyDetected
    }

    $applyAppFilter = {
        $search = Escape-DataViewValue -Value $ui.AppSearchBox.Text.Trim()
        $category = $ui.AppCategoryFilter.SelectedItem
        $clauses = New-Object System.Collections.Generic.List[string]

        if (-not [string]::IsNullOrWhiteSpace($search)) {
            $clauses.Add("(Name LIKE '%$search%' OR Category LIKE '%$search%' OR Provider LIKE '%$search%' OR Description LIKE '%$search%')")
        }

        if ($category -and $category -ne 'All Categories') {
            $escapedCategory = Escape-DataViewValue -Value $category
            $clauses.Add("Category = '$escapedCategory'")
        }

        $appTable.DefaultView.RowFilter = ($clauses -join ' AND ')
    }

    $applyRepairFilter = {
        $search = Escape-DataViewValue -Value $ui.RepairSearchBox.Text.Trim()
        $group = $ui.RepairGroupFilter.SelectedItem
        $clauses = New-Object System.Collections.Generic.List[string]

        if (-not [string]::IsNullOrWhiteSpace($search)) {
            $clauses.Add("(Name LIKE '%$search%' OR [Group] LIKE '%$search%' OR Description LIKE '%$search%' OR Command LIKE '%$search%')")
        }

        if ($group -and $group -ne 'All Groups') {
            $escapedGroup = Escape-DataViewValue -Value $group
            $clauses.Add("[Group] = '$escapedGroup'")
        }

        $repairTable.DefaultView.RowFilter = ($clauses -join ' AND ')
    }

    $setRecommendedSelections = {
        param([System.Data.DataTable]$Table)

        foreach ($row in $Table.Rows) {
            $row.IsSelected = [bool]$row.Recommended
        }
    }

    $selectPreset = {
        $presetName = [string]$ui.AppPresetFilter.SelectedItem
        foreach ($row in $appTable.Rows) {
            $row.IsSelected = $false
        }

        if ($presetName -and $presetName -ne 'No Preset') {
            $preset = $presetCatalog | Where-Object { $_.name -eq $presetName } | Select-Object -First 1
            if ($preset) {
                foreach ($row in $appTable.Rows) {
                    $row.IsSelected = $preset.apps -contains $row.Id
                }
            }
        }
    }

    $getSelectedById = {
        param(
            [System.Data.DataTable]$Table,
            [object[]]$Catalog
        )

        $selectedIds = @($Table.Rows | Where-Object { $_.IsSelected } | ForEach-Object { $_.Id })
        return @($Catalog | Where-Object { $selectedIds -contains $_.id })
    }

    $confirmDangerousRepairs = {
        param([object[]]$Repairs)

        $dangerous = @($Repairs | Where-Object { $_.group -eq 'Dangerous' })
        if (-not $dangerous) {
            return $true
        }

        foreach ($repair in $dangerous) {
            $message = if ($repair.confirmationText) { $repair.confirmationText } else { 'This repair is marked dangerous. Continue?' }
            $response = [System.Windows.MessageBox]::Show($message, $repair.name, 'YesNo', 'Warning')
            if ($response -ne 'Yes') {
                return $false
            }
        }

        return $true
    }

    $runResultsSummary = {
        param(
            [object[]]$Results,
            [string]$SuccessMessage
        )

        if (-not $Results -or $Results.Count -eq 0) {
            & $setStatus 'No actions were run.' 'Warn'
            return
        }

        $failed = @($Results | Where-Object { -not $_.Success })
        if ($failed.Count -gt 0) {
            & $setStatus ('{0} completed with {1} failure(s).' -f $SuccessMessage, $failed.Count) 'Error'
        }
        else {
            & $setStatus ('{0} completed successfully.' -f $SuccessMessage) 'Info'
        }
    }

    $ui.NavHome.Add_Click({ & $showPage 'Home' })
    $ui.NavApplications.Add_Click({ & $showPage 'Applications' })
    $ui.NavRepairs.Add_Click({ & $showPage 'Repairs' })
    $ui.NavTweaks.Add_Click({ & $showPage 'Tweaks' })
    $ui.NavMaintenance.Add_Click({ & $showPage 'Maintenance' })
    $ui.NavLogs.Add_Click({ & $showPage 'Logs' })
    $ui.NavAbout.Add_Click({ & $showPage 'About' })

    $ui.HomeApplicationsButton.Add_Click({ & $showPage 'Applications' })
    $ui.HomeRepairsButton.Add_Click({ & $showPage 'Repairs' })
    $ui.HomeExportSummaryButton.Add_Click({
        try {
            $path = Export-SystemSummary
            & $setStatus ("System summary exported to $path") 'Info'
        }
        catch {
            & $setStatus $_.Exception.Message 'Error'
        }
    })
    $ui.HomeRecommendedRepairsButton.Add_Click({
        & $setRecommendedSelections $repairTable
        $repairs = & $getSelectedById $repairTable $repairCatalog
        if (-not (& $confirmDangerousRepairs $repairs)) {
            & $setStatus 'Recommended repairs were cancelled.' 'Warn'
            return
        }
        $results = foreach ($repair in $repairs) { Invoke-RepairAction -Repair $repair }
        & $runResultsSummary $results 'Recommended repairs'
        & $showPage 'Logs'
    })

    $ui.AppSearchBox.Add_TextChanged({ & $applyAppFilter })
    $ui.AppCategoryFilter.Add_SelectionChanged({ & $applyAppFilter })
    $ui.ApplyPresetButton.Add_Click({
        & $selectPreset
        & $setStatus ("Preset applied: {0}" -f $ui.AppPresetFilter.SelectedItem) 'Info'
    })
    $ui.SelectRecommendedAppsButton.Add_Click({
        & $setRecommendedSelections $appTable
        & $setStatus 'Recommended applications selected.' 'Info'
    })
    $ui.RefreshAppsButton.Add_Click({
        $appCatalog = Get-ApplicationCatalog
        & $loadData
        & $applyAppFilter
        & $setStatus 'Application list refreshed from config.' 'Info'
    })
    $ui.InstallSelectedAppsButton.Add_Click({
        $apps = & $getSelectedById $appTable $appCatalog
        if (-not $apps) {
            & $setStatus 'Select one or more applications first.' 'Warn'
            return
        }
        $results = foreach ($app in $apps) { Invoke-ApplicationAction -App $app -Operation Install }
        & $runResultsSummary $results 'Application install'
        & $showPage 'Logs'
    })
    $ui.UninstallSelectedAppsButton.Add_Click({
        $apps = & $getSelectedById $appTable $appCatalog
        if (-not $apps) {
            & $setStatus 'Select one or more applications first.' 'Warn'
            return
        }
        $results = foreach ($app in $apps) { Invoke-ApplicationAction -App $app -Operation Uninstall }
        & $runResultsSummary $results 'Application uninstall'
        & $showPage 'Logs'
    })

    $ui.RepairSearchBox.Add_TextChanged({ & $applyRepairFilter })
    $ui.RepairGroupFilter.Add_SelectionChanged({ & $applyRepairFilter })
    $ui.SelectRecommendedRepairsButton.Add_Click({
        & $setRecommendedSelections $repairTable
        & $setStatus 'Recommended repairs selected.' 'Info'
    })
    $ui.PreviewRepairsButton.Add_Click({
        $repairs = & $getSelectedById $repairTable $repairCatalog
        if (-not $repairs) {
            & $setStatus 'Select one or more repairs first.' 'Warn'
            return
        }
        $preview = (($repairs | ForEach-Object { '{0} -> {1}' -f $_.name, $_.command }) -join [Environment]::NewLine)
        [System.Windows.MessageBox]::Show($preview, 'Selected Repair Commands', 'OK', 'Information') | Out-Null
        & $setStatus 'Repair command preview displayed.' 'Info'
    })
    $ui.RunRepairsButton.Add_Click({
        $repairs = & $getSelectedById $repairTable $repairCatalog
        if (-not $repairs) {
            & $setStatus 'Select one or more repairs first.' 'Warn'
            return
        }
        if (-not (& $confirmDangerousRepairs $repairs)) {
            & $setStatus 'Repair execution cancelled.' 'Warn'
            return
        }
        $results = foreach ($repair in $repairs) { Invoke-RepairAction -Repair $repair }
        & $runResultsSummary $results 'Repair actions'
        & $showPage 'Logs'
    })

    $ui.SelectRecommendedTweaksButton.Add_Click({
        & $setRecommendedSelections $tweakTable
        & $setStatus 'Recommended tweaks selected.' 'Info'
    })
    $ui.ClearTweakSelectionButton.Add_Click({
        foreach ($row in $tweakTable.Rows) { $row.IsSelected = $false }
        & $setStatus 'Tweak selection cleared.' 'Info'
    })
    $ui.ApplyTweaksButton.Add_Click({
        $tweaks = & $getSelectedById $tweakTable $tweakCatalog
        if (-not $tweaks) {
            & $setStatus 'Select one or more tweaks first.' 'Warn'
            return
        }
        $elevatedTweaks = @($tweaks | Where-Object { $_.risk -ne 'Safe' })
        if ($elevatedTweaks.Count -gt 0) {
            $response = [System.Windows.MessageBox]::Show('One or more selected tweaks are elevated. Continue?', 'Confirm Tweaks', 'YesNo', 'Warning')
            if ($response -ne 'Yes') {
                & $setStatus 'Tweak execution cancelled.' 'Warn'
                return
            }
        }
        $results = foreach ($tweak in $tweaks) { Invoke-TweakAction -Tweak $tweak }
        & $runResultsSummary $results 'Tweaks'
        & $showPage 'Logs'
    })

    foreach ($actionItem in $maintenanceCatalog) {
        $localActionItem = $actionItem
        $button = New-Object System.Windows.Controls.Button
        $button.Content = $localActionItem.name
        $button.Width = 180
        $button.Height = 46
        $button.Margin = '0,0,12,12'
        $button.Foreground = [System.Windows.Media.Brushes]::White
        $button.Background = $neutralButtonBackground
        $button.BorderBrush = $neutralButtonBackground
        $button.ToolTip = $localActionItem.description
        $button.Add_Click({
            $result = Invoke-MaintenanceAction -ActionItem $localActionItem
            if ($result.Success) {
                & $setStatus $result.Message 'Info'
            }
            else {
                & $setStatus $result.ErrorSummary 'Error'
            }
        }.GetNewClosure())
        [void]$ui.MaintenanceButtonsPanel.Children.Add($button)
    }

    $ui.UpgradePackagesButton.Add_Click({
        $results = Invoke-UpgradeSupportedPackages
        & $runResultsSummary $results 'Package upgrades'
        & $showPage 'Logs'
    })
    $ui.ExportInstalledAppsButton.Add_Click({
        try {
            $path = Export-InstalledApplications
            & $setStatus ("Installed applications exported to $path") 'Info'
        }
        catch {
            & $setStatus $_.Exception.Message 'Error'
        }
    })
    $ui.MaintenanceExportSummaryButton.Add_Click({
        try {
            $path = Export-SystemSummary
            & $setStatus ("System summary exported to $path") 'Info'
        }
        catch {
            & $setStatus $_.Exception.Message 'Error'
        }
    })
    $ui.OpenLogsFolderButton.Add_Click({
        $result = Open-LogsFolder
        & $setStatus $result.Message 'Info'
    })

    $ui.RefreshLogsButton.Add_Click({
        $ui.LogViewerTextBox.Text = Get-SessionLogContent
        $ui.LogViewerTextBox.ScrollToEnd()
        & $setStatus 'Logs refreshed.' 'Info'
    })
    $ui.LogsOpenFolderButton.Add_Click({
        $result = Open-LogsFolder
        & $setStatus $result.Message 'Info'
    })
    $ui.ExportSessionLogButton.Add_Click({
        try {
            $path = Export-CurrentSessionLog
            & $setStatus ("Current session log exported to $path") 'Info'
        }
        catch {
            & $setStatus $_.Exception.Message 'Error'
        }
    })

    $logTimer = New-Object System.Windows.Threading.DispatcherTimer
    $logTimer.Interval = [TimeSpan]::FromSeconds(3)
    $logTimer.Add_Tick({
        if ($ui.LogsPage.Visibility -eq 'Visible') {
            $ui.LogViewerTextBox.Text = Get-SessionLogContent
            $ui.LogViewerTextBox.ScrollToEnd()
        }
    })
    $logTimer.Start()

    & $updateSummaryTiles
    & $applyAppFilter
    & $applyRepairFilter
    & $showPage 'Home'
    Write-Log -Message 'Displaying Key Methods Workbench shell.' -Action 'ShowShell'

    if ($AutoClose) {
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(2)
        $timer.Add_Tick({
            $timer.Stop()
            $window.Close()
        })
        $timer.Start()
    }

    [void]$window.ShowDialog()
}

Export-ModuleMember -Function Show-WorkbenchShell
