# ============================================================================
# Key Methods Workbench - UI Module
# ============================================================================
# UI helper functions and controls

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

#region Dialog Functions

function Show-KMMessageBox {
    <#
    .SYNOPSIS
        Displays a message box.
    
    .PARAMETER Message
        Message text.
    
    .PARAMETER Title
        Dialog title.
    
    .PARAMETER Buttons
        Button configuration: OK, OKCancel, YesNo, YesNoCancel.
    
    .PARAMETER Icon
        Icon type: None, Error, Warning, Information, Question.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [string]$Title = "Key Methods Workbench",
        
        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel")]
        [string]$Buttons = "OK",
        
        [ValidateSet("None", "Error", "Warning", "Information", "Question")]
        [string]$Icon = "Information"
    )
    
    $buttonEnum = [System.Windows.MessageBoxButton]::$Buttons
    $iconEnum = [System.Windows.MessageBoxImage]::$Icon
    
    return [System.Windows.MessageBox]::Show($Message, $Title, $buttonEnum, $iconEnum)
}

function Show-KMInputBox {
    <#
    .SYNOPSIS
        Displays an input dialog.
    
    .PARAMETER Message
        Prompt message.
    
    .PARAMETER Title
        Dialog title.
    
    .PARAMETER DefaultValue
        Default input value.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [string]$Title = "Key Methods Workbench",
        
        [string]$DefaultValue = ""
    )
    
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($Message, $Title, $DefaultValue)
}

function Show-KMProgressDialog {
    <#
    .SYNOPSIS
        Shows a progress dialog for long operations.
    
    .PARAMETER Activity
        Current activity description.
    
    .PARAMETER Status
        Current status text.
    
    .PARAMETER PercentComplete
        Percentage complete (0-100).
    
    .PARAMETER Cancelable
        Whether to show cancel button.
    #>
    param(
        [string]$Activity = "Working...",
        [string]$Status = "",
        [int]$PercentComplete = 0,
        [switch]$Cancelable
    )
    
    # Use Write-Progress for console, could be extended for GUI
    $progressParams = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
    }
    
    Write-Progress @progressParams
}

function Show-KMBalloonTip {
    <#
    .SYNOPSIS
        Displays a balloon tip notification.
    
    .PARAMETER Title
        Notification title.
    
    .PARAMETER Text
        Notification text.
    
    .PARAMETER Icon
        Icon type: None, Info, Warning, Error.
    
    .PARAMETER Timeout
        Timeout in milliseconds.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$Text,
        
        [ValidateSet("None", "Info", "Warning", "Error")]
        [string]$Icon = "Info",
        
        [int]$Timeout = 5000
    )
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipIcon = $Icon
        $balloon.BalloonTipTitle = $Title
        $balloon.BalloonTipText = $Text
        $balloon.Visible = $true
        
        $balloon.ShowBalloonTip($Timeout)
        
        # Dispose after showing
        Start-Sleep -Milliseconds ($Timeout + 500)
        $balloon.Dispose()
    }
    catch {
        Write-KMLog -Message "Failed to show balloon tip: $_" -Level "Warning"
    }
}

#endregion

#region File Dialog Functions

function Show-KMOpenFileDialog {
    <#
    .SYNOPSIS
        Shows an open file dialog.
    
    .PARAMETER Title
        Dialog title.
    
    .PARAMETER Filter
        File filter (e.g., "Text files (*.txt)|*.txt|All files (*.*)|*.*").
    
    .PARAMETER InitialDirectory
        Initial directory.
    #>
    param(
        [string]$Title = "Open File",
        [string]$Filter = "All files (*.*)|*.*",
        [string]$InitialDirectory = [Environment]::GetFolderPath("Desktop")
    )
    
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.InitialDirectory = $InitialDirectory
    
    if ($dialog.ShowDialog() -eq $true) {
        return $dialog.FileName
    }
    
    return $null
}

function Show-KMSaveFileDialog {
    <#
    .SYNOPSIS
        Shows a save file dialog.
    
    .PARAMETER Title
        Dialog title.
    
    .PARAMETER Filter
        File filter.
    
    .PARAMETER InitialDirectory
        Initial directory.
    
    .PARAMETER FileName
        Default file name.
    #>
    param(
        [string]$Title = "Save File",
        [string]$Filter = "All files (*.*)|*.*",
        [string]$InitialDirectory = [Environment]::GetFolderPath("Desktop"),
        [string]$FileName = ""
    )
    
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.InitialDirectory = $InitialDirectory
    $dialog.FileName = $FileName
    
    if ($dialog.ShowDialog() -eq $true) {
        return $dialog.FileName
    }
    
    return $null
}

function Show-KMFolderBrowserDialog {
    <#
    .SYNOPSIS
        Shows a folder browser dialog.
    
    .PARAMETER Description
        Dialog description.
    
    .PARAMETER RootFolder
        Root folder special folder.
    
    .PARAMETER ShowNewFolderButton
        Show new folder button.
    #>
    param(
        [string]$Description = "Select Folder",
        [System.Environment+SpecialFolder]$RootFolder = [System.Environment+SpecialFolder]::Desktop,
        [switch]$ShowNewFolderButton
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.RootFolder = $RootFolder
    $dialog.ShowNewFolderButton = $ShowNewFolderButton
    
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    
    return $null
}

#endregion

#region Custom Controls

function New-KMButton {
    <#
    .SYNOPSIS
        Creates a styled button for the Workbench UI.
    
    .PARAMETER Content
        Button content.
    
    .PARAMETER OnClick
        Click scriptblock.
    
    .PARAMETER Style
        Button style: Primary, Secondary, Warning, Danger.
    #>
    param(
        [string]$Content,
        [scriptblock]$OnClick,
        [ValidateSet("Primary", "Secondary", "Warning", "Danger")]
        [string]$Style = "Primary"
    )
    
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Content
    $button.Margin = "5"
    
    # Set colors based on style
    switch ($Style) {
        "Primary" { $button.Background = "#0072C6"; $button.Foreground = "White" }
        "Secondary" { $button.Background = "#6C757D"; $button.Foreground = "White" }
        "Warning" { $button.Background = "#F26522"; $button.Foreground = "White" }
        "Danger" { $button.Background = "#DC3545"; $button.Foreground = "White" }
    }
    
    if ($OnClick) {
        $button.Add_Click($OnClick)
    }
    
    return $button
}

function New-KMDataGrid {
    <#
    .SYNOPSIS
        Creates a data grid with standard styling.
    
    .PARAMETER ItemsSource
        Data source.
    
    .PARAMETER Columns
        Column definitions.
    #>
    param(
        [object]$ItemsSource,
        [array]$Columns = @()
    )
    
    $grid = New-Object System.Windows.Controls.DataGrid
    $grid.ItemsSource = $ItemsSource
    $grid.AutoGenerateColumns = ($Columns.Count -eq 0)
    $grid.Background = "#2D2D2D"
    $grid.Foreground = "White"
    $grid.BorderBrush = "#3D3D3D"
    $grid.RowBackground = "#2D2D2D"
    $grid.AlternatingRowBackground = "#252525"
    $grid.HeadersVisibility = "Column"
    $grid.GridLinesVisibility = "Horizontal"
    $grid.HorizontalGridLinesBrush = "#3D3D3D"
    
    return $grid
}

#endregion

#region Theme Functions

function Get-KMThemeColors {
    <#
    .SYNOPSIS
        Returns the standard theme colors.
    #>
    return @{
        Background = "#1E1E1E"
        BackgroundDark = "#151515"
        BackgroundLight = "#2D2D2D"
        Primary = "#0072C6"
        Secondary = "#F26522"
        Success = "#28A745"
        Warning = "#FFC107"
        Danger = "#DC3545"
        TextPrimary = "#FFFFFF"
        TextSecondary = "#AAAAAA"
    }
}

function Set-KMWindowIcon {
    <#
    .SYNOPSIS
        Sets the window icon from a resource or file.
    
    .PARAMETER Window
        Window object.
    
    .PARAMETER IconPath
        Path to icon file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window,
        
        [string]$IconPath = $null
    )
    
    try {
        if ($IconPath -and (Test-Path $IconPath)) {
            $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create([System.Uri]::new($IconPath))
        }
    }
    catch {
        Write-KMLog -Message "Failed to set window icon: $_" -Level "Warning"
    }
}

#endregion

#region Export Module Members

Export-ModuleMember -Function @(
    'Show-KMMessageBox',
    'Show-KMInputBox',
    'Show-KMProgressDialog',
    'Show-KMBalloonTip',
    'Show-KMOpenFileDialog',
    'Show-KMSaveFileDialog',
    'Show-KMFolderBrowserDialog',
    'New-KMButton',
    'New-KMDataGrid',
    'Get-KMThemeColors',
    'Set-KMWindowIcon'
)

#endregion
