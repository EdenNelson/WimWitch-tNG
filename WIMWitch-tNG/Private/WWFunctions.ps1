#region Functions
<#
.SYNOPSIS
    Displays all WPF form variables and reference instructions.

.DESCRIPTION
    Retrieves and displays all global variables prefixed with 'WPF' that are created from the XAML form definition.
    Shows a one-time informational message directing users to this function if they need to review the form variables again.
    This is useful for debugging and understanding the available form controls.

.EXAMPLE
    Get-FormVariables
    Lists all available WPF control variables from the form.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is typically called after loading the XAML form to understand available controls.

.OUTPUTS
    System.Management.Automation.PSVariable
    Returns all variables matching the WPF* pattern.
#>
Function Get-FormVariables {
    if ($global:ReadmeDisplay -ne $true) { Write-Host 'If you need to reference this display again, run Get-FormVariables' -ForegroundColor Yellow; $global:ReadmeDisplay = $true }
    #write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    Get-Variable WPF*
}

#===========================================================================
# Functions for Controls
#===========================================================================
<#
.SYNOPSIS
    Verifies that the script is running with administrative privileges.

.DESCRIPTION
    Validates that the current PowerShell session has administrator rights by checking
    the Windows principal role. If the user does not have administrator privileges,
    logs an error message and terminates the script execution immediately.
    This function is essential for operations that require elevated permissions.

.EXAMPLE
    Test-Admin
    Checks if current session has admin rights; exits if not.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function should be called early in script initialization to prevent
    partial execution with insufficient permissions.

.OUTPUTS
    None. Exits script if admin rights are not detected.
#>
Function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    if ($currentUser.IsInRole($adminRole)) {
        Update-Log -Data 'User has admin privileges' -Class Information
    } else {
        Update-Log -Data 'This script requires administrative privileges. Please run it as an administrator.' -Class Error
        Exit
    }
}

<#
.SYNOPSIS
    Converts legacy ConfigManager XML configuration files to PowerShell Data (PSD1) format.

.DESCRIPTION
    Scans the configs folder for legacy XML configuration files created by ConfigManager and converts them to modern
    PSD1 (PowerShell Data File) format. This function handles proper serialization of hashtables, arrays, booleans,
    integers, and string values. Optionally removes the legacy XML files after successful conversion.
    This migration ensures compatibility with current configuration import mechanisms.

.PARAMETER RemoveLegacy
    A switch parameter that, when specified, removes the original XML files after successful conversion to PSD1 format.
    If not specified, the legacy XML files are preserved.

.EXAMPLE
    Convert-ConfigMgrXmlToPsd1
    Converts all XML files in the configs folder to PSD1 format, preserving the original XML files.

.EXAMPLE
    Convert-ConfigMgrXmlToPsd1 -RemoveLegacy
    Converts all XML files in the configs folder to PSD1 format and removes the original XML files.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is typically called during application initialization to ensure all configuration files
    are in the current PSD1 format. The conversion maintains all data types and formatting.

.OUTPUTS
    None. Updates are logged via Update-Log function with Information and Error classifications.
    Creates new PSD1 files and optionally removes legacy XML files.
#>
Function Convert-ConfigMgrXmlToPsd1 {
    [CmdletBinding()]
    param(
        [switch]$RemoveLegacy
    )

    # Check if ConfigMgr configs folder exists
    $ConfigPath = "$global:workdir\configs"
    if (-not (Test-Path -Path $ConfigPath)) {
        Update-Log -Data 'ConfigMgr configs folder not found, skipping XML to PSD1 conversion' -Class Information
        return
    }

    # Look for any legacy XML files in the configs folder
    $LegacyXmlFiles = @(Get-ChildItem -Path $ConfigPath -Filter '*.xml' -ErrorAction SilentlyContinue)

    if ($LegacyXmlFiles.Count -gt 0) {
        Update-Log -Data "Found $($LegacyXmlFiles.Count) legacy ConfigMgr XML file(s) to convert" -Class Information

        foreach ($XmlFile in $LegacyXmlFiles) {
            try {
                # Import the CLIXML file (deserialize to hashtable)
                $ConfigData = Import-Clixml -Path $XmlFile.FullName -ErrorAction Stop

                # Convert hashtable to PSD1 format
                $PSD1FileName = [System.IO.Path]::ChangeExtension($XmlFile.FullName, '.psd1')

                # Build PSD1 content with proper formatting
                $PSD1Lines = @("@{")
                $PSD1Lines += "    # Converted from legacy XML: $($XmlFile.Name)"

                foreach ($key in $ConfigData.Keys | Sort-Object) {
                    $value = $ConfigData[$key]
                    $formattedValue = if ($null -eq $value) {
                        '$null'
                    } elseif ($value -is [bool]) {
                        if ($value) { '$true' } else { '$false' }
                    } elseif ($value -is [int]) {
                        $value
                    } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                        # Handle arrays and collections (including ItemCollection)
                        $items = @($value | ForEach-Object {
                            if ($_ -is [string]) {
                                "'$($_ -replace "'", "''")'"
                            } else {
                                "'$($_.ToString() -replace "'", "''")'"
                            }
                        })
                        if ($items.Count -eq 0) {
                            '@()'
                        } else {
                            "@($($items -join ', '))"
                        }
                    } else {
                        # Handle strings and other simple types
                        "'$($value.ToString() -replace "'", "''")'"
                    }
                    $PSD1Lines += "    $key = $formattedValue"
                }

                $PSD1Lines += "}"
                $PSD1Content = $PSD1Lines -join "`r`n"

                Set-Content -Path $PSD1FileName -Value $PSD1Content -ErrorAction Stop
                Update-Log -Data "Converted $($XmlFile.Name) to PSD1 format" -Class Information

                if ($RemoveLegacy) {
                    Remove-Item -Path $XmlFile.FullName -Force -ErrorAction Stop
                    Update-Log -Data "Removed legacy XML file: $($XmlFile.Name)" -Class Information
                }
            }
            catch {
                Update-Log -Data "Error converting $($XmlFile.Name): $($_.Exception.Message)" -Class Warning
            }
        }
    } else {
        Update-Log -Data 'No legacy ConfigMgr XML files found, skipping conversion' -Class Information
    }
}

<#
.SYNOPSIS
    Prompts user to select a mount directory and validates WIM selection.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a directory for mounting Windows images.
    Validates that a valid WIM file has been previously selected, then prompts the user to choose
    an image index from the selected WIM file using an Out-GridView selection dialog.
    Finally imports the selected image information into the form.

.EXAMPLE
    Select-MountDir
    Opens folder browser dialog and guides through image index selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Prerequisites: A valid WIM file must be selected before calling this function.
    Requires: $WPFSourceWIMSelectWIMTextBox, $SourceWIM global variables

.OUTPUTS
    None. Updates form variables via Import-WimInfo
#>
<#
.SYNOPSIS
    Prompts user to select a mount directory for WIM file operations.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a directory where a WIM file
    will be mounted for modification. Validates that a WIM file has been previously selected.
    After directory selection, prompts the user to choose an image index from the currently
    selected WIM file and imports the image information.

.PARAMETER
    This function does not accept parameters. It uses global variables:
    - $WPFSourceWIMSelectWIMTextBox: Contains the path to the selected WIM file
    - $SourceWIM: Global variable containing the selected WIM file information

.EXAMPLE
    Select-MountDir
    Opens folder browser dialog and prompts for WIM image index selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function integrates with WPF form controls and expects $WPFSourceWIMSelectWIMTextBox
    to contain a valid WIM file path. Requires Windows Forms assembly.
    Updates global variable $MountDir with the selected directory path.

.OUTPUTS
    None. Updates form variables and calls Import-WimInfo to process the selected index.
#>
Function Select-MountDir {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the mount folder'
    $null = $browser.ShowDialog()
    $MountDir = $browser.SelectedPath

    if ($SourceWIM.FileName -notlike '*.wim') {
        Update-Log -Data 'A WIM file not selected. Please select a valid file to continue.' -Class Warning
        return
    }

    #Select the index
    $ImageFull = @(Get-WindowsImage -ImagePath $WPFSourceWIMSelectWIMTextBox.text)
    $a = $ImageFull | Out-GridView -Title 'Choose an Image Index' -PassThru
    $IndexNumber = $a.ImageIndex
    if ($null -eq $indexnumber) {
        Update-Log -Data 'Index not selected. Reselect the WIM file to select an index' -Class Warning
        return
    }

    Import-WimInfo -IndexNumber $IndexNumber
}

<#
.SYNOPSIS
    Prompts user to select a source WIM file and image index.

.DESCRIPTION
    Opens a file dialog to allow the user to select a WIM (Windows Imaging Format) file.
    Ensures the Imports\WIM directory exists before opening the dialog.
    After file selection, prompts the user to choose an image index from the WIM file.
    Stores the selection globally and populates the form with image information.
    Validates that the selected file is a valid WIM and that the user successfully
    selects an image index before returning.

.PARAMETER
    This function does not accept parameters. It updates global variables and WPF form controls.

.EXAMPLE
    Select-SourceWIM
    Opens file dialog to select WIM file and image index.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    The selected WIM path is stored in $global:SourceWIM for access by other functions.
    Updates: $WPFSourceWIMSelectWIMTextBox, $global:SourceWIM
    Requires Windows Forms assembly and working directory structure.

.OUTPUTS
    None. Updates form variables and global state. Calls Import-WimInfo with selected index.
#>
Function Select-SourceWIM {
    Add-Type -AssemblyName System.Windows.Forms

    # Ensure Imports\WIM directory exists
    $initialDir = "$global:workdir\Imports\WIM"
    if (-not (Test-Path $initialDir)) {
        New-Item -Path $initialDir -ItemType Directory -Force | Out-Null
    }

    $dialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = $initialDir
        Filter           = 'WIM (*.wim)|*.wim|All Files (*.*)|*.*'
    }
    $null = $dialog.ShowDialog()

    # Persist selection for other functions that reference $SourceWIM
    $global:SourceWIM = $dialog

    # Update UI textbox with chosen path
    $WPFSourceWIMSelectWIMTextBox.Text = $dialog.FileName

    if ($dialog.FileName -notlike '*.wim') {
        Update-Log -Data 'A WIM file not selected. Please select a valid file to continue.' -Class Warning
        return
    }

    # Let user choose image index from the selected WIM
    try {
        $images = @(Get-WindowsImage -ImagePath $dialog.FileName)
    } catch {
        Update-Log -Data "Failed to read WIM images: $($_.Exception.Message)" -Class Error
        return
    }

    $selection = $images | Out-GridView -Title 'Choose an Image Index' -PassThru
    if ($null -eq $selection) {
        Update-Log -Data 'Index not selected. Reselect the WIM file to select an index' -Class Warning
        return
    }

    Import-WimInfo -IndexNumber $selection.ImageIndex
}

<#
.SYNOPSIS
    Imports Windows image metadata from a WIM file and populates form fields.

.DESCRIPTION
    Retrieves detailed metadata from a specified image index within a WIM file using
    Get-WindowsImage. Populates multiple form text boxes with image information including
    edition name, version, service pack build, language, index number, and architecture.
    Automatically adjusts form control states based on the image type (Windows Server disables
    certain features like Autopilot and App packages). Handles errors gracefully if the WIM
    file is corrupted or inaccessible.

.PARAMETER IndexNumber
    Specifies the image index within the WIM file to retrieve information from.
    Type: [int]
    Required: $true
    Position: 0

.PARAMETER SkipUserConfirmation
    When specified, skips retrieving Windows version number confirmation.
    Type: [switch]
    Required: $false
    Default: $false

.EXAMPLE
    Import-WimInfo -IndexNumber 1
    Imports image information from index 1 and updates form fields.

.EXAMPLE
    Import-WimInfo -IndexNumber 2 -SkipUserConfirmation
    Imports image information without retrieving version number confirmation.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function interacts with multiple WPF form controls and expects the following
    global variables to exist: $WPFSourceWIMSelectWIMTextBox, $SourceWIM, and various
    WPFSourceWim* and WPFMIS* textboxes.
    Disables Autopilot and App tabs for Windows Server editions.
    Updates global variable $ImageIndex.

.OUTPUTS
    None. Updates WPF form controls with retrieved image metadata.
#>
Function Import-WimInfo($IndexNumber, [switch]$SkipUserConfirmation) {
    Update-Log -Data 'Importing Source WIM Info' -Class Information
    try {
        #Gets WIM metadata to populate fields on the Source tab.
        $ImageInfo = Get-WindowsImage -ImagePath $WPFSourceWIMSelectWIMTextBox.text -Index $IndexNumber -ErrorAction Stop
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data 'The WIM file selected may be borked. Try a different one' -Class Warning
        return
    }
    $text = 'WIM file selected: ' + $SourceWIM.FileName
    # $text = "WIM file selected: " + $ImageInfo.FileName
    Update-Log -data $text -Class Information
    $text = 'Edition selected: ' + $ImageInfo.ImageName

    Update-Log -data $text -Class Information
    $ImageIndex = $IndexNumber

    $WPFSourceWIMImgDesTextBox.text = $ImageInfo.ImageName
    $WPFSourceWimVerTextBox.Text = $ImageInfo.Version
    $WPFSourceWimSPBuildTextBox.text = $ImageInfo.SPBuild
    $WPFSourceWimLangTextBox.text = $ImageInfo.Languages
    $WPFSourceWimIndexTextBox.text = $ImageIndex
    if ($ImageInfo.Architecture -eq 9) {
        $WPFSourceWimArchTextBox.text = 'x64'
    } Else {
        $WPFSourceWimArchTextBox.text = 'x86'
    }
    if ($WPFSourceWIMImgDesTextBox.text -like 'Windows Server*') {
        $WPFJSONEnableCheckBox.IsChecked = $False
        $WPFAppxCheckBox.IsChecked = $False
        $WPFAppTab.IsEnabled = $False
        $WPFAutopilotTab.IsEnabled = $False
        $WPFMISAppxTextBox.text = 'False'
        $WPFMISJSONTextBox.text = 'False'
        $WPFMISOneDriveCheckBox.IsChecked = $False
        $WPFMISOneDriveCheckBox.IsEnabled = $False
    } Else {
        $WPFAppTab.IsEnabled = $True
        $WPFAutopilotTab.IsEnabled = $True
        $WPFMISOneDriveCheckBox.IsEnabled = $True
    }

    ######right here
    if ($SkipUserConfirmation -eq $False) { $WPFSourceWimTBVersionNum.text = Get-WinVersionNumber }
}

<#
.SYNOPSIS
    Prompts user to select a JSON file and parses Autopilot configuration from it.

.DESCRIPTION
    Opens a file dialog to allow the user to select a JSON file containing Autopilot profile data.
    Updates the form textbox with the selected file path and automatically invokes JSON parsing
    to extract Autopilot-specific information such as ZtdCorrelationId and CloudAssignedTenantDomain.

.EXAMPLE
    Select-JSONFile
    Opens file dialog and parses selected JSON file for Autopilot data.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: $WPFJSONTextBox global variable
    Automatically calls Invoke-ParseJSON after file selection.

.OUTPUTS
    None. Updates form variables with JSON data.
#>
Function Select-JSONFile {
    $JSON = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'JSON (*.JSON)|'
    }
    $null = $JSON.ShowDialog()
    $WPFJSONTextBox.Text = $JSON.FileName

    $text = 'JSON file selected: ' + $JSON.FileName
    Update-Log -Data $text -Class Information
    Invoke-ParseJSON -file $JSON.FileName
}

<#
.SYNOPSIS
    Parses an Autopilot configuration JSON file and extracts relevant profile information into form fields.

.DESCRIPTION
    Reads and parses a JSON file containing Autopilot configuration data (typically created by Get-WWAutopilotProfile).
    Extracts key Autopilot profile properties including ZtdCorrelationId, CloudAssignedTenantDomain, and Comment_File,
    and populates the corresponding WPF form textbox controls with these values. If the JSON file is invalid or
    cannot be parsed, updates the form fields with error messages to inform the user.

.PARAMETER file
    The file system path to the JSON file containing Autopilot configuration data.
    Expected format: JSON file with properties for ZtdCorrelationId, CloudAssignedTenantDomain, and Comment_File.

.EXAMPLE
    Invoke-ParseJSON -file 'C:\Autopilot\AutopilotConfigurationFile.json'
    Parses the JSON file and populates form fields with Autopilot profile information.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function updates global WPF form variables:
    - $WPFZtdCorrelationId
    - $WPFCloudAssignedTenantDomain
    - $WPFComment_File

    If parsing fails, error messages are displayed in the form fields and an error is logged.
    The function returns early on parse failure without raising an exception.

.OUTPUTS
    None. Updates WPF form textbox controls with parsed JSON values or error messages.
#>
Function Invoke-ParseJSON($file) {
    try {
        Update-Log -Data 'Attempting to parse JSON file...' -Class Information
        $autopilotinfo = Get-Content $WPFJSONTextBox.Text | ConvertFrom-Json
        Update-Log -Data 'Successfully parsed JSON file' -Class Information
        $WPFZtdCorrelationId.Text = $autopilotinfo.ZtdCorrelationId
        $WPFCloudAssignedTenantDomain.Text = $autopilotinfo.CloudAssignedTenantDomain
        $WPFComment_File.text = $autopilotinfo.Comment_File

    } catch {
        $WPFZtdCorrelationId.Text = 'Bad file. Try Again.'
        $WPFCloudAssignedTenantDomain.Text = 'Bad file. Try Again.'
        $WPFComment_File.text = 'Bad file. Try Again.'
        Update-Log -Data 'Failed to parse JSON file. Try another'
        return
    }
}

<#
.SYNOPSIS
    Prompts user to select a driver source folder.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a directory containing driver files.
    Updates the specified form textbox with the selected folder path and logs the selection.

.PARAMETER DriverTextBoxNumber
    The WPF textbox control to update with the selected driver folder path.
    Expected to be one of the driver textbox variables from the form.

.EXAMPLE
    Select-DriverSource -DriverTextBoxNumber $WPFDriverDir1TextBox
    Opens folder dialog and updates Driver textbox with selected path.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is called multiple times for different driver source fields (typically 1-5).

.OUTPUTS
    None. Updates specified textbox control.
#>
<#
.SYNOPSIS
    Prompts the user to select a driver source folder and populates the specified textbox.

.DESCRIPTION
    Opens a Windows Forms folder browser dialog allowing the user to browse and select a folder
    containing driver files. The selected path is updated in the provided textbox control and
    logged for audit purposes. This function is used to configure the driver source location
    for driver injection operations.

.PARAMETER DriverTextBoxNumber
    A WPF TextBox control object that will be populated with the selected driver folder path.
    This parameter accepts pipeline input and is typically a form textbox element from the main UI.

.EXAMPLE
    Select-DriverSource -DriverTextBoxNumber $WPFDriverSourceTextBox
    Opens folder browser dialog and updates the specified textbox with the selected driver path.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires System.Windows.Forms assembly for file dialog functionality.
    The selection is logged with Information classification.

.OUTPUTS
    None. Updates the provided TextBox control with the selected folder path.
#>
Function Select-DriverSource($DriverTextBoxNumber) {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the Driver Source folder'
    $null = $browser.ShowDialog()
    $DriverDir = $browser.SelectedPath
    $DriverTextBoxNumber.Text = $DriverDir
    Update-Log -Data "Driver path selected: $DriverDir" -Class Information
}


<#
.SYNOPSIS
    Prompts user to select the target output directory for WIM files.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a target directory where
    modified WIM files will be saved. Updates the form textbox and logs the selection.

.EXAMPLE
    Select-TargetDir
    Opens folder dialog and updates target directory field.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFMISWimFolderTextBox
    The selected path becomes the output destination for WIM processing.

.OUTPUTS
    None. Updates form variable.
#>
Function Select-TargetDir {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the target folder'
    $null = $browser.ShowDialog()
    $TargetDir = $browser.SelectedPath
    $WPFMISWimFolderTextBox.text = $TargetDir #I SCREWED UP THIS VARIABLE
    Update-Log -Data 'Target directory selected' -Class Information
}

#Function to enable logging and folder check
<#
.SYNOPSIS
    Logs messages to both a file and console with color-coded severity levels.

.DESCRIPTION
    Records messages to a log file and displays them in the console with color-coded output based on severity class.
    Supports four classification levels: Information (gray), Warning (yellow), Error (red), and Comment (green).
    Messages are timestamped and include the severity class. The log file path is determined by the global $Log variable.
    If no log file path is configured, messages are displayed in console only.

.PARAMETER Data
    The log message content to record. This is a mandatory parameter that accepts pipeline input.
    Supports any string content describing the event or status being logged.

.PARAMETER Solution
    Optional supplementary information or suggested resolution related to the log message.
    This parameter accepts pipeline input and is useful for error or warning messages.

.PARAMETER Class
    The severity classification of the message. Valid values are:
    - Information: General informational messages (default)
    - Warning: Warning-level messages indicating potential issues
    - Error: Error-level messages indicating failures
    - Comment: Commentary or status messages
    Defaults to 'Information' if not specified.

.EXAMPLE
    Update-Log -Data 'User has admin privileges' -Class Information
    Logs an information message about administrative privileges.

.EXAMPLE
    'Configuration loaded successfully' | Update-Log -Class Comment
    Pipes a message to the function and logs it as a comment with green console output.

.EXAMPLE
    Update-Log -Data 'Failed to mount image' -Class Error -Solution 'Verify image path and permissions'
    Logs an error message with an optional solution suggestion.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    The log file path is determined by the global $Log variable. If not set, only console output is produced.
    All messages are prefixed with the current date and time.

.OUTPUTS
    None. Output is written to console and optionally to the log file.
#>
Function Update-Log {
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Data,

        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Solution = $Solution,

        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [validateset('Information', 'Warning', 'Error', 'Comment')]
        [string]$Class = 'Information'

    )

    $global:ScriptLogFilePath = $Log
    $LogString = "$(Get-Date) $Class  -  $Data"
    $HostString = "$(Get-Date) $Class  -  $Data"


    # Only write to log file if $Log path is set
    if ($Log) {
        Add-Content -Path $Log -Value $LogString
    }

    switch ($Class) {
        'Information' {
            Write-Host $HostString -ForegroundColor Gray
        }
        'Warning' {
            Write-Host $HostString -ForegroundColor Yellow
        }
        'Error' {
            Write-Host $HostString -ForegroundColor Red
        }
        'Comment' {
            Write-Host $HostString -ForegroundColor Green
        }

        Default { }
    }
    #The below line is for a logging tab that was removed. If it gets put back in, reenable the line
    #  $WPFLoggingTextBox.text = Get-Content -Path $Log -Delimiter "\n"
}

<#
.SYNOPSIS
    Initializes logging infrastructure and required application directories.

.DESCRIPTION
    Prepares the application for logging operations by creating necessary folder structure and initializing the log file.
    Removes any existing log file to start with a clean logging session, then creates the logging directory and a new log file.
    Additionally checks for and creates the updates directory if it does not exist.
    All operations are logged through the Update-Log function with appropriate severity levels.

.PARAMETER
    This function does not accept parameters. It uses global variables $global:workdir to determine base directory paths.

.EXAMPLE
    Set-Logging
    Initializes the logging system with clean log file and required directories.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function should be called during application initialization before any logging operations occur.
    Requires the global variable $global:workdir to be set with the base working directory path.
    The function creates the following structure:
    - $global:workdir\Logging\WIMWitch-tNG.log
    - $global:workdir\updates

.OUTPUTS
    None. Creates directories and log file. All status information is logged via Update-Log function.
#>
Function Set-Logging {
    #logging folder
    if (!(Test-Path -Path "$global:workdir\logging\WIMWitch.Log" -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path "$global:workdir\Logging" | Out-Null
        New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
    } Else {
        Remove-Item -Path "$global:workdir\logging\WIMWitch-tNG.log"
        New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
    }


    #updates folder
    $FileExist = Test-Path -Path "$global:workdir\updates" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Updates folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\updates" | Out-Null
        Update-Log -Data 'Updates folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Updates folder exists' -Class Information }

    #staging folder
    $FileExist = Test-Path -Path "$global:workdir\Staging" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Staging folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Staging" | Out-Null
        Update-Log -Data 'Staging folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Staging folder exists' -Class Information }

    #Mount folder
    $FileExist = Test-Path -Path "$global:workdir\Mount" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Mount folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Mount" | Out-Null
        Update-Log -Data 'Mount folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Mount folder exists' -Class Information }

    #Completed WIMs folder
    $FileExist = Test-Path -Path "$global:workdir\CompletedWIMs" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'CompletedWIMs folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\CompletedWIMs" | Out-Null
        Update-Log -Data 'CompletedWIMs folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'CompletedWIMs folder exists' -Class Information }

    #Configurations XML folder
    $FileExist = Test-Path -Path "$global:workdir\Configs" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Configs folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Configs" | Out-Null
        Update-Log -Data 'Configs folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Configs folder exists' -Class Information }

}

<#
.SYNOPSIS
    Applies a driver to the mounted Windows image.

.DESCRIPTION
    Injects a single driver package into the currently mounted Windows Image (WIM) at the path
    specified in the WPFMISMountTextBox form control. The function uses the Add-WindowsDriver
    cmdlet to apply the driver and logs success or failure information. If the driver application
    fails, a warning is logged rather than terminating execution.

.PARAMETER drivertoapply
    The full path to the driver file (.inf file) or driver package to be applied to the mounted image.
    This parameter is mandatory and should point to a valid Windows driver INF file.

.EXAMPLE
    Install-Driver -drivertoapply 'C:\Drivers\Network\driver.inf'
    Applies the specified network driver to the mounted WIM image.

.EXAMPLE
    'C:\Drivers\Storage\driver.inf' | Install-Driver
    Pipes a driver path to the function for injection into the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is typically called by Start-DriverInjection in a loop to apply multiple drivers.
    The mounted image path is read from the global form control $WPFMISMountTextBox.Text.
    Errors are logged as warnings to allow batch operations to continue.

.OUTPUTS
    None. Logs operation results and updates via Update-Log function.
#>
Function Install-Driver($drivertoapply) {
    try {
        Add-WindowsDriver -Path $WPFMISMountTextBox.Text -Driver $drivertoapply -ErrorAction Stop | Out-Null
        Update-Log -Data "Applied $drivertoapply" -Class Information
    } catch {
        Update-Log -Data "Couldn't apply $drivertoapply" -Class Warning
    }

}

<#
.SYNOPSIS
    Recursively applies all drivers from a specified folder to the mounted Windows image.

.DESCRIPTION
    Scans the specified folder recursively for all driver INF files and applies them to the currently
    mounted Windows Image. The function validates that the provided path is a valid directory before
    processing. Each INF file found is passed to the Install-Driver function for individual application.
    This allows for batch driver injection from a folder structure containing multiple driver packages.

.PARAMETER Folder
    The root folder path containing driver files to be applied. The function searches recursively through
    all subfolders for INF driver files. Invalid or non-existent paths are skipped without error.

.EXAMPLE
    Start-DriverInjection -Folder 'C:\Drivers'
    Recursively applies all INF drivers found in the C:\Drivers folder and its subfolders to the mounted image.

.EXAMPLE
    Start-DriverInjection -Folder $WPFDriverSourceTextBox.Text
    Uses the driver source path from the UI textbox to inject all available drivers.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Invalid or non-existent folder paths are silently skipped. Only files with .inf extension are processed.
    Requires a mounted Windows image with the path configured in $WPFMISMountTextBox.Text.
    Each driver application is logged individually and batch completion is logged.

.OUTPUTS
    None. Logs operation results via Update-Log function for each driver and batch completion.
#>
Function Start-DriverInjection($Folder) {
    #This filters out invalid paths, such as the default value
    $testpath = Test-Path $folder -PathType Container
    If ($testpath -eq $false) { return }

    If ($testpath -eq $true) {

        Update-Log -data "Applying drivers from $folder" -class Information

        Get-ChildItem $Folder -Recurse -Filter '*inf' | ForEach-Object { Install-Driver $_.FullName }
        Update-Log -Data "Completed driver injection from $folder" -Class Information
    }
}

#Function to retrieve OSDUpdate Version
<#
.SYNOPSIS
    Retrieves the installed version of the OSDUpdate PowerShell module.

.DESCRIPTION
    Attempts to import the OSDUpdate module and retrieves its version information.
    Updates the WPF form textbox with the installed version or displays 'Not Installed' if the module is not found.
    Logs all actions and errors through the Update-Log function.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Get-OSDBInstallation
    Retrieves and displays the installed OSDUpdate module version in the WPF interface.

.NOTES
    Author: Eden Nelson
    The function updates global WPF form controls: $WPFUpdatesOSDBVersion.Text
    If the module is not installed, users should run Update-OSDB to install it.

.OUTPUTS
    None. Updates WPF form controls with version information.
#>
Function Get-OSDBInstallation {
    Update-Log -Data 'Getting OSD Installation information' -Class Information
    try {
        Import-Module -Name OSDUpdate -ErrorAction Stop
    } catch {
        $WPFUpdatesOSDBVersion.Text = 'Not Installed.'
        Update-Log -Data 'OSD Update is not installed.' -Class Warning
        Return
    }
    try {
        $OSDBVersion = Get-Module -Name OSDUpdate -ErrorAction Stop
        $WPFUpdatesOSDBVersion.Text = $OSDBVersion.Version
        $text = $osdbversion.version
        Update-Log -data "Installed version of OSD Update is $text." -Class Information
        Return
    } catch {
        Update-Log -Data 'Unable to fetch OSD Update version.' -Class Error
        Return
    }
}

<#
.SYNOPSIS
    Retrieves the installed version of the OSDSUS PowerShell module.

.DESCRIPTION
    Attempts to import the OSDSUS module and retrieves its version information.
    Updates the WPF form textbox with the installed version or displays 'Not Installed' if the module is not found.
    Logs all actions and errors through the Update-Log function.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Get-OSDSUSInstallation
    Retrieves and displays the installed OSDSUS module version in the WPF interface.

.NOTES
    Author: Eden Nelson
    The function updates global WPF form controls: $WPFUpdatesOSDSUSVersion.Text
    If the module is not installed, users should run Update-OSDSUS to install it.

.OUTPUTS
    None. Updates WPF form controls with version information.
#>
Function Get-OSDSUSInstallation {
    Update-Log -Data 'Getting OSDSUS Installation information' -Class 'Information'
    try {
        Import-Module -Name OSDSUS -ErrorAction Stop
    } catch {
        $WPFUpdatesOSDSUSVersion.Text = 'Not Installed'

        Update-Log -Data 'OSDSUS is not installed.' -Class Warning
        Return
    }
    try {
        $OSDSUSVersion = Get-Module -Name OSDSUS -ErrorAction Stop
        $WPFUpdatesOSDSUSVersion.Text = $OSDSUSVersion.Version
        $text = $osdsusversion.version
        Update-Log -data "Installed version of OSDSUS is $text." -Class Information
        Return
    } catch {
        Update-Log -Data 'Unable to fetch OSDSUS version.' -Class Error
        Return
    }
}

<#
.SYNOPSIS
    Retrieves the latest available version of the OSDUpdate module from PowerShell Gallery.

.DESCRIPTION
    Queries the PowerShell Gallery to find the most current available version of the OSDUpdate module.
    Updates the WPF form textbox with the latest available version or displays 'Network Error' if the query fails.
    This information is used by Compare-OSDBuilderVer to determine if updates are available.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Get-OSDBCurrentVer
    Retrieves and displays the latest available OSDUpdate version in the WPF interface.

.NOTES
    Author: Eden Nelson
    The function updates global WPF form controls: $WPFUpdatesOSDBCurrentVerTextBox.Text
    Requires internet connectivity to query the PowerShell Gallery.

.OUTPUTS
    None. Updates WPF form controls with the latest available version.
#>
Function Get-OSDBCurrentVer {
    Update-Log -Data 'Checking for the most current OSDUpdate version available' -Class Information
    try {
        $OSDBCurrentVer = Find-Module -Name OSDUpdate -ErrorAction Stop
        $WPFUpdatesOSDBCurrentVerTextBox.Text = $OSDBCurrentVer.version
        $text = $OSDBCurrentVer.version
        Update-Log -data "$text is the most current version" -class Information
        Return
    } catch {
        $WPFUpdatesOSDBCurrentVerTextBox.Text = 'Network Error'
        Return
    }
}

<#
.SYNOPSIS
    Retrieves the latest available version of the OSDSUS module from PowerShell Gallery.

.DESCRIPTION
    Queries the PowerShell Gallery to find the most current available version of the OSDSUS module.
    Updates the WPF form textbox with the latest available version or displays 'Network Error' if the query fails.
    This information is used by Compare-OSDSUSVer to determine if updates are available.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Get-OSDSUSCurrentVer
    Retrieves and displays the latest available OSDSUS version in the WPF interface.

.NOTES
    Author: Eden Nelson
    The function updates global WPF form controls: $WPFUpdatesOSDSUSCurrentVerTextBox.Text
    Requires internet connectivity to query the PowerShell Gallery.

.OUTPUTS
    None. Updates WPF form controls with the latest available version.
#>
Function Get-OSDSUSCurrentVer {
    Update-Log -Data 'Checking for the most current OSDSUS version available' -Class Information
    try {
        $OSDSUSCurrentVer = Find-Module -Name OSDSUS -ErrorAction Stop
        $WPFUpdatesOSDSUSCurrentVerTextBox.Text = $OSDSUSCurrentVer.version
        $text = $OSDSUSCurrentVer.version
        Update-Log -data "$text is the most current version" -class Information
        Return
    } catch {
        $WPFUpdatesOSDSUSCurrentVerTextBox.Text = 'Network Error'
        Return
    }
}

<#
.SYNOPSIS
    Installs or updates the OSDUpdate PowerShell module.

.DESCRIPTION
    Checks the current installation status of the OSDUpdate module and either installs it for the first time
    or updates it to the latest version available in the PowerShell Gallery. Prompts the user to close all
    PowerShell windows after installation or update to ensure proper module loading on next launch.
    Updates are applied via the Update-ModuleOSDUpdate cmdlet.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Update-OSDB
    Installs OSDUpdate if not present, or updates it if a newer version is available.

.NOTES
    Author: Eden Nelson
    This function modifies global WPF form controls and global workdir variables.
    After installation or update, users must close and reopen WIM Witch for changes to take effect.
    Uses Update-Log for status reporting and error handling.

.OUTPUTS
    None. Modifies WPF form controls and updates global variables.
#>
Function Update-OSDB {
    if ($WPFUpdatesOSDBVersion.Text -eq 'Not Installed') {
        Update-Log -Data 'Attempting to install and import OSD Update' -Class Information
        try {
            Install-Module OSDUpdate -Force -ErrorAction Stop
            #Write-Host "Installed module"
            Update-Log -data 'OSD Update module has been installed' -Class Information
            Import-Module -Name OSDUpdate -Force -ErrorAction Stop
            #Write-Host "Imported module"
            Update-Log -Data 'OSD Update module has been imported' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')
            Return
        } catch {
            $WPFUpdatesOSDBVersion.Text = 'Inst Fail'
            Update-Log -Data "Couldn't install OSD Update" -Class Error
            Update-Log -data $_.Exception.Message -class Error
            Return
        }
    }

    If ($WPFUpdatesOSDBVersion.Text -gt '1.0.0') {
        Update-Log -data 'Attempting to update OSD Update' -class Information
        try {
            Update-ModuleOSDUpdate -ErrorAction Stop
            Update-Log -Data 'Updated OSD Update' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')

            get-OSDBInstallation
            return
        } catch {
            $WPFUpdatesOSDBCurrentVerTextBox.Text = 'OSDB Err'
            Return
        }
    }
}

<#
.SYNOPSIS
    Installs or updates the OSDSUS PowerShell module.

.DESCRIPTION
    Checks the current installation status of the OSDSUS module and either installs it for the first time
    or updates it to the latest version available in the PowerShell Gallery. Prompts the user to close all
    PowerShell windows after installation or update to ensure proper module loading on next launch.
    Updates are performed by uninstalling all versions and reinstalling the latest.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Update-OSDSUS
    Installs OSDSUS if not present, or updates it if a newer version is available.

.NOTES
    Author: Eden Nelson
    This function modifies global WPF form controls and global workdir variables.
    After installation or update, users must close and reopen WIM Witch for changes to take effect.
    Uses Update-Log for status reporting and error handling.

.OUTPUTS
    None. Modifies WPF form controls and updates global variables.
#>
Function Update-OSDSUS {
    if ($WPFUpdatesOSDSUSVersion.Text -eq 'Not Installed') {
        Update-Log -Data 'Attempting to install and import OSDSUS' -Class Information
        try {
            Install-Module OSDUpdate -Force -ErrorAction Stop
            Update-Log -data 'OSDSUS module has been installed' -Class Information
            Import-Module -Name OSDUpdate -Force -ErrorAction Stop
            Update-Log -Data 'OSDSUS module has been imported' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')
            Return
        } catch {
            $WPFUpdatesOSDSUSVersion.Text = 'Inst Fail'
            Update-Log -Data "Couldn't install OSDSUS" -Class Error
            Update-Log -data $_.Exception.Message -class Error
            Return
        }
    }

    If ($WPFUpdatesOSDSUSVersion.Text -gt '1.0.0') {
        Update-Log -data 'Attempting to update OSDSUS' -class Information
        try {
            Uninstall-Module -Name osdsus -AllVersions -Force
            Install-Module -Name osdsus -Force
            Update-Log -Data 'Updated OSDSUS' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')
            get-OSDSUSInstallation
            return
        } catch {
            $WPFUpdatesOSDSUSCurrentVerTextBox.Text = 'OSDSUS Err'
            Return
        }
    }
}

<#
.SYNOPSIS
    Compares the installed OSDUpdate module version with the latest available version.

.DESCRIPTION
    Compares the currently installed OSDUpdate version (retrieved by Get-OSDBInstallation) with the
    latest available version in the PowerShell Gallery (retrieved by Get-OSDBCurrentVer).
    Logs a warning message if updates are available, directing the user to click the Install/Update button.
    If the module is not installed or versions match, appropriate informational messages are logged.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Compare-OSDBuilderVer
    Compares installed and available OSDUpdate versions and logs update availability status.

.NOTES
    Author: Eden Nelson
    This function relies on WPF form controls set by Get-OSDBInstallation and Get-OSDBCurrentVer.
    Should be called after both Get-OSDBInstallation and Get-OSDBCurrentVer have executed.

.OUTPUTS
    None. Logs comparison results via Update-Log function.
#>
Function Compare-OSDBuilderVer {
    Update-Log -data 'Comparing OSD Update module versions' -Class Information
    if ($WPFUpdatesOSDBVersion.Text -eq 'Not Installed') {
        Return
    }
    If ($WPFUpdatesOSDBVersion.Text -eq $WPFUpdatesOSDBCurrentVerTextBox.Text) {
        Update-Log -Data 'OSD Update is up to date' -class Information
        Return
    }
    Update-Log -Data 'OSD Update appears to be out of date. Please click the Install / Update button to update it.' -class Warning
    Update-Log -Data 'OSD Update appears to be out of date. Run the upgrade Function from within WIM Witch to resolve' -class Warning

    Return
}

<#
.SYNOPSIS
    Compares the installed OSDSUS module version with the latest available version.

.DESCRIPTION
    Compares the currently installed OSDSUS version (retrieved by Get-OSDSUSInstallation) with the
    latest available version in the PowerShell Gallery (retrieved by Get-OSDSUSCurrentVer).
    Logs a warning message if updates are available, directing the user to click the Install/Update button.
    If the module is not installed or versions match, appropriate informational messages are logged.

.PARAMETER
    None. This function does not accept parameters.

.EXAMPLE
    Compare-OSDSUSVer
    Compares installed and available OSDSUS versions and logs update availability status.

.NOTES
    Author: Eden Nelson
    This function relies on WPF form controls set by Get-OSDSUSInstallation and Get-OSDSUSCurrentVer.
    Should be called after both Get-OSDSUSInstallation and Get-OSDSUSCurrentVer have executed.

.OUTPUTS
    None. Logs comparison results via Update-Log function.
#>
Function Compare-OSDSUSVer {
    Update-Log -data 'Comparing OSDSUS module versions' -Class Information
    if ($WPFUpdatesOSDSUSVersion.Text -eq 'Not Installed') {
        Return
    }
    If ($WPFUpdatesOSDSUSVersion.Text -eq $WPFUpdatesOSDSUSCurrentVerTextBox.Text) {
        Update-Log -Data 'OSDSUS is up to date' -class Information
        Return
    }
    Update-Log -Data 'OSDSUS appears to be out of date. Please click the Install / Update button to update it.' -class Warning
    Update-Log -Data 'OSDSUS appears to be out of date. Run the upgrade Function from within WIM Witch to resolve' -class Warning

    Return
}

<#
.SYNOPSIS
    Identifies and optionally removes superseded Windows updates from the update storage directory.

.DESCRIPTION
    Scans the WIM Witch update storage directory for a specified Windows OS and build version.
    Queries the OSDUpdate catalog to determine which updates are still current and which have been superseded.
    Can either audit superseded updates (report only) or delete them to free storage space.
    Properly handles nested directory structures and complex update package hierarchies.

.PARAMETER action
    Specifies the action to perform on superseded updates: 'delete' removes superseded files and folders,
    'audit' reports superseded updates without removing them.

.PARAMETER OS
    The Windows operating system to check (e.g., 'Windows 10', 'Windows 11', 'Windows Server').

.PARAMETER Build
    The build number to check (e.g., '22H2', '23H2', '24H2', '1809', '21H2').

.EXAMPLE
    Test-Superceded -action audit -OS 'Windows 10' -Build '22H2'
    Audits for superseded updates in Windows 10 22H2 without deleting them.

.EXAMPLE
    Test-Superceded -action delete -OS 'Windows 11' -Build '24H2'
    Deletes all superseded updates from Windows 11 24H2 directory.

.NOTES
    Author: Eden Nelson
    Uses the global $workdir variable for the update storage location.
    Requires the OSDUpdate module to query current update status.
    Updates WPF form controls when superseded updates are discovered in audit mode.

.OUTPUTS
    None. Deletes files/folders or updates WPF form controls based on action parameter.
#>
Function Test-Superceded($action, $OS, $Build) {
    Update-Log -Data 'Checking WIM Witch Update store for superseded updates' -Class Information
    $path = $global:workdir + '\updates\' + $OS + '\' + $Build + '\' #sets base path

    if ((Test-Path -Path $path) -eq $false) {
        Update-Log -Data 'No updates found, likely not yet downloaded. Skipping supersedense check...' -Class Warning
        return
    }

    $Children = Get-ChildItem -Path $path  #query sub directories

    foreach ($Children in $Children) {
        $path1 = $path + $Children
        $sprout = Get-ChildItem -Path $path1


        foreach ($sprout in $sprout) {
            $path3 = $path1 + '\' + $sprout
            $fileinfo = Get-ChildItem -Path $path3
            foreach ($file in $fileinfo) {
                $StillCurrent = Get-OSDUpdate | Where-Object { $_.FileName -eq $file }
                If ($null -eq $StillCurrent) {
                    Update-Log -data "$file no longer current" -Class Warning
                    if ($action -eq 'delete') {
                        Update-Log -data "Deleting $path3" -class Warning
                        Remove-Item -Path $path3 -Recurse -Force
                    }
                    if ($action -eq 'audit') {
                        $WPFUpdatesOSDListBox.items.add('Superceded updates discovered. Please select the versions of Windows 10 you are supporting and click Update')
                        Return
                    }
                } else {
                    Update-Log -data "$file is still current" -Class Information
                }
            }
        }
    }
    Update-Log -data 'Supercedense check complete.' -Class Information
}

<#
.SYNOPSIS
    Downloads Windows updates for a specified OS version and build from the OSDUpdate catalog.

.DESCRIPTION
    Downloads multiple categories of Windows updates including SSU (Servicing Stack Updates), AdobeSU,
    LCU (Latest Cumulative Updates), .NET Framework updates, and optional/dynamic updates based on user preferences.
    Uses the OSDUpdate module's Get-OSDUpdate and Get-DownOSDUpdate cmdlets to retrieve and download files.
    Updates are organized into separate folders by category within the update storage directory.
    Handles errors gracefully for each update category independently.

.PARAMETER build
    The Windows build version to download updates for (e.g., '22H2', '23H2', '24H2', '1809', '21H2').

.PARAMETER OS
    The Windows operating system to download updates for (e.g., 'Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Get-WindowsPatches -build '22H2' -OS 'Windows 10'
    Downloads all available Windows 10 22H2 updates to the configured update storage directory.

.NOTES
    Author: Eden Nelson
    Uses global variables: $global:workdir for storage location, WPF checkboxes for optional/dynamic flags.
    Downloads include: SSU, AdobeSU, LCU, DotNet, DotNetCU, and optionally Optional and SetupDU (Dynamic).
    Each category is downloaded to its own subdirectory based on UpdateGroup classification.

.OUTPUTS
    None. Downloads files to disk and logs progress via Update-Log function.
#>
Function Get-WindowsPatches($build, $OS) {
    Update-Log -Data "Downloading SSU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'SSU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\SSU
    } catch {
        Update-Log -data 'Failed to download SSU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading AdobeSU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'AdobeSU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\AdobeSU
    } catch {
        Update-Log -data 'Failed to download AdobeSU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading LCU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'LCU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\LCU
    } catch {
        Update-Log -data 'Failed to download LCU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }
    Update-Log -Data "Downloading .Net updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'DotNet' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\DotNet
    } catch {
        Update-Log -data 'Failed to download .Net update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading .Net CU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'DotNetCU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\DotNetCU
    } catch {
        Update-Log -data 'Failed to download .Net CU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    if ($WPFUpdatesCBEnableOptional.IsChecked -eq $True) {
        try {
            Update-Log -Data "Downloading optional updates for $OS $build" -Class Information
            Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'Optional' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\Optional
        } catch {
            Update-Log -data 'Failed to download optional update' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }
    }

    if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) {
        try {
            Update-Log -Data "Downloading dynamic updates for $OS $build" -Class Information
            Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'SetupDU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\Dynamic
        } catch {
            Update-Log -data 'Failed to download dynamic update' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }
    }


    Update-Log -Data "Downloading completed for $OS $build" -Class Information


}

<#
.SYNOPSIS
    Coordinates the removal of superseded updates and downloads of current patches for selected Windows versions.

.DESCRIPTION
    Provides a central orchestration function that integrates supersedence checking, update removal, and
    new patch downloads. Supports both OSDSUS and ConfigMgr (Intune) catalog sources. Processes all selected
    Windows versions and builds from the WPF form, performing supersedence checks and initiating downloads
    for Windows 10 (22H2), Windows 11 (23H2, 24H2, 25H2), and Windows Server versions (1607, 1809, 21H2).

.PARAMETER
    None. This function does not accept parameters. All configuration comes from WPF form controls.

.EXAMPLE
    Update-PatchSource
    Processes all selected Windows versions and downloads current patches after removing superseded updates.

.NOTES
    Author: Eden Nelson
    This is the primary workflow function for managing update sources. It reads multiple WPF checkboxes
    to determine which OS versions and builds to process. Supports both OSDSUS and ConfigMgr update sources.
    Calls Get-OneDrive on completion for cloud integration.

.OUTPUTS
    None. Downloads files to disk and updates WPF form controls with progress information.
#>
Function Update-PatchSource {

    Update-Log -Data 'attempting to start download Function' -Class Information
    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'OSDSUS') {
        if ($WPFUpdatesW10Main.IsChecked -eq $true) {
            if ($WPFUpdatesW10_22H2.IsChecked -eq $true) {
                Test-Superceded -action delete -build 22H2 -OS 'Windows 10'
                Get-WindowsPatches -build 22H2 -OS 'Windows 10'
            }
        }
        if ($WPFUpdatesS2019.IsChecked -eq $true) {
            Test-Superceded -action delete -build 1809 -OS 'Windows Server'
            Get-WindowsPatches -build 1809 -OS 'Windows Server'
        }
        if ($WPFUpdatesS2016.IsChecked -eq $true) {
            Test-Superceded -action delete -build 1607 -OS 'Windows Server'
            Get-WindowsPatches -build 1607 -OS 'Windows Server'
        }
        if ($WPFUpdatesS2022.IsChecked -eq $true) {
            Test-Superceded -action delete -build 21H2 -OS 'Windows Server'
            Get-WindowsPatches -build 21H2 -OS 'Windows Server'
        }

        if ($WPFUpdatesW11Main.IsChecked -eq $true) {
            if ($WPFUpdatesW11_23h2.IsChecked -eq $true) {
                Write-Host '23H2'
                Test-Superceded -action delete -build 23H2 -OS 'Windows 11'
                Get-WindowsPatches -build 23H2 -OS 'Windows 11'
            }
            if ($WPFUpdatesW11_24h2.IsChecked -eq $true) {
                Write-Host '24H2'
                Test-Superceded -action delete -build 24H2 -OS 'Windows 11'
                Get-WindowsPatches -build 24H2 -OS 'Windows 11'
            }
            if ($WPFUpdatesW11_25h2.IsChecked -eq $true) {
                Write-Host '25H2'
                Test-Superceded -action delete -build 25H2 -OS 'Windows 11'
                Get-WindowsPatches -build 25H2 -OS 'Windows 11'
            }

        }
        Get-OneDrive
    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'ConfigMgr') {
        if ($WPFUpdatesW10Main.IsChecked -eq $true) {
            if ($WPFUpdatesW10_22H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 10' -Ver '22H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 10' -ver '22H2'
            }
            #Get-OneDrive
        }
        if ($WPFUpdatesS2019.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '1809'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '1809'
        }
        if ($WPFUpdatesS2016.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '1607'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '1607'
        }
        if ($WPFUpdatesS2022.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '21H2'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '21H2'
        }
        if ($WPFUpdatesW11Main.IsChecked -eq $true) {
            if ($WPFUpdatesW11_23H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '23H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '23H2'
            }
            if ($WPFUpdatesW11_24H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '24H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '24H2'
            }
            if ($WPFUpdatesW11_25H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '25H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '25H2'
            }
        }
        Get-OneDrive
    }
    Update-Log -data 'All downloads complete' -class Information
}

<#
.SYNOPSIS
    Deploys Latest Cumulative Update (LCU) packages to the mounted Windows image.

.DESCRIPTION
    Handles OS-specific deployment of LCU packages. For Windows 10, extracts the LCU CAB file and applies
    both SSU (Servicing Stack Update) and LCU components. For Windows 11, converts the CAB file to MSU format
    and applies it directly. Supports demo mode for testing without actually applying updates.
    Properly orders SSU application before LCU to ensure system stability.

.PARAMETER packagepath
    The full path to the LCU package directory containing the CAB file(s) to be deployed.

.EXAMPLE
    Deploy-LCU -packagepath 'C:\workdir\updates\Windows 10\22H2\LCU'
    Deploys the LCU package to the currently mounted Windows 10 image.

.NOTES
    Author: Eden Nelson
    Uses global variables: $global:workdir for staging location, $WPFMISMountTextBox.Text for mount path.
    Respects $demomode variable to skip actual updates during testing.
    Windows 10 uses expand.exe for CAB extraction; Windows 11 converts CAB to MSU format.
    Must be run after the WIM image is mounted by Mount-WindowsImage.

.OUTPUTS
    None. Applies packages to mounted image and logs progress via Update-Log function.
#>
Function Deploy-LCU($packagepath) {

    $osver = Get-WindowsType

    if ($osver -eq 'Windows 10') {
        $executable = "$env:windir\system32\expand.exe"
        $filename = (Get-ChildItem $packagepath).name
        Update-Log -Data 'Extracting LCU Package content to staging folder...' -Class Information
        Start-Process $executable -args @("`"$packagepath\$filename`"", '/f:*.CAB', "`"$global:workdir\staging`"") -Wait -ErrorAction Stop
        $cabs = (Get-Item $global:workdir\staging\*.cab)

        #MMSMOA2022
        Update-Log -data 'Applying SSU...' -class information
        foreach ($cab in $cabs) {

            if ($cab -like '*SSU*') {
                Update-Log -data $cab -class Information

                if ($demomode -eq $false) { Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $cab -ErrorAction stop | Out-Null }
                else {
                    $string = 'Demo mode active - Not applying ' + $cab
                    Update-Log -data $string -Class Warning
                }
            }

        }

        Update-Log -data 'Applying LCU...' -class information
        foreach ($cab in $cabs) {
            if ($cab -notlike '*SSU*') {
                Update-Log -data $cab -class information
                if ($demomode -eq $false) { Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $cab -ErrorAction stop | Out-Null }
                else {
                    $string = 'Demo mode active - Not applying ' + $cab
                    Update-Log -data $string -Class Warning
                }
            }
        }
    }
    if ($osver -eq 'Windows 11') {
        # Copy files to staging and apply
        Update-Log -data 'Copying LCU file(s) to staging folder...' -class information
        $filenames = @(Get-ChildItem -Path $packagepath -Name)

        foreach ($filename in $filenames) {
            Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force

            Update-Log -data 'Changing file extension type from CAB to MSU...' -class information
            $basename = (Get-Item -Path $global:workdir\staging\$filename).BaseName
            $newname = $basename + '.msu'
            Rename-Item -Path $global:workdir\staging\$filename -NewName $newname

            Update-Log -data 'Applying LCU...' -class information
            Update-Log -data $global:workdir\staging\$newname -class information
            $updatename = (Get-Item -Path $packagepath\$filename).name
            Update-Log -data $updatename -Class Information

            try {
                if ($demomode -eq $false) {
                    Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $global:workdir\staging\$newname -ErrorAction Stop | Out-Null
                } else {
                    $string = 'Demo mode active - Not applying ' + $updatename
                    Update-Log -data $string -Class Warning
                }
            } catch {
                Update-Log -data 'Failed to apply update' -class Warning
                Update-Log -data $_.Exception.Message -class Warning
            }
        }


    }

}

<#
.SYNOPSIS
    Applies Windows updates to a mounted Windows image based on the specified update class.

.DESCRIPTION
    Comprehensive update deployment function that handles multiple update types and Windows versions.
    Supports SSU, LCU, AdobeSU, .NET, DotNetCU, Optional, and Dynamic/PE (Preinstallation Environment) updates.
    Automatically detects Windows version and build, handles version-specific deployment logic,
    and provides fallback mechanisms for different OS configurations. Skips Adobe updates for Server Core builds.
    Manages PE-prefixed updates separately for Windows PE environments.

.PARAMETER class
    The class of updates to deploy: 'SSU', 'LCU', 'AdobeSU', 'DotNet', 'DotNetCU', 'Optional', 'Dynamic',
    'PESSU' (PE SSU), or 'PELCU' (PE LCU). PE variants are routed to the mount directory for PE images.

.EXAMPLE
    Deploy-Updates -class 'LCU'
    Applies all Latest Cumulative Updates appropriate for the currently mounted Windows image.

.EXAMPLE
    Deploy-Updates -class 'DotNet'
    Applies all .NET Framework updates to the mounted image.

.NOTES
    Author: Eden Nelson
    Uses global variables: $global:workdir for update storage, WPF form controls for mount paths and image info.
    Automatically handles special cases: Windows 10 18362 build detection, 1903 vs 1909 differentiation for PE.
    Respects demo mode to prevent actual updates during testing via $demomode variable.
    Dynamic updates are extracted to media\sources; other updates use Add-WindowsPackage.

.OUTPUTS
    None. Applies packages to mounted image and logs progress via Update-Log function.
#>
Function Deploy-Updates($class) {

    if (($class -eq 'AdobeSU') -and ($WPFSourceWIMImgDesTextBox.text -like 'Windows Server 20*') -and ($WPFSourceWIMImgDesTextBox.text -notlike '*(Desktop Experience)')) {
        Update-Log -Data 'Skipping Adobe updates for Server Core build' -Class Information
        return
    }

    $OS = Get-WindowsType
    $buildnum = Get-WinVersionNumber

    if ($buildnum -eq '2009') { $buildnum = '20H2' }

    If (($WPFSourceWimVerTextBox.text -like '10.0.18362.*') -and (($class -ne 'Dynamic') -and ($class -notlike 'PE*'))) {
        $mountdir = $WPFMISMountTextBox.Text
        reg LOAD HKLM\OFFLINE $mountdir\Windows\System32\Config\SOFTWARE | Out-Null
        $regvalues = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\OFFLINE\Microsoft\Windows NT\CurrentVersion\' )
        $buildnum = $regvalues.ReleaseId
        reg UNLOAD HKLM\OFFLINE | Out-Null
    }

    If (($WPFSourceWimVerTextBox.text -like '10.0.18362.*') -and (($class -eq 'Dynamic') -or ($class -like 'PE*'))) {
        $windowsver = Get-WindowsImage -ImagePath ($global:workdir + '\staging\' + $WPFMISWimNameTextBox.text) -Index 1
        $Vardate = (Get-Date -Year 2019 -Month 10 -Day 01)
        if ($windowsver.CreatedTime -gt $vardate) { $buildnum = 1909 }
        else
        { $buildnum = 1903 }
    }

    if ($class -eq 'PESSU') {
        $IsPE = $true
        $class = 'SSU'
    }

    if ($class -eq 'PELCU') {
        $IsPE = $true
        $class = 'LCU'
    }

    $path = $global:workdir + '\updates\' + $OS + '\' + $buildnum + '\' + $class + '\'


    if ((Test-Path $path) -eq $False) {
        Update-Log -data "$path does not exist. There are no updates of this class to apply" -class Warning
        return
    }

    $Children = Get-ChildItem -Path $path
    foreach ($Child in $Children) {
        $compound = $Child.fullname
        Update-Log -Data "Applying $Child" -Class Information
        try {
            if ($class -eq 'Dynamic') {
                #Update-Log -data "Applying Dynamic to media" -Class Information
                $mediafolder = $global:workdir + '\staging\media\sources'
                $DynUpdates = (Get-ChildItem -Path $compound -Name)
                foreach ($DynUpdate in $DynUpdates) {

                    $text = $compound + '\' + $DynUpdate
                    #write-host $text
                    Start-Process -FilePath c:\windows\system32\expand.exe -args @("`"$text`"", '-F:*', "`"$mediafolder`"") -Wait
                }
            } elseif ($IsPE -eq $true) { Add-WindowsPackage -Path ($global:workdir + '\staging\mount') -PackagePath $compound -ErrorAction stop | Out-Null }
            else {
                if ($class -eq 'LCU') {
                    if (($os -eq 'Windows 10') -and (($buildnum -eq '2004') -or ($buildnum -eq '2009') -or ($buildnum -eq '20H2') -or ($buildnum -eq '21H1') -or ($buildnum -eq '21H2') -or ($buildnum -eq '22H2'))) {
                        Update-Log -data 'Processing the LCU package to retrieve SSU...' -class information
                        Deploy-LCU -packagepath $compound
                    } elseif ($os -eq 'Windows 11') {
                        Update-Log -data 'Windows 11 required LCU modification started...' -Class Information
                        Deploy-LCU -packagepath $compound
                    }

                    else {

                        Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $compound -ErrorAction stop | Out-Null
                    }
                }

                else { Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $compound -ErrorAction stop | Out-Null }

            }
        } catch {
            Update-Log -data 'Failed to apply update' -class Warning
            Update-Log -data $_.Exception.Message -class Warning
        }
    }
}

#Function to select AppX packages to yank
<#
.SYNOPSIS
    Prompts user to select AppX packages to remove from the Windows image.

.DESCRIPTION
    Loads the appropriate AppX package list file based on the detected Windows version and build number.
    Displays all available packages in a grid view dialog allowing user multi-select.
    Updates the form with selected packages and returns the selection for processing.

.EXAMPLE
    Select-Appx
    Displays AppX packages available for the selected Windows image and allows selection for removal.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: $WPFSourceWimTBVersionNum, $WPFAppxTextBox global variables
    AppX list files are stored in Assets folder with naming convention: appxWin##_##.psd1

.OUTPUTS
    Array of strings
    Returns array of selected AppX package names, or $null if none selected.
#>
Function Select-Appx {

    $AssetsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Assets'

    $OS = Get-WindowsType
    $buildnum = $WPFSourceWimTBVersionNum.text

    if ($OS -eq 'Windows 10') {
        $OS = 'Win10'
    }
    if ($OS -eq 'Windows 11') {
        $OS = 'Win11'
    }

    $appxListFile = Join-Path -Path $AssetsPath -ChildPath $("appx$OS" + '_' + "$buildnum.psd1")
    Update-Log -Data "Looking for Appx list file $appxListFile" -Class Information

    if (Test-Path $appxListFile) {
        $appxData = Import-PowerShellDataFile $appxListFile
        $appxPackages = $appxData.Packages
        $exappxs = $appxPackages | Out-GridView -Title 'Select apps to remove' -PassThru
    } else {
        Write-Warning "No matching Appx list file found for build $buildnum."
        return
    }

    if ($null -eq $exappxs) {
        Update-Log -Data 'No apps were selected' -Class Warning
    } elseif ($null -ne $exappxs) {
        Update-Log -data 'The following apps were selected for removal:' -Class Information
        Foreach ($exappx in $exappxs) {
            Update-Log -Data $exappx -Class Information
        }

        $WPFAppxTextBox.Text = $exappxs -join "`r`n"
        return $exappxs
    }
}

<#
.SYNOPSIS
    Removes selected AppX packages from the mounted Windows image.

.DESCRIPTION
    Iterates through an array of AppX package names and removes each one from the currently mounted
    Windows image using Remove-AppxProvisionedPackage. Handles removal errors gracefully, logging
    each package removal attempt and any failures. This function is typically called after the user
    has selected which AppX packages to remove using Select-Appx.

.PARAMETER array
    An array of AppX package names to be removed from the mounted image.
    These package names should match the provisioned package identifiers in the Windows image.
    Type: [System.Object[]]
    Required: $true
    Position: 0

.EXAMPLE
    Remove-Appx -array $selectedPackages
    Removes all packages in the $selectedPackages array from the mounted image.

.EXAMPLE
    $packages = 'Microsoft.ZuneMusic_*', 'Microsoft.ZuneVideo_*'
    Remove-Appx -array $packages
    Removes the specified Zune music and video packages from the mounted Windows image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    The mounted image path is read from the global form control $WPFMISMountTextBox.Text.
    Each package removal is logged individually via the Update-Log function.
    If a package fails to remove, the error is logged but processing continues with remaining packages.
    This function should only be called when the WIM image is properly mounted and the form is initialized.

.OUTPUTS
    None. Logs all removal operations and results via the Update-Log function.
    Returns after processing all packages in the array.
#>
Function Remove-Appx($array) {
    $exappxs = $array
    Update-Log -data 'Starting AppX removal' -class Information
    foreach ($exappx in $exappxs) {
        try {
            Remove-AppxProvisionedPackage -Path $WPFMISMountTextBox.Text -PackageName $exappx -ErrorAction Stop | Out-Null
            Update-Log -data "Removing $exappx" -Class Information
        } catch {
            Update-Log -Data "Failed to remove $exappx" -Class Error
            Update-Log -Data $_.Exception.Message -Class Error
        }
    }
    return
}

#Function to remove unwanted image indexes
<#
.SYNOPSIS
    Removes all image indexes from a WIM file except the selected one.

.DESCRIPTION
    Identifies all images within the staging WIM file and removes all indexes
    except the one currently selected in the form (specified in $WPFSourceWIMImgDesTextBox).
    This operation permanently modifies the WIM file to contain only the desired image.
    Iterates through all available images, evaluates each one against the selected image,
    and removes non-matching indexes using Remove-WindowsImage.

.PARAMETER
    This function does not accept parameters. It uses global variables:
    - $global:workdir: Base working directory path
    - $WPFSourceWIMImgDesTextBox.Text: Contains the name of the image index to keep

.EXAMPLE
    Remove-OSIndex
    Removes all image indexes from the WIM file except the currently selected one.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This is a destructive operation. The WIM file in $global:workdir\Staging\*.wim
    will be permanently modified with all non-selected indexes removed.
    Logs all operations via Update-Log function for troubleshooting.
    Assumes exactly one WIM file exists in the Staging directory.

.OUTPUTS
    None. Modifies the WIM file in place and logs all operations.
#>
Function Remove-OSIndex {
    Update-Log -Data 'Attempting to remove unwanted image indexes' -Class Information
    $wimname = Get-Item -Path $global:workdir\Staging\*.wim

    Update-Log -Data "Found Image $wimname" -Class Information
    $IndexesAll = Get-WindowsImage -ImagePath $wimname | ForEach-Object { $_.ImageName }
    $IndexSelected = $WPFSourceWIMImgDesTextBox.Text
    foreach ($Index in $IndexesAll) {
        Update-Log -data "$Index is being evaluated"
        If ($Index -eq $IndexSelected) {
            Update-Log -Data "$Index is the index we want to keep. Skipping." -Class Information | Out-Null
        } else {
            Update-Log -data "Deleting $Index from WIM" -Class Information
            Remove-WindowsImage -ImagePath $wimname -Name $Index -InformationAction SilentlyContinue | Out-Null

        }
    }
}

#Function to select which folder to save Autopilot JSON file to
<#
.SYNOPSIS
    Prompts user to select a directory for saving Autopilot JSON profile files.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a destination directory
    for saving Autopilot profile JSON files. Updates the form textbox with the selected path.

.EXAMPLE
    Select-NewJSONDir
    Opens folder dialog and updates Autopilot save directory field.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFJSONTextBoxSavePath
    This selected directory will be used as the destination for Autopilot profile exports.

.OUTPUTS
    None. Updates form variable.
#>
<#
.SYNOPSIS
    Prompts the user to select a directory for saving Autopilot JSON configuration files.

.DESCRIPTION
    Opens a Windows Forms folder browser dialog allowing the user to browse and select a target directory
    for saving Autopilot JSON configuration files. The selected path is updated in the form's save path
    textbox control and logged for audit purposes. This function is used to specify the output location
    when retrieving Autopilot profiles from Intune.

.PARAMETER
    This function does not accept parameters. It uses global WPF form variables for interaction.

.EXAMPLE
    Select-NewJSONDir
    Opens folder browser dialog and updates the JSON save path textbox with user selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires System.Windows.Forms assembly for folder browser dialog functionality.
    Updates the global variable $WPFJSONTextBoxSavePath with the selected folder path.
    The selection is logged with Information classification.

.OUTPUTS
    None. Updates the $WPFJSONTextBoxSavePath textbox control with the selected folder path.
#>
Function Select-NewJSONDir {

    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the folder to save JSON'
    $null = $browser.ShowDialog()
    $SaveDir = $browser.SelectedPath
    $WPFJSONTextBoxSavePath.text = $SaveDir
    $text = "Autopilot profile save path selected: $SaveDir"
    Update-Log -Data $text -Class Information
}

<#
.SYNOPSIS
    Updates the WindowsAutopilotIntune PowerShell module to the latest available version.

.DESCRIPTION
    Uninstalls the current version of the WindowsAutopilotIntune module and installs the latest available version
    from the PowerShell Gallery. After successful installation, prompts the user that WIM Witch must close and
    PowerShell must be restarted to complete the update process. Closes the application upon user confirmation.

.PARAMETER
    This function does not accept parameters.

.EXAMPLE
    Update-Autopilot
    Uninstalls current WindowsAutopilotIntune module and installs latest version, then closes application.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is called when a newer version of the WindowsAutopilotIntune module is available and the user
    chooses to proceed with the update. The application will exit after the update to allow PowerShell to reload
    the new module version.

.OUTPUTS
    None. Updates module and closes the application.
#>
Function Update-Autopilot {
    Update-Log -Data 'Uninstalling old WindowsAutopilotIntune module...' -Class Warning
    Uninstall-Module -Name WindowsAutopilotIntune -AllVersions
    Update-Log -Data 'Installing new WindowsAutopilotIntune module...' -Class Warning
    Install-Module -Name WindowsAutopilotIntune -Force
    $AutopilotUpdate = ([System.Windows.MessageBox]::Show('WIM Witch needs to close and PowerShell needs to be restarted. Click OK to close WIM Witch.', 'Updating complete.', 'OK', 'warning'))
    if ($AutopilotUpdate -eq 'OK') {
        $form.Close()
        exit
    }
}

<#
.SYNOPSIS
    Retrieves the Autopilot profile from Microsoft Intune and saves it as a JSON configuration file.

.DESCRIPTION
    Ensures all required dependencies are installed (NuGet, AzureAD, and WindowsAutopilotIntune modules),
    checks for module updates, and connects to Microsoft Intune. Retrieves available Autopilot profiles,
    presents them in an interactive selection dialog, and exports the selected profile as a JSON configuration
    file to the specified output directory. The JSON file is saved as 'AutopilotConfigurationFile.json'.

.PARAMETER login
    The user login credentials or identifier for authenticating with Microsoft Intune.
    This parameter is provided for potential future use in the function.

.PARAMETER path
    The file system path where the Autopilot configuration JSON file will be saved.
    The function will create 'AutopilotConfigurationFile.json' in this directory.

.EXAMPLE
    Get-WWAutopilotProfile -login 'user@contoso.com' -path 'C:\Autopilot'
    Retrieves Autopilot profile from Intune and saves JSON configuration to C:\Autopilot\AutopilotConfigurationFile.json

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires:
    - NuGet package provider (minimum version 2.8.5.201)
    - AzureAD PowerShell module
    - WindowsAutopilotIntune PowerShell module
    - Interactive access to Microsoft Intune

    The function automatically installs missing dependencies. If the WindowsAutopilotIntune module is outdated,
    the user is prompted to update it. Module versions prior to 3.9 use Connect-AutopilotIntune; version 3.9
    and later use Connect-MSGraph for authentication.

.OUTPUTS
    None. Creates an AutopilotConfigurationFile.json file in the specified path directory.
#>
Function Get-WWAutopilotProfile($login, $path) {
    Update-Log -data 'Checking dependencies for Autopilot profile retrieval...' -Class Information

    try {
        Import-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -ErrorAction Stop
        Update-Log -Data 'NuGet is installed' -Class Information
    } catch {
        Update-Log -data 'NuGet is not installed. Installing now...' -Class Warning
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Update-Log -data 'NuGet is now installed' -Class Information
    }

    try {

        Import-Module -Name AzureAD -ErrorAction Stop | Out-Null
        Update-Log -data 'AzureAD Module is installed' -Class Information
    } catch {
        Update-Log -data 'AzureAD Module is not installed. Installing now...' -Class Warning
        Install-Module AzureAD -Force
        Update-Log -data 'AzureAD is now installed' -class Information
    }

    try {

        Import-Module -Name WindowsAutopilotIntune -ErrorAction Stop
        Update-Log -data 'WindowsAutopilotIntune module is installed' -Class Information
    } catch {

        Update-Log -data 'WindowsAutopilotIntune module is not installed. Installing now...' -Class Warning
        Install-Module WindowsAutopilotIntune -Force
        Update-Log -data 'WindowsAutopilotIntune module is now installed.' -class Information
    }

    $AutopilotInstalledVer = (Get-Module -Name windowsautopilotintune).Version
    Update-Log -Data "The currently installed version of the WindowsAutopilotIntune module is $AutopilotInstalledVer" -Class Information
    $AutopilotLatestVersion = (Find-Module -Name windowsautopilotintune).version
    Update-Log -data "The latest available version of the WindowsAutopilotIntune module is $AutopilotLatestVersion" -Class Information

    if ($AutopilotInstalledVer -eq $AutopilotLatestVersion) {
        Update-Log -data 'WindowsAutopilotIntune module is current. Continuing...' -Class Information
    } else {
        Update-Log -data 'WindowsAutopilotIntune module is out of date. Prompting the user to upgrade...'
        $UpgradeAutopilot = ([System.Windows.MessageBox]::Show("Would you like to update the WindowsAutopilotIntune module to version $AutopilotLatestVersion now?", 'Update Autopilot Module?', 'YesNo', 'warning'))
    }

    if ($UpgradeAutopilot -eq 'Yes') {
        Update-Log -Data 'User has chosen to update WindowsAutopilotIntune module' -Class Warning
        Update-Autopilot
    } elseif ($AutopilotInstalledVer -ne $AutopilotLatestVersion) {
        Update-Log -data 'User declined to update WindowsAutopilotIntune module. Continuing...' -Class Warning
    }


    Update-Log -data 'Connecting to Intune...' -Class Information
    if ($AutopilotInstalledVer -lt 3.9) { Connect-AutopilotIntune | Out-Null }
    else {
        Connect-MSGraph | Out-Null
    }

    Update-Log -data 'Connected to Intune' -Class Information

    Update-Log -data 'Retrieving profile...' -Class Information
    Get-AutoPilotProfile | Out-GridView -Title 'Select Autopilot profile' -PassThru | ConvertTo-AutoPilotConfigurationJSON | Out-File $path\AutopilotConfigurationFile.json -Encoding ASCII
    $text = $path + '\AutopilotConfigurationFile.json'
    Update-Log -data "Profile successfully created at $text" -Class Information
}

#Function to save current configuration
<#
.SYNOPSIS
    Saves the current WIM customization configuration to a file.

.DESCRIPTION
    Captures all current WPF form control values and settings from the WIMWitch application interface,
    then saves them to a configuration file in PSD1 format. This allows users to save their customization
    preferences for later use. The function collects settings for source WIM, updates, drivers, Autopilot,
    applications, language packs, features on demand, custom scripts, and Configuration Manager integration
    if enabled. The saved configuration can be reloaded using Get-Configuration.

.PARAMETER filename
    The name or path of the configuration file to save. If not specified, defaults to a generated filename
    based on system information and timestamp.

.PARAMETER CM
    A switch parameter that, when specified, includes Configuration Manager-specific settings in the saved
    configuration file, such as image type, package ID, site code, and distribution point information.
    If not specified, only standard WIMWitch settings are saved.

.EXAMPLE
    Save-Configuration -filename 'MyConfig.psd1'
    Saves the current configuration to MyConfig.psd1 with standard WIMWitch settings.

.EXAMPLE
    Save-Configuration -filename 'CMConfig.psd1' -CM
    Saves the current configuration with Configuration Manager settings included.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function reads from global WPF form variables created from XAML and saves all current state.
    The configuration file can be imported later to restore all settings.

.OUTPUTS
    None. Creates or overwrites the specified configuration file with PSD1 formatted data.
#>
Function Save-Configuration {
    Param(
        [parameter(mandatory = $false, HelpMessage = 'config file')]
        [string]$filename,

        [parameter(mandatory = $false, HelpMessage = 'enable CM files')]
        [switch]$CM
    )

    $CurrentConfig = @{
        SourcePath       = $WPFSourceWIMSelectWIMTextBox.text
        SourceIndex      = $WPFSourceWimIndexTextBox.text
        SourceEdition    = $WPFSourceWIMImgDesTextBox.text
        UpdatesEnabled   = $WPFUpdatesEnableCheckBox.IsChecked
        AutopilotEnabled = $WPFJSONEnableCheckBox.IsChecked
        AutopilotPath    = $WPFJSONTextBox.text
        DriversEnabled   = $WPFDriverCheckBox.IsChecked
        DriverPath1      = $WPFDriverDir1TextBox.text
        DriverPath2      = $WPFDriverDir2TextBox.text
        DriverPath3      = $WPFDriverDir3TextBox.text
        DriverPath4      = $WPFDriverDir4TextBox.text
        DriverPath5      = $WPFDriverDir5TextBox.text
        AppxIsEnabled    = $WPFAppxCheckBox.IsChecked
        AppxSelected     = $WPFAppxTextBox.Text
        WIMName          = $WPFMISWimNameTextBox.text
        WIMPath          = $WPFMISWimFolderTextBox.text
        MountPath        = $WPFMISMountTextBox.text
        DotNetEnabled    = $WPFMISDotNetCheckBox.IsChecked
        OneDriveEnabled  = $WPFMISOneDriveCheckBox.IsChecked
        LPsEnabled       = $WPFCustomCBLangPacks.IsChecked
        LXPsEnabled      = $WPFCustomCBLEP.IsChecked
        FODsEnabled      = $WPFCustomCBFOD.IsChecked
        LPListBox        = $WPFCustomLBLangPacks.items
        LXPListBox       = $WPFCustomLBLEP.Items
        FODListBox       = $WPFCustomLBFOD.Items
        PauseAfterMount  = $WPFMISCBPauseMount.IsChecked
        PauseBeforeDM    = $WPFMISCBPauseDismount.IsChecked
        RunScript        = $WPFCustomCBRunScript.IsChecked
        ScriptTiming     = $WPFCustomCBScriptTiming.SelectedItem
        ScriptFile       = $WPFCustomTBFile.Text
        ScriptParams     = $WPFCustomTBParameters.Text
        CMImageType      = $WPFCMCBImageType.SelectedItem
        CMPackageID      = $WPFCMTBPackageID.Text
        CMImageName      = $WPFCMTBImageName.Text
        CMVersion        = $WPFCMTBImageVer.Text
        CMDescription    = $WPFCMTBDescription.Text
        CMBinDifRep      = $WPFCMCBBinDirRep.IsChecked
        CMSiteCode       = $WPFCMTBSitecode.Text
        CMSiteServer     = $WPFCMTBSiteServer.Text
        CMDPGroup        = $WPFCMCBDPDPG.SelectedItem
        CMDPList         = $WPFCMLBDPs.Items
        UpdateSource     = $WPFUSCBSelectCatalogSource.SelectedItem
        UpdateMIS        = $WPFMISCBCheckForUpdates.IsChecked
        AutoFillVersion  = $WPFCMCBImageVerAuto.IsChecked
        AutoFillDesc     = $WPFCMCBDescriptionAuto.IsChecked
        DefaultAppCB     = $WPFCustomCBEnableApp.IsChecked
        DefaultAppPath   = $WPFCustomTBDefaultApp.Text
        StartMenuCB      = $WPFCustomCBEnableStart.IsChecked
        StartMenuPath    = $WPFCustomTBStartMenu.Text
        RegFilesCB       = $WPFCustomCBEnableRegistry.IsChecked
        RegFilesLB       = $WPFCustomLBRegistry.Items
        SUOptional       = $WPFUpdatesCBEnableOptional.IsChecked
        SUDynamic        = $WPFUpdatesCBEnableDynamic.IsChecked

        ApplyDynamicCB   = $WPFMISCBDynamicUpdates.IsChecked
        UpdateBootCB     = $WPFMISCBBootWIM.IsChecked
        DoNotCreateWIMCB = $WPFMISCBNoWIM.IsChecked
        CreateISO        = $WPFMISCBISO.IsChecked
        ISOFileName      = $WPFMISTBISOFileName.Text
        ISOFilePath      = $WPFMISTBFilePath.Text
        UpgradePackageCB = $WPFMISCBUpgradePackage.IsChecked
        UpgradePackPath  = $WPFMISTBUpgradePackage.Text
        IncludeOptionCB  = $WPFUpdatesOptionalEnableCheckBox.IsChecked

        SourceVersion    = $WPFSourceWimTBVersionNum.text
    }

    if ($CM -eq $False) {

        Update-Log -data "Saving configuration file $filename" -Class Information

        # Ensure filename has .psd1 extension
        if ($filename -notmatch '\.psd1$') {
            $filename = [System.IO.Path]::ChangeExtension($filename, '.psd1')
        }

        try {
            # Save as PSD1 format (PowerShell Data File)
            $PSD1Lines = @('@{')
            foreach ($key in $CurrentConfig.Keys | Sort-Object) {
                $value = $CurrentConfig[$key]
                $formattedValue = if ($null -eq $value) {
                    '$null'
                } elseif ($value -is [bool]) {
                    if ($value) { '$true' } else { '$false' }
                } elseif ($value -is [int]) {
                    $value
                } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                    $items = @($value | ForEach-Object {
                        if ($_ -is [string]) {
                            "'$($_ -replace "'", "''")'"
                        } else {
                            "'$($_.ToString() -replace "'", "''")'"
                        }
                    })
                    if ($items.Count -eq 0) { '@()' } else { "@($($items -join ', '))" }
                } else {
                    "'$($value.ToString() -replace "'", "''")'"
                }
                $PSD1Lines += "    $key = $formattedValue"
            }
            $PSD1Lines += '}'
            $PSD1Content = $PSD1Lines -join "`r`n"
            Set-Content -Path "$global:workdir\Configs\$filename" -Value $PSD1Content -ErrorAction Stop
            Update-Log -data "Configuration saved as PSD1: $filename" -Class Information
        } catch {
            Update-Log -data "Couldn't save file: $($_.Exception.Message)" -Class Error
        }
    } else {
        Update-Log -data "Saving ConfigMgr Image info for Package $filename" -Class Information

        $CurrentConfig.CMPackageID = $filename
        $CurrentConfig.CMImageType = 'Update Existing Image'

        $CurrentConfig.CMImageType

        if ((Test-Path -Path $global:workdir\ConfigMgr\PackageInfo) -eq $False) {
            Update-Log -Data 'Creating ConfigMgr Package Info folder...' -Class Information

            try {
                New-Item -ItemType Directory -Path $global:workdir\ConfigMgr\PackageInfo -ErrorAction Stop
            } catch {
                Update-Log -Data "Couldn't create the folder. Likely a permission issue" -Class Error
            }
        }
        try {
            $CurrentConfig | Export-Clixml -Path $global:workdir\ConfigMgr\PackageInfo\$filename -Force -ErrorAction Stop
            Update-Log -data 'file saved' -Class Information
        } catch {
            Update-Log -data "Couldn't save file" -Class Error
        }
    }
}

#Function to import configurations from file
<#
.SYNOPSIS
    Loads configuration settings from a file and applies them to WIM customization form controls.

.DESCRIPTION
    Imports configuration settings from either PSD1 (PowerShell Data File) or XML format files and applies
    them to the corresponding WPF form controls in the WIMWitch application interface. This function detects
    the file format based on extension and uses the appropriate deserialization method. It populates all source
    WIM settings, driver paths, Autopilot configuration, language packs, features on demand, custom scripts,
    and Configuration Manager settings if present. Legacy XML format files are automatically supported for
    backward compatibility.

.PARAMETER filename
    The full path to the configuration file to load. Supports both PSD1 and XML formats.
    The file must be a valid configuration file created by Save-Configuration.

.EXAMPLE
    Get-Configuration -filename 'C:\configs\MyConfig.psd1'
    Loads the configuration from MyConfig.psd1 and applies all settings to the form controls.

.EXAMPLE
    Get-Configuration -filename 'C:\configs\LegacyConfig.xml'
    Loads the configuration from a legacy XML format file.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function sets WPF form control values directly and should only be called after the form is
    fully initialized. Legacy XML files are supported for backward compatibility with older WIMWitch versions.
    The function includes error handling for missing legacy controls.

.OUTPUTS
    None. Modifies WPF form control values directly. Updates are logged via Update-Log function.
#>
Function Get-Configuration($filename) {
    Update-Log -data "Importing config from $filename" -Class Information
    try {
        # Determine if file is PSD1 or XML format based on extension
        if ($filename -match '\.psd1$') {
            $settings = Import-PowerShellDataFile -Path $filename -ErrorAction Stop
        }
        else {
            $settings = Import-Clixml -Path $filename -ErrorAction Stop
        }
        Update-Log -data 'Config file read...' -Class Information
        $WPFSourceWIMSelectWIMTextBox.text = $settings.SourcePath
        $WPFSourceWimIndexTextBox.text = $settings.SourceIndex
        $WPFSourceWIMImgDesTextBox.text = $settings.SourceEdition
        $WPFUpdatesEnableCheckBox.IsChecked = $settings.UpdatesEnabled
        $WPFJSONEnableCheckBox.IsChecked = $settings.AutopilotEnabled
        $WPFJSONTextBox.text = $settings.AutopilotPath
        $WPFDriverCheckBox.IsChecked = $settings.DriversEnabled
        $WPFDriverDir1TextBox.text = $settings.DriverPath1
        $WPFDriverDir2TextBox.text = $settings.DriverPath2
        $WPFDriverDir3TextBox.text = $settings.DriverPath3
        $WPFDriverDir4TextBox.text = $settings.DriverPath4
        $WPFDriverDir5TextBox.text = $settings.DriverPath5
        $WPFAppxCheckBox.IsChecked = $settings.AppxIsEnabled
        $WPFAppxTextBox.text = $settings.AppxSelected -split ' '
        $WPFMISWimNameTextBox.text = $settings.WIMName
        $WPFMISWimFolderTextBox.text = $settings.WIMPath
        $WPFMISMountTextBox.text = $settings.MountPath
        $global:SelectedAppx = $settings.AppxSelected -split ' '
        $WPFMISDotNetCheckBox.IsChecked = $settings.DotNetEnabled
        $WPFMISOneDriveCheckBox.IsChecked = $settings.OneDriveEnabled
        $WPFCustomCBLangPacks.IsChecked = $settings.LPsEnabled
        $WPFCustomCBLEP.IsChecked = $settings.LXPsEnabled
        $WPFCustomCBFOD.IsChecked = $settings.FODsEnabled

        $WPFMISCBPauseMount.IsChecked = $settings.PauseAfterMount
        $WPFMISCBPauseDismount.IsChecked = $settings.PauseBeforeDM
        $WPFCustomCBRunScript.IsChecked = $settings.RunScript
        $WPFCustomCBScriptTiming.SelectedItem = $settings.ScriptTiming
        $WPFCustomTBFile.Text = $settings.ScriptFile
        $WPFCustomTBParameters.Text = $settings.ScriptParams
        $WPFCMCBImageType.SelectedItem = $settings.CMImageType
        $WPFCMTBPackageID.Text = $settings.CMPackageID
        $WPFCMTBImageName.Text = $settings.CMImageName
        $WPFCMTBImageVer.Text = $settings.CMVersion
        $WPFCMTBDescription.Text = $settings.CMDescription
        $WPFCMCBBinDirRep.IsChecked = $settings.CMBinDifRep
        $WPFCMTBSitecode.Text = $settings.CMSiteCode
        $WPFCMTBSiteServer.Text = $settings.CMSiteServer
        $WPFCMCBDPDPG.SelectedItem = $settings.CMDPGroup
        $WPFUSCBSelectCatalogSource.SelectedItem = $settings.UpdateSource
        $WPFMISCBCheckForUpdates.IsChecked = $settings.UpdateMIS

        $WPFCMCBImageVerAuto.IsChecked = $settings.AutoFillVersion
        $WPFCMCBDescriptionAuto.IsChecked = $settings.AutoFillDesc

        $WPFCustomCBEnableApp.IsChecked = $settings.DefaultAppCB
        $WPFCustomTBDefaultApp.Text = $settings.DefaultAppPath
        $WPFCustomCBEnableStart.IsChecked = $settings.StartMenuCB
        $WPFCustomTBStartMenu.Text = $settings.StartMenuPath
        $WPFCustomCBEnableRegistry.IsChecked = $settings.RegFilesCB
        # Legacy controls - skip if they don't exist
        if (Get-Variable -Name WPFUpdatesCBEnableOptional -ErrorAction SilentlyContinue) {
            $WPFUpdatesCBEnableOptional.IsChecked = $settings.SUOptional
        }
        if (Get-Variable -Name WPFUpdatesCBEnableDynamic -ErrorAction SilentlyContinue) {
            $WPFUpdatesCBEnableDynamic.IsChecked = $settings.SUDynamic
        }

        $WPFMISCBDynamicUpdates.IsChecked = $settings.ApplyDynamicCB
        $WPFMISCBBootWIM.IsChecked = $settings.UpdateBootCB
        $WPFMISCBNoWIM.IsChecked = $settings.DoNotCreateWIMCB
        $WPFMISCBISO.IsChecked = $settings.CreateISO
        $WPFMISTBISOFileName.Text = $settings.ISOFileName
        $WPFMISTBFilePath.Text = $settings.ISOFilePath
        $WPFMISCBUpgradePackage.IsChecked = $settings.UpgradePackageCB
        $WPFMISTBUpgradePackage.Text = $settings.UpgradePackPath
        $WPFUpdatesOptionalEnableCheckBox.IsChecked = $settings.IncludeOptionCB

        $WPFSourceWimTBVersionNum.text = $settings.SourceVersion

        $LEPs = $settings.LPListBox
        $LXPs = $settings.LXPListBox
        $FODs = $settings.FODListBox
        $DPs = $settings.CMDPList
        $REGs = $settings.RegFilesLB



        Update-Log -data 'Configration set' -class Information

        Update-Log -data 'Clearing list boxes...' -Class Information
        $WPFCustomLBLangPacks.Items.Clear()
        $WPFCustomLBLEP.Items.Clear()
        $WPFCustomLBFOD.Items.Clear()
        $WPFCMLBDPs.Items.Clear()
        $WPFCustomLBRegistry.Items.Clear()


        Update-Log -data 'Populating list boxes...' -class Information
        foreach ($LEP in $LEPs) { $WPFCustomLBLangPacks.Items.Add($LEP) | Out-Null }
        foreach ($LXP in $LXPs) { $WPFCustomLBLEP.Items.Add($LXP) | Out-Null }
        foreach ($FOD in $FODs) { $WPFCustomLBFOD.Items.Add($FOD) | Out-Null }
        foreach ($DP in $DPs) { $WPFCMLBDPs.Items.Add($DP) | Out-Null }
        foreach ($REG in $REGs) { $WPFCustomLBRegistry.Items.Add($REG) | Out-Null }


        Import-WimInfo -IndexNumber $WPFSourceWimIndexTextBox.text -SkipUserConfirmation

        if ($WPFJSONEnableCheckBox.IsChecked -eq $true) {

            Invoke-ParseJSON -file $WPFJSONTextBox.text
        }

        if ($WPFCMCBImageType.SelectedItem -eq 'Update Existing Image') {
            # Only attempt to get image info if SiteServer is set
            if ($global:SiteServer) {
                try {
                    Get-ImageInfo -PackID $settings.CMPackageID
                } catch {
                    Update-Log -data "Could not retrieve ConfigMgr image info: $($_.Exception.Message)" -Class Warning
                }
            }
        }

        Reset-MISCheckBox

    }

    catch {
        Update-Log -data "Could not import from $filename" -Class Error
        Update-Log -data "Error details: $($_.Exception.Message)" -Class Error
    }

    # Invoke-CheckboxCleanup removed - Windows 10 version checkboxes no longer exist
    Update-Log -data 'Config file loaded successfully' -Class Information
}

#Function to select configuration file
<#
.SYNOPSIS
    Prompts user to select a configuration XML file and loads it.

.DESCRIPTION
    Opens a file dialog to allow the user to select a previously saved WIM Witch configuration XML file.
    Updates the form textbox with the selected file path and automatically loads the configuration
    into the application, populating all form fields with saved settings.

.EXAMPLE
    Select-Config
    Opens file dialog to select config file and loads its settings into the form.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Configuration files are stored in the working directory's Configs subfolder.
    Updates: $WPFSLLoadTextBox

.OUTPUTS
    None. Updates form state with configuration file data.
#>
Function Select-Config {
    $SourceXML = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = "$global:workdir\Configs"
        Filter           = 'XML (*.XML)|'
    }
    $null = $SourceXML.ShowDialog()
    $WPFSLLoadTextBox.text = $SourceXML.FileName
    Get-Configuration -filename $WPFSLLoadTextBox.text
}

#Function to reset reminder values from check boxes on the MIS tab when loading a config
<#
.SYNOPSIS
    Refreshes and synchronizes the Mount Image Service (MIS) interface controls based on configuration checkboxes.

.DESCRIPTION
    Evaluates all enabled configuration checkboxes in the WIMWitch form and updates the corresponding Mount Image
    Service (MIS) section controls and text display values. This function enables relevant buttons and updates status
    text boxes to reflect the current configuration state. It synchronizes the MIS display with Autopilot, Drivers,
    Updates, Appx packages, custom applications, start menu customizations, and registry file settings. This ensures
    the user interface accurately reflects which customization options are currently enabled.

.EXAMPLE
    Reset-MISCheckBox
    Refreshes all MIS controls and text boxes to reflect the current configuration settings.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function should be called after any configuration checkbox is modified or after loading a saved
    configuration file via Get-Configuration. It ensures the MIS interface remains synchronized with the overall
    application state.

.OUTPUTS
    None. Updates WPF form control properties (IsEnabled) and text box values directly.
    Logs activity via Update-Log function with Information classification.
#>
Function Reset-MISCheckBox {
    Update-Log -data 'Refreshing MIS Values...' -class Information

    If ($WPFJSONEnableCheckBox.IsChecked -eq $true) {
        $WPFJSONButton.IsEnabled = $True
        $WPFMISJSONTextBox.Text = 'True'
    }
    If ($WPFDriverCheckBox.IsChecked -eq $true) {
        $WPFDriverDir1Button.IsEnabled = $True
        $WPFDriverDir2Button.IsEnabled = $True
        $WPFDriverDir3Button.IsEnabled = $True
        $WPFDriverDir4Button.IsEnabled = $True
        $WPFDriverDir5Button.IsEnabled = $True
        $WPFMISDriverTextBox.Text = 'True'
    }
    If ($WPFUpdatesEnableCheckBox.IsChecked -eq $true) {
        $WPFMISUpdatesTextBox.Text = 'True'
    }
    If ($WPFAppxCheckBox.IsChecked -eq $true) {
        $WPFAppxButton.IsEnabled = $True
        $WPFMISAppxTextBox.Text = 'True'
    }
    If ($WPFCustomCBEnableApp.IsChecked -eq $true) { $WPFCustomBDefaultApp.IsEnabled = $True }
    If ($WPFCustomCBEnableStart.IsChecked -eq $true) { $WPFCustomBStartMenu.IsEnabled = $True }
    If ($WPFCustomCBEnableRegistry.IsChecked -eq $true) {
        $WPFCustomBRegistryAdd.IsEnabled = $True
        $WPFCustomBRegistryRemove.IsEnabled = $True
    }

}

#Function to run WIM Witch from a config file
<#
.SYNOPSIS
    Executes a configuration file to automate WIM image customization.

.DESCRIPTION
    Loads and processes a configuration file (.psd1) containing preset customization options,
    then orchestrates the automated build of a Windows image based on those settings.
    This function provides unattended/scripted execution mode for WIMWitch-tNG, enabling
    batch processing and CI/CD integration. The configuration file is loaded via Get-Configuration,
    settings are applied, and the image build is initiated through Invoke-MakeItSo.
    Progress and completion are logged with decorative separators for clear output boundaries.

.PARAMETER filename
    The path to the configuration file (.psd1) to execute. This file contains all the
    customization settings including source WIM path, updates, drivers, applications,
    and output options that would normally be selected through the GUI.

.EXAMPLE
    Invoke-RunConfigFile -filename 'C:\WIMWitch\configs\Windows11-Standard.psd1'
    Loads the Windows11-Standard configuration and builds the image according to its settings.

.EXAMPLE
    Invoke-RunConfigFile 'D:\Configs\Win10-Engineering.psd1'
    Executes the Win10-Engineering configuration file for automated image creation.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is the primary entry point for automation scenarios and batch processing.
    Requires a valid configuration file created through the GUI or manually authored.
    Updates and results are logged via the Update-Log function.

.OUTPUTS
    System.String. Outputs formatted text via Write-Output indicating completion with separator lines.
    Logs all operations via Update-Log function.
#>
Function Invoke-RunConfigFile($filename) {
    Update-Log -Data "Loading the config file: $filename" -Class Information
    Get-Configuration -filename $filename
    Update-Log -Data $WWScriptVer
    Invoke-MakeItSo -appx $global:SelectedAppx
    Write-Output ' '
    Write-Output '##########################################################'
    Write-Output ' '
}

<#
.SYNOPSIS
    Displays the closing banner and exit message for WIMWitch-tNG.

.DESCRIPTION
    Displays a formatted ASCII banner thanking the user for using WIMWitch-tNG.
    This function is called when the application exits, providing a clean and professional closing message.
    The banner format includes decorative hash-mark separators matching the opening banner style for visual consistency.
    Uses Write-Host instead of Write-Output to ensure proper output during application exit sequences.

.PARAMETER
    This function does not accept parameters.

.EXAMPLE
    Show-ClosingText
    Displays the WIMWitch-tNG closing banner and thank you message.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function should be called when the application is exiting or completing execution.
    Uses Write-Host (rather than Write-Output) to ensure output is displayed correctly during application termination.

.OUTPUTS
    System.String. Outputs formatted text to the console via Write-Host for the closing banner display.
#>
function Show-ClosingText {
    #Before you start bitching about write-host, write-output doesn't work with the exiting function. Suggestions are welcome.
    Write-Host ' '
    Write-Host '##########################################################'
    Write-Host ' '
    Write-Host 'Thank you for using WIMWitch-tNG.'
    Write-Host ' '
    Write-Host '##########################################################'
}

<#
.SYNOPSIS
    Displays the opening banner and application title for WIMWitch-tNG.

.DESCRIPTION
    Clears the console screen and displays a formatted ASCII banner with the application name,
    version information, and decorative separators. This function provides visual feedback when
    the application starts, informing the user that WIMWitch-tNG is running and displaying the current version.
    The banner format includes centered text with hash-mark decorative borders.

.PARAMETER
    This function does not accept parameters. It uses the global variable $WWScriptVer for version display.

.EXAMPLE
    Show-OpeningText
    Displays the WIMWitch-tNG opening banner with current application version.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function should be called early in the application startup sequence to provide visual confirmation
    that the application has launched. Requires the global variable $WWScriptVer to be set with version information.

.OUTPUTS
    System.String. Outputs formatted text to the console via Write-Output for the opening banner display.
#>
function Show-OpeningText {
    Clear-Host
    Write-Output '##########################################################'
    Write-Output ' '
    Write-Output '             ***** Starting WIM Witch *****'
    Write-Output "                      version $WWScriptVer"
    Write-Output ' '
    Write-Output '##########################################################'
    Write-Output ' '
}

#Function to check suitability of the proposed mount point folder
<#
.SYNOPSIS
    Validates and prepares a directory path for WIM image mounting.

.DESCRIPTION
    Inspects a specified path to determine if it is suitable for mounting Windows images.
    Checks for existing mount points and orphaned files. Can optionally clean the directory
    by dismounting any mounted images or removing existing content.
    Returns detailed status information through logging.

.PARAMETER path
    The file system path to validate as a mount point destination.
    This should be an empty or cleanable directory.

.PARAMETER clean
    Optional switch to enable automatic cleanup. If $true, the function will:
    - Dismount any mounted images at the path
    - Remove existing files and subdirectories

.EXAMPLE
    Test-MountPath -path 'C:\WIM\Mount' -clean $true
    Validates the mount path and cleans it if necessary.

.EXAMPLE
    Test-MountPath -path 'D:\WorkDir\Mount'
    Validates the path without cleaning.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function logs all operations and warnings to the logging system.
    Used during WIM Witch initialization to prepare the mount directory.

.OUTPUTS
    None. Updates are communicated through the Update-Log function.
#>
Function Test-MountPath {
    param(
        [parameter(mandatory = $true, HelpMessage = 'mount path')]
        $path,

        [parameter(mandatory = $false, HelpMessage = 'clear out the crapola')]
        [ValidateSet($true)]
        $clean
    )


    $IsMountPoint = $null
    $HasFiles = $null
    $currentmounts = Get-WindowsImage -Mounted

    foreach ($currentmount in $currentmounts) {
        if ($currentmount.path -eq $path) { $IsMountPoint = $true }
    }

    if ($null -eq $IsMountPoint) {
        if ( (Get-ChildItem $path | Measure-Object).Count -gt 0) {
            $HasFiles = $true
        }
    }

    if ($HasFiles -eq $true) {
        Update-Log -Data 'Folder is not empty' -Class Warning
        if ($clean -eq $true) {
            try {
                Update-Log -Data 'Cleaning folder...' -Class Warning
                Remove-Item -Path $path\* -Recurse -Force -ErrorAction Stop
                Update-Log -Data "$path cleared" -Class Warning
            }

            catch {
                Update-Log -Data "Couldn't delete contents of $path" -Class Error
                Update-Log -Data 'Select a different folder to continue.' -Class Error
                return
            }
        }
    }

    if ($IsMountPoint -eq $true) {
        Update-Log -Data "$path is currently a mount point" -Class Warning
        if (($IsMountPoint -eq $true) -and ($clean -eq $true)) {

            try {
                Update-Log -Data 'Attempting to dismount image from mount point' -Class Warning
                Dismount-WindowsImage -Path $path -Discard | Out-Null -ErrorAction Stop
                $IsMountPoint = $null
                Update-Log -Data 'Dismounting was successful' -Class Warning
            }

            catch {
                Update-Log -Data "Couldn't completely dismount the folder. Ensure" -Class Error
                Update-Log -data 'all connections to the path are closed, then try again' -Class Error
                return
            }
        }
    }
    if (($null -eq $IsMountPoint) -and ($null -eq $HasFiles)) {
        Update-Log -Data "$path is suitable for mounting" -Class Information
    }
}

#Function to check the name of the target file and remediate if necessary
<#
.SYNOPSIS
    Validates and processes the target WIM file name for uniqueness and proper extension.

.DESCRIPTION
    Ensures the target WIM file name has a .wim extension and checks for naming conflicts
    in the destination folder. Handles conflicts according to the specified conflict resolution
    strategy by appending extension, overwriting, backing up existing files, or stopping.
    Updates the form textbox with the corrected filename if extension is missing.

.PARAMETER conflict
    Specifies the action to take if a file with the same name already exists.
    Valid values:
    - 'stop': Halts operation and logs a warning (default)
    - 'append': Renames existing file with timestamp and continues
    - 'backup': Creates backup of existing file
    - 'overwrite': Replaces existing file

.EXAMPLE
    Test-Name
    Validates WIM name with default 'stop' conflict resolution.

.EXAMPLE
    Test-Name -conflict 'append'
    Validates WIM name and renames existing file if conflict exists.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: $WPFMISWimNameTextBox, $WPFMISWimFolderTextBox form variables
    This function automatically appends .wim extension if missing.

.OUTPUTS
    System.String
    Returns 'stop' if validation fails or conflict cannot be resolved.
    Returns nothing if validation succeeds.
#>
Function Test-Name {
    Param(
        [parameter(mandatory = $false, HelpMessage = 'what to do')]
        [ValidateSet('stop', 'append', 'backup', 'overwrite')]
        $conflict = 'stop'
    )

    If ($WPFMISWimNameTextBox.Text -like '*.wim') {
        #$WPFLogging.Focus()
        #Update-Log -Data "New WIM name is valid" -Class Information
    }

    If ($WPFMISWimNameTextBox.Text -notlike '*.wim') {

        $WPFMISWimNameTextBox.Text = $WPFMISWimNameTextBox.Text + '.wim'
        Update-Log -Data 'Appending new file name with an extension' -Class Information
    }

    $WIMpath = $WPFMISWimFolderTextBox.text + '\' + $WPFMISWimNameTextBox.Text
    $FileCheck = Test-Path -Path $WIMpath


    #append,overwrite,stop

    if ($FileCheck -eq $false) { Update-Log -data 'Target WIM file name not in use. Continuing...' -class Information }
    else {
        if ($conflict -eq 'append') {
            $renamestatus = (Rename-Name -file $WIMpath -extension '.wim')
            if ($renamestatus -eq 'stop') { return 'stop' }
        }
        if ($conflict -eq 'overwrite') {
            Write-Host 'overwrite action'
            return
        }
        if ($conflict -eq 'stop') {
            $string = $WPFMISWimNameTextBox.Text + ' already exists. Rename the target WIM and try again'
            Update-Log -Data $string -Class Warning
            return 'stop'
        }
    }
    Update-Log -Data 'New WIM name is valid' -Class Information
}

<#
.SYNOPSIS
    Renames an existing file by appending a timestamp to avoid naming conflicts.

.DESCRIPTION
    Creates a unique filename by appending the file's last write time as a timestamp
    to the original filename before the extension. This prevents overwriting existing
    files and preserves historical versions. Handles errors gracefully and logs all operations.
    Timestamp format: YYYY_MM_DD_HH_MM_SS

.PARAMETER file
    The full path to the file to be renamed.

.PARAMETER extension
    The file extension (including the dot) to preserve in the new filename.
    Example: '.wim', '.iso'

.EXAMPLE
    Rename-Name -file "C:\Images\install.wim" -extension ".wim"
    Renames install.wim to install2026_01_19_14_30_45.wim

.EXAMPLE
    Rename-Name "C:\Output\custom.iso" ".iso"
    Renames custom.iso to custom2026_01_19_14_30_45.iso

.NOTES
    Author: Eden Nelson
    Version: 1.0
    The timestamp is based on the file's LastWriteTime property.
    Special characters in timestamp are replaced with underscores for filesystem compatibility.

.OUTPUTS
    System.String
    Returns 'stop' if rename operation fails.
    Returns nothing if rename succeeds.
#>
Function Rename-Name($file, $extension) {
    $text = 'Renaming existing ' + $extension + ' file...'
    Update-Log -Data $text -Class Warning
    $filename = (Split-Path -Leaf $file)
    $dateinfo = (Get-Item -Path $file).LastWriteTime -replace (' ', '_') -replace ('/', '_') -replace (':', '_')
    $filename = $filename -replace ($extension, '')
    $filename = $filename + $dateinfo + $extension
    try {
        Rename-Item -Path $file -NewName $filename -ErrorAction Stop
        $text = $file + ' has been renamed to ' + $filename
        Update-Log -Data $text -Class Warning
    } catch {
        Update-Log -data "Couldn't rename file. Stopping..." -force -Class Error
        return 'stop'
    }
}

#Function to see if the folder WIM Witch was started in is an installation folder. If not, prompt for installation
<#
.SYNOPSIS
    Creates and validates the required WIM Witch working directory structure.

.DESCRIPTION
    Verifies that the working directory contains all necessary subdirectories for WIM Witch operations.
    If any required folders are missing, automatically creates them. This ensures a consistent
    and complete directory structure for staging, logging, mounting, and output operations.
    Essential as a preflight check before main application operations begin.

.EXAMPLE
    Test-WorkingDirectory
    Validates working directory structure and creates missing folders as needed.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Required folders: CompletedWIMs, Configs, drivers, jobs, logging, Mount, Staging,
    updates, imports, imports\WIM, imports\DotNet, Autopilot, backup
    This function should be called during application initialization.
    Output is written to the console, not to the logging system.

.OUTPUTS
    None. Console output indicates folder validation and creation status.
#>
Function Test-WorkingDirectory {

    $subfolders = @(
        'CompletedWIMs'
        'Configs'
        'drivers'
        'jobs'
        'logging'
        'Mount'
        'Staging'
        'updates'
        'imports'
        'imports\WIM'
        'imports\DotNet'
        'Autopilot'
        'backup'
    )

    $count = $null
    Set-Location -Path $global:workdir
    Write-Output "WIMWitch-tNG working directory selected: $global:workdir"
    Write-Output 'Checking working directory for required folders...'
    foreach ($subfolder in $subfolders) {
        if ((Test-Path -Path .\$subfolder) -eq $true) { $count = $count + 1 }
    }

    if ($null -eq $count) {
        Write-Output 'Creating missing folders...'
        foreach ($subfolder in $subfolders) {
            if ((Test-Path -Path "$subfolder") -eq $false) {
                New-Item -Path $subfolder -ItemType Directory | Out-Null
                Write-Output "Created folder: $subfolder"
            }
        }
    }
    if ($null -ne $count) {
        Write-Output 'Creating missing folders...'
        foreach ($subfolder in $subfolders) {
            if ((Test-Path -Path "$subfolder") -eq $false) {
                New-Item -Path $subfolder -ItemType Directory | Out-Null
                Write-Output "Created folder: $subfolder"
            }
        }
        Write-Output 'Preflight complete. Starting WIM Witch'
    }

}

<#
.SYNOPSIS
    Prompts user to select the working directory for WIM Witch operations.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a root working directory.
    This directory will be used to store all WIM Witch temporary files, staging areas, and output.
    Exits the script if user cancels the dialog or provides an invalid selection.

.EXAMPLE
    $workdir = Select-WorkingDirectory
    Opens folder dialog and returns selected working directory path.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    User cancellation results in script termination.
    The selected directory should be empty or on a large partition with sufficient free space.

.OUTPUTS
    String
    Returns the full path of the selected working directory.
#>
Function Select-WorkingDirectory {
    $selectWorkingDirectory = New-Object System.Windows.Forms.FolderBrowserDialog
    $selectWorkingDirectory.Description = 'Select the working directory.'
    $null = $selectWorkingDirectory.ShowDialog()

    if ($selectWorkingDirectory.SelectedPath -eq '') {
        Write-Output 'User Cancelled or invalid entry'
        exit 0
    }

    return $selectWorkingDirectory.SelectedPath
}

<#
.SYNOPSIS
    Inspects and repairs issues with the WIM mount point directory.

.DESCRIPTION
    Diagnoses and resolves problems with the mount directory used for WIM image operations.
    Checks for:
    - Mounted images that need to be dismounted
    - Orphaned files and folders from previous operations
    - Missing mount directory (creates if needed)

    When AutoFix is disabled, prompts user for repair options. When enabled, automatically
    dismounts images and removes orphaned content without user intervention.

.PARAMETER AutoFix
    Boolean switch to enable automatic repair without user prompts.
    Default is $false, which requires user interaction for decisions.

.EXAMPLE
    Repair-MountPoint -AutoFix $true
    Automatically repairs all mount point issues.

.EXAMPLE
    Repair-MountPoint
    Interactively prompts user for repair actions.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Mount point location: $global:workdir\Mount
    User options (when AutoFix is $false):
    1) Dismount mounted images
    2) Purge mount directory completely
    3) Continue without repairs
    All operations are logged via Update-Log.

.OUTPUTS
    None. Operations and status are communicated through logging system.
#>
Function Repair-MountPoint {
    param(
        [bool]$AutoFix = $false
    )

    $MountPath = Join-Path -Path $global:workdir -ChildPath 'Mount'

    Update-Log -Data "Checking mount point: $MountPath" -Class Information

    # Check if mount path exists
    if (-not (Test-Path $MountPath)) {
        Update-Log -Data "Mount path does not exist. Creating directory." -Class Information
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
        return
    }

    # Check if anything is mounted
    $MountedImages = Get-WindowsImage -Mounted 2>$null | Where-Object { $_.ImagePath -like "*$MountPath*" }

    if ($MountedImages) {
        Update-Log -Data "Found mounted images at $MountPath" -Class Warning

        if ($AutoFix) {
            Update-Log -Data "AutoFix enabled - dismounting images..." -Class Information
            foreach ($image in $MountedImages) {
                try {
                    Dismount-WindowsImage -Path $image.Path -Discard | Out-Null
                    Update-Log -Data "Dismounted: $($image.Path)" -Class Information
                } catch {
                    Update-Log -Data "Failed to dismount $($image.Path): $($_.Exception.Message)" -Class Error
                }
            }
        } else {
            Write-Host "Mounted images found in $MountPath" -ForegroundColor Yellow
            Write-Host "Options:"
            Write-Host "  1) Dismount all images"
            Write-Host "  2) Purge mount directory (force)"
            Write-Host "  3) Continue anyway"

            $choice = Read-Host "Select option (1-3)"

            switch ($choice) {
                '1' {
                    foreach ($image in $MountedImages) {
                        try {
                            Dismount-WindowsImage -Path $image.Path -Discard | Out-Null
                            Update-Log -Data "Dismounted: $($image.Path)" -Class Information
                        } catch {
                            Update-Log -Data "Failed to dismount: $($_.Exception.Message)" -Class Error
                        }
                    }
                }
                '2' {
                    try {
                        Remove-Item -Path $MountPath -Recurse -Force
                        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
                        Update-Log -Data "Mount directory purged and recreated" -Class Information
                    } catch {
                        Update-Log -Data "Failed to purge mount directory: $($_.Exception.Message)" -Class Error
                    }
                }
                '3' {
                    Update-Log -Data "User chose to continue with mounted images" -Class Warning
                }
            }
        }
    }

    # Check for orphaned content
    $MountContent = Get-ChildItem -Path $MountPath -ErrorAction SilentlyContinue | Measure-Object

    if ($MountContent.Count -gt 0) {
        Update-Log -Data "Mount directory contains $($MountContent.Count) items" -Class Warning

        if ($AutoFix) {
            Update-Log -Data "AutoFix enabled - purging mount directory..." -Class Information
            try {
                Remove-Item -Path $MountPath\* -Recurse -Force -ErrorAction Stop
                Update-Log -Data "Mount directory purged" -Class Information
            } catch {
                Update-Log -Data "Failed to purge mount directory: $($_.Exception.Message)" -Class Error
            }
        } else {
            Write-Host "Mount directory contains orphaned content" -ForegroundColor Yellow
            $purge = Read-Host "Purge mount directory? (Y/N)"

            if ($purge -eq 'Y' -or $purge -eq 'y') {
                try {
                    Remove-Item -Path $MountPath\* -Recurse -Force -ErrorAction Stop
                    Update-Log -Data "Mount directory purged" -Class Information
                } catch {
                    Update-Log -Data "Failed to purge: $($_.Exception.Message)" -Class Error
                }
            }
        }
    }

    Update-Log -Data "Mount point check complete" -Class Information
}

<#
.SYNOPSIS
    Converts a Windows build number to its marketing version name.

.DESCRIPTION
    Translates Windows OS build numbers into their corresponding marketing version names
    (e.g., 22H2, 23H2, 24H2). Supports Windows 10 22H2, Windows 11 versions, and Windows Server.
    Identifies unsupported legacy Windows 10 builds and logs appropriate warnings or errors.
    Returns 'Unknown' for unrecognized build numbers and 'Unsupported' for deprecated versions.

.PARAMETER wimversion
    The full Windows build version string to parse.
    Format: Major.Minor.Build.Revision (e.g., '10.0.22631.1234')

.EXAMPLE
    Set-Version -wimversion '10.0.22631.1234'
    Returns: '23H2' (Windows 11 23H2)

.EXAMPLE
    Set-Version '10.0.19045.3570'
    Returns: '22H2' (Windows 10 22H2)

.EXAMPLE
    Set-Version '10.0.17763.1234'
    Returns: 'Unsupported' and logs error for Windows 10 1809

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Only Windows 10 22H2 (build 1904*) is supported for Windows 10.
    Windows 11 versions: 23H2 (22631), 24H2 (26100), 25H2 (26200)
    Windows Server 2022: 21H2 (20348)

.OUTPUTS
    System.String
    Returns the marketing version name or status:
    - '22H2', '23H2', '24H2', '25H2', '21H2' for supported versions
    - 'Unsupported' for deprecated Windows 10 builds
    - 'Unknown' for unrecognized build numbers
#>
Function Set-Version($wimversion) {
    # Windows 11 versions
    if ($wimversion -like '10.0.22631.*') { $version = '23H2' }
    elseif ($wimversion -like '10.0.26100.*') { $version = '24H2' }
    elseif ($wimversion -like '10.0.26200.*') { $version = '25H2' }

    # Windows 10 - Only 22H2 supported (all 1904*.* builds)
    elseif ($wimversion -like '10.0.1904*.*') {
        $version = '22H2'
        Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimversion. Note: Only Windows 10 22H2 is supported. ISO build numbers are inconsistent, assuming 22H2." -Class Information
    }

    # Unsupported Windows 10 builds
    elseif ($wimversion -like '10.0.16299.*') {
        Update-Log -Data "Unsupported Windows 10 build 1709 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17134.*') {
        Update-Log -Data "Unsupported Windows 10 build 1803 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17763.*') {
        Update-Log -Data "Unsupported Windows 10 build 1809 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.18362.*') {
        Update-Log -Data "Unsupported Windows 10 build 1909 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.14393.*') {
        Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.20348.*') { $version = '21H2' }
    else {
        Update-Log -Data "Unknown Windows version: $wimversion" -Class Warning
        $version = 'Unknown'
    }
    return $version
}


<#
.SYNOPSIS
    Imports Windows installation media content from an ISO file into the WIM Witch import structure.

.DESCRIPTION
    Mounts a Windows installation ISO and extracts WIM/ESD files, .NET binaries, and ISO media binaries
    to their respective import folders. Handles conversion of ESD format to WIM format, validates Windows
    versions, and organizes imported content by OS type and version number. Creates appropriate directory
    structures for Windows 10, Windows 11, and Windows Server editions.

.PARAMETER
    This function uses global form variables:
    - $WPFImportISOTextBox: Path to the ISO file to import
    - $WPFImportNewNameTextBox: New name for the imported WIM file
    - $WPFImportWIMCheckBox: Flag to import WIM/ESD content
    - $WPFImportDotNetCheckBox: Flag to import .NET 3.5 binaries
    - $WPFImportISOCheckBox: Flag to import ISO media binaries

.EXAMPLE
    Import-ISO
    Imports all selected content (WIM, .NET, ISO binaries) from the ISO file selected in the form.

.EXAMPLE
    Import-ISO
    With only $WPFImportWIMCheckBox checked, imports only the install.wim file.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    The function mounts ISO without a drive letter for safer handling.
    Supports both WIM and ESD format source files with automatic conversion.
    Validates Windows versions and rejects unsupported builds.
    Requires administrative privileges.

.OUTPUTS
    None. Updates are logged via Update-Log function.
    Creates/updates files in: $global:workdir\Imports\WIM, DotNet, and iso subdirectories.
#>
Function Import-ISO {
    $newname = $WPFImportNewNameTextBox.Text
    $file = $WPFImportISOTextBox.Text

    #Check to see if destination WIM already exists

    if ($WPFImportWIMCheckBox.IsChecked -eq $true) {
        Update-Log -data 'Checking to see if the destination WIM file exists...' -Class Information
        #check to see if the new name for the imported WIM is valid
        if (($WPFImportNewNameTextBox.Text -eq '') -or ($WPFImportNewNameTextBox.Text -eq 'Name for the imported WIM')) {
            Update-Log -Data 'Enter a valid file name for the imported WIM and then try again' -Class Error
            return
        }

        If ($newname -notlike '*.wim') {
            $newname = $newname + '.wim'
            Update-Log -Data 'Appending new file name with an extension' -Class Information
        }

        if ((Test-Path -Path $global:workdir\Imports\WIM\$newname) -eq $true) {
            Update-Log -Data 'Destination WIM name already exists. Provide a new name and try again.' -Class Error
            return
        } else {
            Update-Log -Data 'Name appears to be good. Continuing...' -Class Information
        }
    }

    #Mount ISO
    Update-Log -Data 'Mounting ISO...' -Class Information
    try {
        $isomount = Mount-DiskImage -ImagePath $file -PassThru -NoDriveLetter -ErrorAction Stop
        $iso = $isomount.devicepath

    } catch {
        Update-Log -Data 'Could not mount the ISO! Stopping actions...' -Class Error
        return
    }
    if (-not(Test-Path -Path (Join-Path $iso '\sources\'))) {
        Update-Log -Data 'Could not access the mounted ISO! Stopping actions...' -Class Error
        try {
            Invoke-RemoveISOMount -inputObject $isomount
        } catch {
            Update-Log -Data 'Attempted to dismount iso - might have failed...' -Class Warning
        }
        return
    }
    Update-Log -Data "$isomount" -Class Information
    #Testing for ESD or WIM format
    if (Test-Path -Path (Join-Path $iso '\sources\install.wim')) {
        $installWimFound = $true
    } elseif (Test-Path -Path (Join-Path $iso '\sources\install.esd')) {
        $installEsdFound = $true
        Update-Log -data 'Found ESD type installer - attempting to convert to WIM.' -Class Information
    } else {
        Update-Log -data 'Error accessing install.wim or install.esd! Breaking' -Class Warning
        try {
            Invoke-RemoveISOMount -inputObject $isomount
        } catch {
            Update-Log -Data 'Attempted to dismount iso - might have failed...' -Class Warning
        }
        return
    }

    try {
        if ($installWimFound) {
            $windowsver = Get-WindowsImage -ImagePath (Join-Path $iso '\sources\install.wim') -Index 1 -ErrorAction Stop
        } elseif ($installEsdFound) {
            $windowsver = Get-WindowsImage -ImagePath (Join-Path $iso '\sources\install.esd') -Index 1 -ErrorAction Stop
        }


        #####################
        $version = Set-Version -wimversion $windowsver.Version

        # Abort if unsupported Windows version detected
        if ($version -eq 'Unsupported') {
            Update-Log -Data "Cannot import unsupported Windows 10 build. Only Windows 10 22H2 is supported." -Class Error
            Write-Output 'Import cancelled - unsupported Windows version'
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

    } catch {
        Update-Log -data 'install.wim could not be found or accessed! Skipping...' -Class Warning
        $installWimFound = $false
    }


    #Copy out WIM file
    #if (($type -eq "all") -or ($type -eq "wim")) {
    if (($WPFImportWIMCheckBox.IsChecked -eq $true) -and (($installWimFound) -or ($installEsdFound))) {

        #Copy out the WIM file from the selected ISO
        try {
            Update-Log -data 'Purging staging folder...' -Class Information
            Remove-Item -Path $global:workdir\staging\*.* -Force
            Update-Log -data 'Purge complete.' -Class Information
            if ($installWimFound) {
                Update-Log -Data 'Copying WIM file to the staging folder...' -Class Information
                Copy-Item -Path $iso\sources\install.wim -Destination $global:workdir\staging -Force -ErrorAction Stop -PassThru
            }
        } catch {
            Update-Log -data "Couldn't copy from the source" -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

        #convert the ESD file to WIM
        if ($installEsdFound) {
            $sourceEsdFile = (Join-Path $iso '\sources\install.esd')
            Update-Log -Data 'Assessing install.esd file...' -Class Information
            $indexesFound = Get-WindowsImage -ImagePath $sourceEsdFile
            Update-Log -Data "$($indexesFound.Count) indexes found for conversion..." -Class Information
            foreach ($index in $indexesFound) {
                try {
                    Update-Log -Data "Converting index $($index.ImageIndex) - $($index.ImageName)" -Class Information
                    Export-WindowsImage -SourceImagePath $sourceEsdFile -SourceIndex $($index.ImageIndex) -DestinationImagePath (Join-Path $global:workdir '\staging\install.wim') -CompressionType fast -ErrorAction Stop
                } catch {
                    Update-Log -Data "Converting index $($index.ImageIndex) failed - skipping..." -Class Error
                    continue
                }
            }
        }

        #Change file attribute to normal
        Update-Log -Data 'Setting file attribute of install.wim to Normal' -Class Information
        $attrib = Get-Item $global:workdir\staging\install.wim
        $attrib.Attributes = 'Normal'

        #Rename install.wim to the new name
        try {
            $text = 'Renaming install.wim to ' + $newname
            Update-Log -Data $text -Class Information
            Rename-Item -Path $global:workdir\Staging\install.wim -NewName $newname -ErrorAction Stop
        } catch {
            Update-Log -data "Couldn't rename the copied file. Most likely a weird permissions issues." -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

        #Move the imported WIM to the imports folder

        try {
            Update-Log -data "Moving $newname to imports folder..." -Class Information
            Move-Item -Path $global:workdir\Staging\$newname -Destination $global:workdir\Imports\WIM -ErrorAction Stop
        } catch {
            Update-Log -Data "Couldn't move the new WIM to the staging folder." -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }
        Update-Log -data 'WIM importation complete' -Class Information
    }

    #Copy DotNet binaries

    if ($WPFImportDotNetCheckBox.IsChecked -eq $true) {


        If (($windowsver.imagename -like '*Windows 10*') -or (($windowsver.imagename -like '*server') -and ($windowsver.version -lt 10.0.20248.0))) { $Path = "$global:workdir\Imports\DotNet\$version" }
        If (($windowsver.Imagename -like '*server*') -and ($windowsver.version -gt 10.0.20348.0)) { $Path = "$global:workdir\Imports\Dotnet\Windows Server\$version" }
        If ($windowsver.imagename -like '*Windows 11*') { $Path = "$global:workdir\Imports\Dotnet\Windows 11\$version" }


        if ((Test-Path -Path $Path) -eq $false) {

            try {
                Update-Log -Data 'Creating folders...' -Class Warning

                New-Item -Path (Split-Path -Path $path -Parent) -Name $version -ItemType Directory -ErrorAction stop | Out-Null

            } catch {
                Update-Log -Data "Couldn't creating new folder in DotNet imports folder" -Class Error
                return
            }
        }


        try {
            Update-Log -Data 'Copying .Net binaries...' -Class Information
            Copy-Item -Path $iso\sources\sxs\*netfx3* -Destination $path -Force -ErrorAction Stop

        } catch {
            Update-Log -Data "Couldn't copy the .Net binaries" -Class Error
            return
        }
    }

    #Copy out ISO files
    if ($WPFImportISOCheckBox.IsChecked -eq $true) {
        #Determine if is Windows 10 or Windows Server
        Update-Log -Data 'Importing ISO/Upgrade Package files...' -Class Information

        if ($windowsver.ImageName -like 'Windows 10*') { $OS = 'Windows 10' }

        if ($windowsver.ImageName -like 'Windows 11*') { $OS = 'Windows 11' }

        if ($windowsver.ImageName -like '*Server*') { $OS = 'Windows Server' }
        Update-Log -Data "$OS detected" -Class Information
        if ((Test-Path -Path $global:workdir\imports\iso\$OS\$Version) -eq $false) {
            Update-Log -Data 'Path does not exist. Creating...' -Class Information
            New-Item -Path $global:workdir\imports\iso\$OS\ -Name $version -ItemType Directory
        }

        Update-Log -Data 'Copying boot folder...' -Class Information
        Copy-Item -Path $iso\boot\ -Destination $global:workdir\imports\iso\$OS\$Version\boot -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying efi folder...' -Class Information
        Copy-Item -Path $iso\efi\ -Destination $global:workdir\imports\iso\$OS\$Version\efi -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying sources folder...' -Class Information
        Copy-Item -Path $iso\sources\ -Destination $global:workdir\imports\iso\$OS\$Version\sources -Recurse -Force -Exclude install.wim

        Update-Log -Data 'Copying support folder...' -Class Information
        Copy-Item -Path $iso\support\ -Destination $global:workdir\imports\iso\$OS\$Version\support -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying files in root folder...' -Class Information
        Copy-Item $iso\autorun.inf -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\bootmgr -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\bootmgr.efi -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\setup.exe -Destination $global:workdir\imports\iso\$OS\$Version\ -Force

    }

    #Dismount and finish
    try {
        Update-Log -Data 'Dismount!' -Class Information
        Invoke-RemoveISOMount -inputObject $isomount
    } catch {
        Update-Log -Data "Couldn't dismount the ISO. WIM Witch uses a file mount option that does not" -Class Error
        Update-Log -Data 'provision a drive letter. Use the Dismount-DiskImage command to manaully dismount.' -Class Error
    }
    Update-Log -data 'Importing complete' -class Information
}

#Function to select ISO for import
<#
.SYNOPSIS
    Prompts user to select an ISO file to import content from.

.DESCRIPTION
    Opens a file dialog to allow the user to select a Windows installation ISO file.
    Updates the form textbox with the selected ISO file path and validates that a proper
    ISO file was selected before logging the selection. Initializes with the Desktop folder.

.PARAMETER
    This function uses global form variables:
    - $WPFImportISOTextBox: Textbox to populate with the selected ISO file path

.EXAMPLE
    Select-ISO
    Opens file dialog to select Windows installation ISO file, updates form textbox.

.EXAMPLE
    Select-ISO
    User selects file, function validates .iso extension and logs the selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Initial directory defaults to Desktop
    Validates .iso file extension before accepting selection
    Logs warnings if non-ISO file is selected

.OUTPUTS
    None. Updates form variable $WPFImportISOTextBox with selected file path.
#>
Function Select-ISO {

    $SourceISO = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'ISO (*.iso)|'
    }
    $null = $SourceISO.ShowDialog()
    $WPFImportISOTextBox.text = $SourceISO.FileName


    if ($SourceISO.FileName -notlike '*.iso') {
        Update-Log -Data 'An ISO file not selected. Please select a valid file to continue.' -Class Warning
        return
    }
    $text = $WPFImportISOTextBox.text + ' selected as the ISO to import from'
    Update-Log -Data $text -class Information

}

#Function to inject the .Net 3.5 binaries from the import folder
<#
.SYNOPSIS
    Injects .NET 3.5 binaries into a mounted Windows image.

.DESCRIPTION
    This function injects .NET 3.5 framework binaries into a mounted Windows image using Add-WindowsPackage.
    It automatically detects the Windows version and architecture to determine the correct source path for
    the .NET binaries. For Windows 10, it uses the build number. For Windows 11 and Windows Server, it uses
    the OS type along with the build number. The source files must be located in the imports folder structure.

.PARAMETER None
    This function uses global variables for configuration:
    - $global:workdir: The working directory containing imports and mount points
    - $WPFMISMountTextBox.Text: The path to the mounted Windows image

.EXAMPLE
    Add-DotNet
    Injects the appropriate .NET 3.5 binaries for the current Windows version into the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Mounted Windows image and .NET binaries in the proper directory structure.
    The function logs all operations and errors via Update-Log.

.OUTPUTS
    None. Logs injection status via Update-Log function.
#>
Function Add-DotNet {

    $buildnum = Get-WinVersionNumber
    $OSType = Get-WindowsType

    #fix the build number 21h

    if ($OSType -eq 'Windows 10') { $DotNetFiles = "$global:workdir\imports\DotNet\$buildnum" }
    if (($OSType -eq 'Windows 11') -or ($OSType -eq 'Windows Server')) { $DotNetFiles = "$global:workdir\imports\DotNet\$OSType\$buildnum" }


    try {
        $text = 'Injecting .Net 3.5 binaries from ' + $DotNetFiles
        Update-Log -Data $text -Class Information
        Add-WindowsPackage -PackagePath $DotNetFiles -Path $WPFMISMountTextBox.Text -ErrorAction Continue | Out-Null
    } catch {
        Update-Log -Data "Couldn't inject .Net Binaries" -Class Warning
        Update-Log -data $_.Exception.Message -Class Error
        return
    }
    Update-Log -Data '.Net 3.5 injection complete' -Class Information
}

<#
.SYNOPSIS
    Verifies that .NET 3.5 binaries exist for the selected Windows version.

.DESCRIPTION
    Tests whether the required .NET 3.5 binaries are present in the imports directory for the
    currently selected Windows version and build number. This function validates the availability
    of .NET files before attempting injection. It handles the special case of Windows 10 20H2
    build which is identified as 2009. For Windows 11 and Windows Server, it includes the OS
    type in the path structure.

.PARAMETER None
    This function uses global variables for configuration:
    - $global:workdir: The working directory containing the DotNet imports folder
    - $WPFSourceWimTBVersionNum.text: The version/build number of the Windows image

.EXAMPLE
    Test-DotNetExists
    Checks if .NET 3.5 binaries are available for the selected Windows version.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Add-DotNet function for injection operations.
    Windows 10 20H2 uses special build number mapping (20H2 -> 2009).

.OUTPUTS
    System.Boolean. Returns $false if binaries are not found, otherwise returns the result of Test-Path.
#>
Function Test-DotNetExists {

    $OSType = Get-WindowsType
    #$buildnum = Get-WinVersionNumber
    $buildnum = $WPFSourceWimTBVersionNum.text

    if ($OSType -eq 'Windows 10') {
        if ($buildnum -eq '20H2') { $Buildnum = '2009' }
        $DotNetFiles = "$global:workdir\imports\DotNet\$buildnum"
    }
    if (($OSType -eq 'Windows 11') -or ($OSType -eq 'Windows Server')) { $DotNetFiles = "$global:workdir\imports\DotNet\$OSType\$buildnum" }


    Test-Path -Path $DotNetFiles\*
    if ((Test-Path -Path $DotNetFiles\*) -eq $false) {
        $text = '.Net 3.5 Binaries are not present for ' + $buildnum
        Update-Log -Data $text -Class Warning
        Update-Log -data 'Import .Net from an ISO or disable injection to continue' -Class Warning
        return $false
    }
}

#For those who like to dig through code and find notes from the dev team:
#Each Function is listed in the order it was created. This point marks
#where v1.0 was released. Everything
#below is from updates -DRR 10/22/2020

<#
.SYNOPSIS
    Prompts the user to upgrade WIM Witch to the latest version from PowerShell Gallery.

.DESCRIPTION
    Interactively prompts the user to upgrade WIM Witch by downloading the latest version from
    the PowerShell Gallery. If the user confirms, creates a backup of the current version using
    Backup-WIMWitch, downloads the new version using Save-Script, and exits the application to
    allow the user to restart with the updated version. If the upgrade fails, returns control
    without exiting. If the user declines, logs the decision and continues normal operation.
    The function validates user input and recursively re-prompts on invalid entries.

.PARAMETER None
    This function uses global variables:
    - $global:workdir: The working directory where the upgraded script will be saved

.EXAMPLE
    Install-WimWitchUpgrade
    Prompts the user to upgrade WIM Witch and handles the upgrade process interactively.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Internet connectivity to download from PowerShell Gallery.
    The function exits the application after successful upgrade to ensure clean restart.
    User must manually restart WIM Witch after upgrade.

.OUTPUTS
    None. Logs update status via Update-Log function and exits application on successful upgrade.
#>
Function Install-WimWitchUpgrade {
    Write-Output 'Would you like to upgrade WIM Witch?'
    $yesno = Read-Host -Prompt '(Y/N)'
    Write-Output $yesno
    if (($yesno -ne 'Y') -and ($yesno -ne 'N')) {
        Write-Output 'Invalid entry, try again.'
        Install-WimWitchUpgrade
    }

    if ($yesno -eq 'y') {
        Backup-WIMWitch

        try {
            Save-Script -Name 'WIMWitch' -Path $global:workdir -Force -ErrorAction Stop
            Write-Output 'New version has been applied. WIM Witch will now exit.'
            Write-Output 'Please restart WIM Witch'
            exit
        } catch {
            Write-Output "Couldn't upgrade. Try again when teh tubes are clear"
            return
        }

    }


    if ($yesno -eq 'n') {
        Write-Output "You'll want to upgrade at some point."
        Update-Log -Data 'Upgrade to new version was declined' -Class Warning
        Update-Log -Data 'Continuing to start WIM Witch...' -Class Warning
    }

}

<#
.SYNOPSIS
    Creates a backup of the current WIM Witch script file before performing an upgrade.

.DESCRIPTION
    Backs up the currently running WIM Witch script file to the backup subdirectory within the
    working directory. Identifies the current script using $MyInvocation.PSCommandPath, copies it
    to the backup folder, and attempts to rename it with a timestamp for archiving purposes using
    the Rename-Name function. If the copy operation fails (typically due to permissions issues),
    logs an error and exits to prevent potential data loss. If the rename operation fails, logs
    a warning but continues with the upgrade process since this is not considered critical.
    This function ensures a recovery path exists before applying upgrades.

.PARAMETER None
    This function uses global variables:
    - $global:workdir: The working directory containing the backup subdirectory
    Uses automatic variables:
    - $MyInvocation.PSCommandPath: Full path to the currently executing script

.EXAMPLE
    Backup-WIMWitch
    Creates a backup of the current WIM Witch script in the backup folder.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Write permissions to the backup directory.
    Exits the script if backup copy fails to prevent upgrade without recovery option.
    Called automatically by Install-WimWitchUpgrade before downloading new version.

.OUTPUTS
    None. Creates backup file and logs operations via Update-Log function.
    May exit script if critical backup operation fails.
#>
Function Backup-WIMWitch {
    Update-log -data 'Backing up existing WIM Witch script...' -Class Information

    $scriptname = Split-Path $MyInvocation.PSCommandPath -Leaf #Find local script name
    Update-Log -data 'The script to be backed up is: ' -Class Information
    Update-Log -data $MyInvocation.PSCommandPath -Class Information

    try {
        Update-Log -data 'Copy script to backup folder...' -Class Information
        Copy-Item -Path $scriptname -Destination $global:workdir\backup -ErrorAction Stop
        Update-Log -Data 'Successfully copied...' -Class Information
    } catch {
        Update-Log -data "Couldn't copy the WIM Witch script. My guess is a permissions issue" -Class Error
        Update-Log -Data 'Exiting out of an over abundance of caution' -Class Error
        exit
    }

    try {
        Update-Log -data 'Renaming archived script...' -Class Information
        Rename-Name -file $global:workdir\backup\$scriptname -extension '.ps1'
        Update-Log -data 'Backup successfully renamed for archiving' -class Information
    } catch {

        Update-Log -Data "Backed-up script couldn't be renamed. This isn't a critical error" -Class Warning
        Update-Log -Data "You may want to change it's name so it doesn't get overwritten." -Class Warning
        Update-Log -Data 'Continuing with WIM Witch upgrade...' -Class Warning
    }
}

<#
.SYNOPSIS
    Downloads the latest OneDrive client installer(s) for the target Windows version and architecture.

.DESCRIPTION
    Downloads the current OneDrive setup executable(s) from Microsoft's official download links based on
    the Windows version and architecture being serviced. For Windows 10 x64, it downloads both x86 and x64
    installers. For Windows 11 x64, it downloads only the x64 installer. For Windows 11 ARM64, it downloads
    the ARM64 installer. Files are saved to the updates\OneDrive directory structure with architecture-specific
    subdirectories (x86, x64, or arm64).

.PARAMETER None
    This function uses global variables for configuration:
    - $global:workdir: The working directory where OneDrive installers will be saved
    - $WPFSourceWimArchTextBox.text: The architecture of the target Windows image (x64 or ARM64)

.EXAMPLE
    Get-OneDrive
    Downloads the appropriate OneDrive installer(s) for the selected Windows version and architecture.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Internet connectivity to download from Microsoft's official CDN.
    The function handles architecture-specific download logic automatically.
    Based on original work by David Segura (@SeguraOSD).

.OUTPUTS
    None. Downloads files to $global:workdir\updates\OneDrive and logs status via Update-Log.
#>
Function Get-OneDrive {
    #https://go.microsoft.com/fwlink/p/?LinkID=844652 -Possible new link location.
    #https://go.microsoft.com/fwlink/?linkid=2181064 - x64 installer
    #https://go.microsoft.com/fwlink/?linkid=2282608 - ARM64 installer

    # Detect Windows version and architecture being serviced
    $os = Get-WindowsType
    $arch = $WPFSourceWimArchTextBox.text

    # Windows 10 x64: Download x86 + x64
    # Windows 11 x64: Download x64 only
    # Windows 11 ARM64: Download ARM64 only

    if ($os -eq 'Windows 10') {
        Update-Log -Data 'Downloading latest 32-bit OneDrive agent installer for Windows 10...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/p/?LinkId=248256'
        $DownloadPath = "$global:workdir\updates\OneDrive\x86"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive x86 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive x86 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping x86 OneDrive download for Windows 11' -Class Information
    }

    # Only download x64 for Windows 10 or Windows 11 x64 (skip for ARM64)
    if (($os -eq 'Windows 10') -or (($os -eq 'Windows 11') -and ($arch -eq 'x64'))) {
        Update-Log -Data 'Downloading latest 64-bit OneDrive agent installer...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/?linkid=2181064'
        $DownloadPath = "$global:workdir\updates\OneDrive\x64"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive x64 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive x64 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping x64 OneDrive download for Windows 11 ARM64' -Class Information
    }

    if (($os -eq 'Windows 11') -and ($arch -eq 'ARM64')) {
        Update-Log -Data 'Downloading latest ARM64 OneDrive agent installer for Windows 11...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/?linkid=2282608'
        $DownloadPath = "$global:workdir\updates\OneDrive\arm64"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive ARM64 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive ARM64 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping ARM64 OneDrive download (not Windows 11 ARM64)' -Class Information
    }

}

<#
.SYNOPSIS
    Copies the updated x86 OneDrive installer to the mounted Windows image (SysWOW64).

.DESCRIPTION
    Copies the x86 OneDrive installer from the updates folder to the SysWOW64 directory in a mounted
    Windows image. This function handles the complex task of modifying file permissions (ACLs) to allow
    the copy operation, then restores the original ACLs. It includes validation to skip the operation
    if the target is a Windows 11 or ARM64 system (which lack SysWOW64), or if the installer has not
    been downloaded.

.PARAMETER None
    This function uses global variables for configuration:
    - $global:workdir: The working directory containing the OneDrive x86 installer
    - $WPFMISMountTextBox.text: The path to the mounted Windows image

.EXAMPLE
    Copy-OneDrive
    Copies the x86 OneDrive installer to the mounted image's SysWOW64 folder.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: A mounted Windows image and a downloaded x86 OneDrive installer.
    Only applies to x64 systems that have SysWOW64. Skips for Windows 11 and ARM64.
    The function preserves original file ACLs by backing them up and restoring them after the copy.

.OUTPUTS
    None. Logs copy operations and ACL changes via Update-Log.
#>
Function Copy-OneDrive {
    Update-Log -data 'Updating OneDrive x86 client' -class information
    $mountpath = $WPFMISMountTextBox.text

    # Check if SysWOW64 exists (only present on x64 systems, not on Windows 11 or ARM64)
    if (-not (Test-Path "$mountpath\Windows\SysWOW64\OneDriveSetup.exe")) {
        Update-Log -Data 'Skipping x86 OneDrive—SysWOW64 not present (likely Windows 11 or ARM64 system)' -Class Information
        return
    }

    # Check if x86 installer was downloaded
    if (-not (Test-Path "$global:workdir\updates\OneDrive\x86\OneDriveSetup.exe")) {
        Update-Log -Data 'x86 OneDrive installer not found in updates folder. Skipping x86 update.' -Class Warning
        return
    }

    try {
        Update-Log -Data 'Setting ACL on the original OneDriveSetup.exe file' -Class Information

        $AclBAK = Get-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe"
        $user = $env:USERDOMAIN + '\' + $env:USERNAME
        $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $user
        $item = Get-Item "$mountpath\Windows\SysWOW64\OneDriveSetup.exe"

        $Acl = $null # Reset the $Acl variable to $null
        $Acl = Get-Acl -Path $Item.FullName # Get the ACL from the item
        $Acl.SetOwner($Account) # Update the in-memory ACL
        Set-Acl -Path $Item.FullName -AclObject $Acl -ErrorAction Stop  # Set the updated ACL on the target item
        Update-Log -Data 'Ownership of OneDriveSetup.exe siezed' -Class Information

        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'FullControl', 'Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe" $Acl -ErrorAction Stop | Out-Null

        Update-Log -Data 'ACL successfully updated. Continuing...'
    } catch {
        Update-Log -data "Couldn't set the ACL on the original file" -Class Error
        return
    }

    try {
        Update-Log -data 'Copying updated OneDrive agent installer...' -Class Information
        Copy-Item "$global:workdir\updates\OneDrive\x86\OneDriveSetup.exe" -Destination "$mountpath\Windows\SysWOW64" -Force -ErrorAction Stop
        Update-Log -Data 'OneDrive x86 installer successfully copied.' -Class Information
    } catch {
        Update-Log -data "Couldn't copy the OneDrive installer file." -class Error
        Update-Log -data $_.Exception.Message -Class Error
        return
    }

    try {
        Update-Log -data 'Restoring original ACL to OneDrive installer.' -Class Information
        Set-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe" $AclBAK -ErrorAction Stop | Out-Null
        Update-Log -data 'Restoration complete' -Class Information
    } catch {
        Update-Log "Couldn't restore original ACLs. Continuing." -Class Error
    }
}

<#
.SYNOPSIS
    Copies the updated x64 or ARM64 OneDrive installer to the mounted Windows image (System32).

.DESCRIPTION
    Copies the x64 or ARM64 OneDrive installer from the updates folder to the System32 directory in
    a mounted Windows image. The function automatically detects the target architecture (x64 or ARM64)
    and uses the appropriate installer. Like Copy-OneDrive, this function handles ACL (Access Control List)
    modifications to enable the copy operation, then restores the original permissions. It includes
    validation to ensure both the source installer and target file exist before attempting the copy.

.PARAMETER None
    This function uses global variables for configuration:
    - $global:workdir: The working directory containing the OneDrive x64/ARM64 installer
    - $WPFMISMountTextBox.text: The path to the mounted Windows image
    - $WPFSourceWimArchTextBox.text: The architecture of the target image (x64 or ARM64)

.EXAMPLE
    Copy-OneDrivex64
    Copies the x64 or ARM64 OneDrive installer to the mounted image's System32 folder based on target architecture.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: A mounted Windows image and a downloaded x64 or ARM64 OneDrive installer.
    Automatically selects the correct installer based on the target WIM architecture.
    The function preserves original file ACLs by backing them up and restoring them after the copy.

.OUTPUTS
    None. Logs copy operations and ACL changes via Update-Log.
#>
Function Copy-OneDrivex64 {
    Update-Log -data 'Updating OneDrive x64/ARM64 client' -class information
    $mountpath = $WPFMISMountTextBox.text

    # Detect WIM architecture
    $wimArch = $WPFSourceWimArchTextBox.text

    # Determine which installer to use
    $installerPath = ""
    $archType = ""

    if ($wimArch -eq 'ARM64') {
        $installerPath = "$global:workdir\updates\OneDrive\arm64\OneDriveSetup.exe"
        $archType = 'ARM64'
    } else {
        $installerPath = "$global:workdir\updates\OneDrive\x64\OneDriveSetup.exe"
        $archType = 'x64'
    }

    # Check if installer exists
    if (-not (Test-Path $installerPath)) {
        Update-Log -Data "$archType OneDrive installer not found at $installerPath. Skipping update." -Class Warning
        return
    }

    # Check if target file exists in mount
    if (-not (Test-Path "$mountpath\Windows\System32\OneDriveSetup.exe")) {
        Update-Log -Data 'OneDriveSetup.exe not found in System32. Skipping update.' -Class Warning
        return
    }

    try {
        Update-Log -Data "Setting ACL on the original OneDriveSetup.exe file ($archType)" -Class Information

        $AclBAK = Get-Acl "$mountpath\Windows\System32\OneDriveSetup.exe"
        $user = $env:USERDOMAIN + '\' + $env:USERNAME
        $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $user
        $item = Get-Item "$mountpath\Windows\System32\OneDriveSetup.exe"

        $Acl = $null # Reset the $Acl variable to $null
        $Acl = Get-Acl -Path $Item.FullName # Get the ACL from the item
        $Acl.SetOwner($Account) # Update the in-memory ACL
        Set-Acl -Path $Item.FullName -AclObject $Acl -ErrorAction Stop  # Set the updated ACL on the target item
        Update-Log -Data 'Ownership of OneDriveSetup.exe siezed' -Class Information

        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'FullControl', 'Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl "$mountpath\Windows\System32\OneDriveSetup.exe" $Acl -ErrorAction Stop | Out-Null

        Update-Log -Data 'ACL successfully updated. Continuing...'
    } catch {
        Update-Log -data "Couldn't set the ACL on the original file" -Class Error
        return
    }

    try {
        Update-Log -data "Copying updated OneDrive $archType agent installer..." -Class Information
        Copy-Item $installerPath -Destination "$mountpath\Windows\System32" -Force -ErrorAction Stop
        Update-Log -Data "OneDrive $archType installer successfully copied." -Class Information
    } catch {
        Update-Log -data "Couldn't copy the OneDrive installer file." -class Error
        Update-Log -data $_.Exception.Message -Class Error
        return
    }

    try {
        Update-Log -data 'Restoring original ACL to OneDrive installer.' -Class Information
        Set-Acl "$mountpath\Windows\System32\OneDriveSetup.exe" $AclBAK -ErrorAction Stop | Out-Null
        Update-Log -data 'Restoration complete' -Class Information
    } catch {
        Update-Log "Couldn't restore original ACLs. Continuing." -Class Error
    }
}

#Function to call the next three Functions. This determines WinOS and WinVer and calls the Function
<#
.SYNOPSIS
    Routes Language Pack, Local Experience Pack, or Features On Demand selection based on type.

.DESCRIPTION
    Determines the appropriate import source folder based on the specified type and the detected
    Windows version. Validates that the source folder exists before routing to the appropriate
    selection function (Language Packs, Local Experience Packs, or Features On Demand).
    Handles version compatibility mapping for Windows 10 builds.

.PARAMETER Type
    The type of content to select. Valid values:
    - 'LP' for Language Packs
    - 'LXP' for Local Experience Packs
    - 'FOD' for Features On Demand

.EXAMPLE
    Select-LPFODCriteria -Type 'LP'
    Routes to language pack selection if source is available.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Properly structured imports directory with Lang and FODs subfolders.

.OUTPUTS
    None. Routes to appropriate selection function.
#>
<#
.SYNOPSIS
    Routes language pack, local experience pack, or features on demand selection based on type criteria.

.DESCRIPTION
    Determines the appropriate selection function to call based on the provided type parameter.
    Validates that the required source directories exist before proceeding with selection.
    Handles version normalization for Windows 10 versions (2009, 20H2, 21H1, 21H2, 22H2 map to 2004).
    Routes to Select-LanguagePacks, Select-LocalExperiencePack, or Select-FeaturesOnDemand accordingly.

.PARAMETER Type
    The type of content to select. Valid values:
    - 'LP': Language Packs
    - 'LXP': Local Experience Packs
    - 'FOD': Features On Demand

.EXAMPLE
    Select-LPFODCriteria -Type 'LP'
    Routes to Select-LanguagePacks for the current WIM's OS and version.

.EXAMPLE
    Select-LPFODCriteria -Type 'FOD'
    Routes to Select-FeaturesOnDemand after validating FOD source directory exists.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Get-WindowsType, Update-Log, Select-LanguagePacks, Select-LocalExperiencePack, Select-FeaturesOnDemand
    Validates paths in: $global:workdir\imports\Lang\{OS}\{Version}\LanguagePacks
                        $global:workdir\imports\Lang\{OS}\{Version}\localexperiencepack
                        $global:workdir\imports\FODs\{OS}\{Version}\

.OUTPUTS
    None. Calls appropriate selection function or logs error if source not found.
#>
Function Select-LPFODCriteria($Type) {

    $WinOS = Get-WindowsType
    #$WinVer = Get-WinVersionNumber
    $WinVer = $WPFSourceWimTBVersionNum.text

    if ($WinOS -eq 'Windows 10') {
        if (($Winver -eq '2009') -or ($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '21H2') -or ($winver -eq '22H2')) { $winver = '2004' }
    }

    if ($type -eq 'LP') {
        if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$Winver\LanguagePacks) -eq $false) {
            Update-Log -Data 'Source not found. Please import some language packs and try again' -Class Error
            return
        }
        Select-LanguagePacks -winver $Winver -WinOS $WinOS
    }

    If ($type -eq 'LXP') {
        if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$Winver\localexperiencepack) -eq $false) {
            Update-Log -Data 'Source not found. Please import some Local Experience Packs and try again' -Class Error
            return
        }
        Select-LocalExperiencePack -winver $Winver -WinOS $WinOS
    }

    if ($type -eq 'FOD') {
        if ((Test-Path -Path $global:workdir\imports\FODs\$WinOS\$Winver\) -eq $false) {

            Update-Log -Data 'Source not found. Please import some Demanding Features and try again' -Class Error
            return
        }

        Select-FeaturesOnDemand -winver $Winver -WinOS $WinOS
    }
}

<#
.SYNOPSIS
    Displays available language packs for selection and adds them to the form list.

.DESCRIPTION
    Retrieves language pack files from the import directory for the specified Windows version.
    Displays available language packs in a grid view dialog for multi-select.
    Adds selected items to the form's language pack listbox for injection into the image.

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-LanguagePacks -winver '22H2' -WinOS 'Windows 10'
    Displays available language packs for Windows 10 22H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBLangPacks listbox control
    Source directory structure: imports\lang\{WinOS}\{winver}\LanguagePacks\

.OUTPUTS
    None. Updates form listbox.
#>
<#
.SYNOPSIS
    Displays available language packs for selection and adds them to the form list.

.DESCRIPTION
    Retrieves language pack (.cab) files from the import directory for the specified Windows version.
    Displays available language packs in a grid view dialog for multi-select.
    Adds selected items to the form's language pack listbox for injection into the WIM image.

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004', '1909').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-LanguagePacks -winver '22H2' -WinOS 'Windows 10'
    Displays available Language Packs for Windows 10 22H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBLangPacks listbox control
    Source directory structure: imports\lang\{WinOS}\{winver}\LanguagePacks\

.OUTPUTS
    None. Updates form listbox.
#>
Function Select-LanguagePacks($winver, $WinOS) {

    $LPSourceFolder = $global:workdir + '\imports\lang\' + $WinOS + '\' + $winver + '\' + 'LanguagePacks' + '\'

    $items = (Get-ChildItem -Path $LPSourceFolder | Select-Object -Property Name | Out-GridView -Title 'Select Language Packs' -PassThru)
    foreach ($item in $items) { $WPFCustomLBLangPacks.Items.Add($item.name) }
}

<#
.SYNOPSIS
    Displays available Local Experience Packs for selection and adds them to the form list.

.DESCRIPTION
    Retrieves Local Experience Pack (LXP) files from the import directory for the specified Windows version.
    Displays available LXP files in a grid view dialog for multi-select.
    Adds selected items to the form's LXP listbox for injection into the image.

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-LocalExperiencePack -winver '23H2' -WinOS 'Windows 11'
    Displays available Local Experience Packs for Windows 11 23H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBLEP listbox control
    Source directory structure: imports\lang\{WinOS}\{winver}\localexperiencepack\

.OUTPUTS
    None. Updates form listbox.
#>
<#
.SYNOPSIS
    Displays available Local Experience Packs for selection and adds them to the form list.

.DESCRIPTION
    Retrieves Local Experience Pack (LXP) files from the import directory for the specified Windows version.
    Displays available LXP files in a grid view dialog for multi-select.
    Adds selected items to the form's LXP listbox for injection into the image.

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004', '1909').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-LocalExperiencePack -winver '23H2' -WinOS 'Windows 11'
    Displays available Local Experience Packs for Windows 11 23H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBLEP listbox control
    Source directory structure: imports\lang\{WinOS}\{winver}\localexperiencepack\

.OUTPUTS
    None. Updates form listbox.
#>
Function Select-LocalExperiencePack($winver, $WinOS) {

    $LPSourceFolder = $global:workdir + '\imports\lang\' + $WinOS + '\' + $winver + '\' + 'localexperiencepack' + '\'


    $items = (Get-ChildItem -Path $LPSourceFolder | Select-Object -Property Name | Out-GridView -Title 'Select Local Experience Packs' -PassThru)
    foreach ($item in $items) { $WPFCustomLBLEP.Items.Add($item.name) }
}
<#
.SYNOPSIS
    Displays available Features On Demand (FOD) for selection and adds them to the form list.

.DESCRIPTION
    Retrieves Features On Demand (FOD) capability identifiers for the specified Windows version.
    Displays available FODs in a grid view dialog for multi-select.
    Adds selected FOD capabilities to the form's FOD listbox for injection into the image.
    FODs are Windows capabilities that can be added to an image (e.g., NetFx3, Speech, etc.).

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-FeaturesOnDemand -winver '22H2' -WinOS 'Windows 10'
    Displays available Features On Demand for Windows 10 22H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBFOD listbox control
    FODs are specified using their capability identifiers (e.g., 'Browser.InternetExplorer~~~~0.0.11.0').
    Source directory structure: imports\FODs\{WinOS}\{winver}\

.OUTPUTS
    None. Updates form listbox.
#>
<#
.SYNOPSIS
    Displays available Features On Demand (FOD) for selection and adds them to the form list.

.DESCRIPTION
    Retrieves Features On Demand (FOD) capability identifiers for the specified Windows version.
    Displays available FODs in a grid view dialog for multi-select.
    Adds selected FOD capabilities to the form's FOD listbox for injection into the image.
    FODs are Windows capabilities that can be added to an image (e.g., NetFx3, Speech, Language features, etc.).

.PARAMETER winver
    The Windows version (e.g., '22H2', '23H2', '2004', '1909').

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Select-FeaturesOnDemand -winver '22H2' -WinOS 'Windows 10'
    Displays available Features On Demand for Windows 10 22H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBFOD listbox control
    FODs are specified using their capability identifiers (e.g., 'Browser.InternetExplorer~~~~0.0.11.0').
    Source directory structure: imports\FODs\{WinOS}\{winver}\

.OUTPUTS
    None. Updates form listbox.
#>
Function Select-FeaturesOnDemand($winver, $WinOS) {
    $Win10_1909_FODs = @('Accessibility.Braille~~~~0.0.1.0',
        'Analog.Holographic.Desktop~~~~0.0.1.0',
        'App.Support.QuickAssist~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'Hello.Face.18330~~~~0.0.1.0',
        'Hello.Face.Migration.18330~~~~0.0.1.0',
        'Language.Basic~~~af-ZA~0.0.1.0',
        'Language.Basic~~~ar-SA~0.0.1.0',
        'Language.Basic~~~as-IN~0.0.1.0',
        'Language.Basic~~~az-LATN-AZ~0.0.1.0',
        'Language.Basic~~~ba-RU~0.0.1.0',
        'Language.Basic~~~be-BY~0.0.1.0',
        'Language.Basic~~~bg-BG~0.0.1.0',
        'Language.Basic~~~bn-BD~0.0.1.0',
        'Language.Basic~~~bn-IN~0.0.1.0',
        'Language.Basic~~~bs-LATN-BA~0.0.1.0',
        'Language.Basic~~~ca-ES~0.0.1.0',
        'Language.Basic~~~cs-CZ~0.0.1.0',
        'Language.Basic~~~cy-GB~0.0.1.0',
        'Language.Basic~~~da-DK~0.0.1.0',
        'Language.Basic~~~de-CH~0.0.1.0',
        'Language.Basic~~~de-DE~0.0.1.0',
        'Language.Basic~~~el-GR~0.0.1.0',
        'Language.Basic~~~en-AU~0.0.1.0',
        'Language.Basic~~~en-CA~0.0.1.0',
        'Language.Basic~~~en-GB~0.0.1.0',
        'Language.Basic~~~en-IN~0.0.1.0',
        'Language.Basic~~~en-US~0.0.1.0',
        'Language.Basic~~~es-ES~0.0.1.0',
        'Language.Basic~~~es-MX~0.0.1.0',
        'Language.Basic~~~es-US~0.0.1.0',
        'Language.Basic~~~et-EE~0.0.1.0',
        'Language.Basic~~~eu-ES~0.0.1.0',
        'Language.Basic~~~fa-IR~0.0.1.0',
        'Language.Basic~~~fi-FI~0.0.1.0',
        'Language.Basic~~~fil-PH~0.0.1.0',
        'Language.Basic~~~fr-BE~0.0.1.0',
        'Language.Basic~~~fr-CA~0.0.1.0',
        'Language.Basic~~~fr-CH~0.0.1.0',
        'Language.Basic~~~fr-FR~0.0.1.0',
        'Language.Basic~~~ga-IE~0.0.1.0',
        'Language.Basic~~~gd-GB~0.0.1.0',
        'Language.Basic~~~gl-ES~0.0.1.0',
        'Language.Basic~~~gu-IN~0.0.1.0',
        'Language.Basic~~~ha-LATN-NG~0.0.1.0',
        'Language.Basic~~~haw-US~0.0.1.0',
        'Language.Basic~~~he-IL~0.0.1.0',
        'Language.Basic~~~hi-IN~0.0.1.0',
        'Language.Basic~~~hr-HR~0.0.1.0',
        'Language.Basic~~~hu-HU~0.0.1.0',
        'Language.Basic~~~hy-AM~0.0.1.0',
        'Language.Basic~~~id-ID~0.0.1.0',
        'Language.Basic~~~ig-NG~0.0.1.0',
        'Language.Basic~~~is-IS~0.0.1.0',
        'Language.Basic~~~it-IT~0.0.1.0',
        'Language.Basic~~~ja-JP~0.0.1.0',
        'Language.Basic~~~ka-GE~0.0.1.0',
        'Language.Basic~~~kk-KZ~0.0.1.0',
        'Language.Basic~~~kl-GL~0.0.1.0',
        'Language.Basic~~~kn-IN~0.0.1.0',
        'Language.Basic~~~ko-KR~0.0.1.0',
        'Language.Basic~~~kok-DEVA-IN~0.0.1.0',
        'Language.Basic~~~ky-KG~0.0.1.0',
        'Language.Basic~~~lb-LU~0.0.1.0',
        'Language.Basic~~~lt-LT~0.0.1.0',
        'Language.Basic~~~lv-LV~0.0.1.0',
        'Language.Basic~~~mi-NZ~0.0.1.0',
        'Language.Basic~~~mk-MK~0.0.1.0',
        'Language.Basic~~~ml-IN~0.0.1.0',
        'Language.Basic~~~mn-MN~0.0.1.0',
        'Language.Basic~~~mr-IN~0.0.1.0',
        'Language.Basic~~~ms-BN~0.0.1.0',
        'Language.Basic~~~ms-MY~0.0.1.0',
        'Language.Basic~~~mt-MT~0.0.1.0',
        'Language.Basic~~~nb-NO~0.0.1.0',
        'Language.Basic~~~ne-NP~0.0.1.0',
        'Language.Basic~~~nl-NL~0.0.1.0',
        'Language.Basic~~~nn-NO~0.0.1.0',
        'Language.Basic~~~nso-ZA~0.0.1.0',
        'Language.Basic~~~or-IN~0.0.1.0',
        'Language.Basic~~~pa-IN~0.0.1.0',
        'Language.Basic~~~pl-PL~0.0.1.0',
        'Language.Basic~~~ps-AF~0.0.1.0',
        'Language.Basic~~~pt-BR~0.0.1.0',
        'Language.Basic~~~pt-PT~0.0.1.0',
        'Language.Basic~~~rm-CH~0.0.1.0',
        'Language.Basic~~~ro-RO~0.0.1.0',
        'Language.Basic~~~ru-RU~0.0.1.0',
        'Language.Basic~~~rw-RW~0.0.1.0',
        'Language.Basic~~~sah-RU~0.0.1.0',
        'Language.Basic~~~si-LK~0.0.1.0',
        'Language.Basic~~~sk-SK~0.0.1.0',
        'Language.Basic~~~sl-SI~0.0.1.0',
        'Language.Basic~~~sq-AL~0.0.1.0',
        'Language.Basic~~~sr-CYRL-RS~0.0.1.0',
        'Language.Basic~~~sr-LATN-RS~0.0.1.0',
        'Language.Basic~~~sv-SE~0.0.1.0',
        'Language.Basic~~~sw-KE~0.0.1.0',
        'Language.Basic~~~ta-IN~0.0.1.0',
        'Language.Basic~~~te-IN~0.0.1.0',
        'Language.Basic~~~tg-CYRL-TJ~0.0.1.0',
        'Language.Basic~~~th-TH~0.0.1.0',
        'Language.Basic~~~tk-TM~0.0.1.0',
        'Language.Basic~~~tn-ZA~0.0.1.0',
        'Language.Basic~~~tr-TR~0.0.1.0',
        'Language.Basic~~~tt-RU~0.0.1.0',
        'Language.Basic~~~ug-CN~0.0.1.0',
        'Language.Basic~~~uk-UA~0.0.1.0',
        'Language.Basic~~~ur-PK~0.0.1.0',
        'Language.Basic~~~uz-LATN-UZ~0.0.1.0',
        'Language.Basic~~~vi-VN~0.0.1.0',
        'Language.Basic~~~wo-SN~0.0.1.0',
        'Language.Basic~~~xh-ZA~0.0.1.0',
        'Language.Basic~~~yo-NG~0.0.1.0',
        'Language.Basic~~~zh-CN~0.0.1.0',
        'Language.Basic~~~zh-HK~0.0.1.0',
        'Language.Basic~~~zh-TW~0.0.1.0',
        'Language.Basic~~~zu-ZA~0.0.1.0',
        'Language.Fonts.Arab~~~und-ARAB~0.0.1.0',
        'Language.Fonts.Beng~~~und-BENG~0.0.1.0',
        'Language.Fonts.Cans~~~und-CANS~0.0.1.0',
        'Language.Fonts.Cher~~~und-CHER~0.0.1.0',
        'Language.Fonts.Deva~~~und-DEVA~0.0.1.0',
        'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0',
        'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0',
        'Language.Fonts.Guru~~~und-GURU~0.0.1.0',
        'Language.Fonts.Hans~~~und-HANS~0.0.1.0',
        'Language.Fonts.Hant~~~und-HANT~0.0.1.0',
        'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0',
        'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0',
        'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0',
        'Language.Fonts.Knda~~~und-KNDA~0.0.1.0',
        'Language.Fonts.Kore~~~und-KORE~0.0.1.0',
        'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0',
        'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0',
        'Language.Fonts.Orya~~~und-ORYA~0.0.1.0',
        'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0',
        'Language.Fonts.Sinh~~~und-SINH~0.0.1.0',
        'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0',
        'Language.Fonts.Taml~~~und-TAML~0.0.1.0',
        'Language.Fonts.Telu~~~und-TELU~0.0.1.0',
        'Language.Fonts.Thai~~~und-THAI~0.0.1.0',
        'Language.Handwriting~~~af-ZA~0.0.1.0',
        'Language.Handwriting~~~bs-LATN-BA~0.0.1.0',
        'Language.Handwriting~~~ca-ES~0.0.1.0',
        'Language.Handwriting~~~cs-CZ~0.0.1.0',
        'Language.Handwriting~~~cy-GB~0.0.1.0',
        'Language.Handwriting~~~da-DK~0.0.1.0',
        'Language.Handwriting~~~de-DE~0.0.1.0',
        'Language.Handwriting~~~el-GR~0.0.1.0',
        'Language.Handwriting~~~en-GB~0.0.1.0',
        'Language.Handwriting~~~en-US~0.0.1.0',
        'Language.Handwriting~~~es-ES~0.0.1.0',
        'Language.Handwriting~~~es-MX~0.0.1.0',
        'Language.Handwriting~~~eu-ES~0.0.1.0',
        'Language.Handwriting~~~fi-FI~0.0.1.0',
        'Language.Handwriting~~~fr-FR~0.0.1.0',
        'Language.Handwriting~~~ga-IE~0.0.1.0',
        'Language.Handwriting~~~gd-GB~0.0.1.0',
        'Language.Handwriting~~~gl-ES~0.0.1.0',
        'Language.Handwriting~~~hi-IN~0.0.1.0',
        'Language.Handwriting~~~hr-HR~0.0.1.0',
        'Language.Handwriting~~~id-ID~0.0.1.0',
        'Language.Handwriting~~~it-IT~0.0.1.0',
        'Language.Handwriting~~~ja-JP~0.0.1.0',
        'Language.Handwriting~~~ko-KR~0.0.1.0',
        'Language.Handwriting~~~lb-LU~0.0.1.0',
        'Language.Handwriting~~~mi-NZ~0.0.1.0',
        'Language.Handwriting~~~ms-BN~0.0.1.0',
        'Language.Handwriting~~~ms-MY~0.0.1.0',
        'Language.Handwriting~~~nb-NO~0.0.1.0',
        'Language.Handwriting~~~nl-NL~0.0.1.0',
        'Language.Handwriting~~~nn-NO~0.0.1.0',
        'Language.Handwriting~~~nso-ZA~0.0.1.0',
        'Language.Handwriting~~~pl-PL~0.0.1.0',
        'Language.Handwriting~~~pt-BR~0.0.1.0',
        'Language.Handwriting~~~pt-PT~0.0.1.0',
        'Language.Handwriting~~~rm-CH~0.0.1.0',
        'Language.Handwriting~~~ro-RO~0.0.1.0',
        'Language.Handwriting~~~ru-RU~0.0.1.0',
        'Language.Handwriting~~~rw-RW~0.0.1.0',
        'Language.Handwriting~~~sk-SK~0.0.1.0',
        'Language.Handwriting~~~sl-SI~0.0.1.0',
        'Language.Handwriting~~~sq-AL~0.0.1.0',
        'Language.Handwriting~~~sr-CYRL-RS~0.0.1.0',
        'Language.Handwriting~~~sr-LATN-RS~0.0.1.0',
        'Language.Handwriting~~~sv-SE~0.0.1.0',
        'Language.Handwriting~~~sw-KE~0.0.1.0',
        'Language.Handwriting~~~tn-ZA~0.0.1.0',
        'Language.Handwriting~~~tr-TR~0.0.1.0',
        'Language.Handwriting~~~wo-SN~0.0.1.0',
        'Language.Handwriting~~~xh-ZA~0.0.1.0',
        'Language.Handwriting~~~zh-CN~0.0.1.0',
        'Language.Handwriting~~~zh-HK~0.0.1.0',
        'Language.Handwriting~~~zh-TW~0.0.1.0',
        'Language.Handwriting~~~zu-ZA~0.0.1.0',
        'Language.OCR~~~ar-SA~0.0.1.0',
        'Language.OCR~~~bg-BG~0.0.1.0',
        'Language.OCR~~~bs-LATN-BA~0.0.1.0',
        'Language.OCR~~~cs-CZ~0.0.1.0',
        'Language.OCR~~~da-DK~0.0.1.0',
        'Language.OCR~~~de-DE~0.0.1.0',
        'Language.OCR~~~el-GR~0.0.1.0',
        'Language.OCR~~~en-GB~0.0.1.0',
        'Language.OCR~~~en-US~0.0.1.0',
        'Language.OCR~~~es-ES~0.0.1.0',
        'Language.OCR~~~es-MX~0.0.1.0',
        'Language.OCR~~~fi-FI~0.0.1.0',
        'Language.OCR~~~fr-CA~0.0.1.0',
        'Language.OCR~~~fr-FR~0.0.1.0',
        'Language.OCR~~~hr-HR~0.0.1.0',
        'Language.OCR~~~hu-HU~0.0.1.0',
        'Language.OCR~~~it-IT~0.0.1.0',
        'Language.OCR~~~ja-JP~0.0.1.0',
        'Language.OCR~~~ko-KR~0.0.1.0',
        'Language.OCR~~~nb-NO~0.0.1.0',
        'Language.OCR~~~nl-NL~0.0.1.0',
        'Language.OCR~~~pl-PL~0.0.1.0',
        'Language.OCR~~~pt-BR~0.0.1.0',
        'Language.OCR~~~pt-PT~0.0.1.0',
        'Language.OCR~~~ro-RO~0.0.1.0',
        'Language.OCR~~~ru-RU~0.0.1.0',
        'Language.OCR~~~sk-SK~0.0.1.0',
        'Language.OCR~~~sl-SI~0.0.1.0',
        'Language.OCR~~~sr-CYRL-RS~0.0.1.0',
        'Language.OCR~~~sr-LATN-RS~0.0.1.0',
        'Language.OCR~~~sv-SE~0.0.1.0',
        'Language.OCR~~~tr-TR~0.0.1.0',
        'Language.OCR~~~zh-CN~0.0.1.0',
        'Language.OCR~~~zh-HK~0.0.1.0',
        'Language.OCR~~~zh-TW~0.0.1.0',
        'Language.Speech~~~da-DK~0.0.1.0',
        'Language.Speech~~~de-DE~0.0.1.0',
        'Language.Speech~~~en-AU~0.0.1.0',
        'Language.Speech~~~en-CA~0.0.1.0',
        'Language.Speech~~~en-GB~0.0.1.0',
        'Language.Speech~~~en-IN~0.0.1.0',
        'Language.Speech~~~en-US~0.0.1.0',
        'Language.Speech~~~es-ES~0.0.1.0',
        'Language.Speech~~~es-MX~0.0.1.0',
        'Language.Speech~~~fr-CA~0.0.1.0',
        'Language.Speech~~~fr-FR~0.0.1.0',
        'Language.Speech~~~it-IT~0.0.1.0',
        'Language.Speech~~~ja-JP~0.0.1.0',
        'Language.Speech~~~pt-BR~0.0.1.0',
        'Language.Speech~~~zh-CN~0.0.1.0',
        'Language.Speech~~~zh-HK~0.0.1.0',
        'Language.Speech~~~zh-TW~0.0.1.0',
        'Language.TextToSpeech~~~ar-EG~0.0.1.0',
        'Language.TextToSpeech~~~ar-SA~0.0.1.0',
        'Language.TextToSpeech~~~bg-BG~0.0.1.0',
        'Language.TextToSpeech~~~ca-ES~0.0.1.0',
        'Language.TextToSpeech~~~cs-CZ~0.0.1.0',
        'Language.TextToSpeech~~~da-DK~0.0.1.0',
        'Language.TextToSpeech~~~de-AT~0.0.1.0',
        'Language.TextToSpeech~~~de-CH~0.0.1.0',
        'Language.TextToSpeech~~~de-DE~0.0.1.0',
        'Language.TextToSpeech~~~el-GR~0.0.1.0',
        'Language.TextToSpeech~~~en-AU~0.0.1.0',
        'Language.TextToSpeech~~~en-CA~0.0.1.0',
        'Language.TextToSpeech~~~en-GB~0.0.1.0',
        'Language.TextToSpeech~~~en-IE~0.0.1.0',
        'Language.TextToSpeech~~~en-IN~0.0.1.0',
        'Language.TextToSpeech~~~en-US~0.0.1.0',
        'Language.TextToSpeech~~~es-ES~0.0.1.0',
        'Language.TextToSpeech~~~es-MX~0.0.1.0',
        'Language.TextToSpeech~~~fi-FI~0.0.1.0',
        'Language.TextToSpeech~~~fr-CA~0.0.1.0',
        'Language.TextToSpeech~~~fr-CH~0.0.1.0',
        'Language.TextToSpeech~~~fr-FR~0.0.1.0',
        'Language.TextToSpeech~~~he-IL~0.0.1.0',
        'Language.TextToSpeech~~~hi-IN~0.0.1.0',
        'Language.TextToSpeech~~~hr-HR~0.0.1.0',
        'Language.TextToSpeech~~~hu-HU~0.0.1.0',
        'Language.TextToSpeech~~~id-ID~0.0.1.0',
        'Language.TextToSpeech~~~it-IT~0.0.1.0',
        'Language.TextToSpeech~~~ja-JP~0.0.1.0',
        'Language.TextToSpeech~~~ko-KR~0.0.1.0',
        'Language.TextToSpeech~~~ms-MY~0.0.1.0',
        'Language.TextToSpeech~~~nb-NO~0.0.1.0',
        'Language.TextToSpeech~~~nl-BE~0.0.1.0',
        'Language.TextToSpeech~~~nl-NL~0.0.1.0',
        'Language.TextToSpeech~~~pl-PL~0.0.1.0',
        'Language.TextToSpeech~~~pt-BR~0.0.1.0',
        'Language.TextToSpeech~~~pt-PT~0.0.1.0',
        'Language.TextToSpeech~~~ro-RO~0.0.1.0',
        'Language.TextToSpeech~~~ru-RU~0.0.1.0',
        'Language.TextToSpeech~~~sk-SK~0.0.1.0',
        'Language.TextToSpeech~~~sl-SI~0.0.1.0',
        'Language.TextToSpeech~~~sv-SE~0.0.1.0',
        'Language.TextToSpeech~~~ta-IN~0.0.1.0',
        'Language.TextToSpeech~~~th-TH~0.0.1.0',
        'Language.TextToSpeech~~~tr-TR~0.0.1.0',
        'Language.TextToSpeech~~~vi-VN~0.0.1.0',
        'Language.TextToSpeech~~~zh-CN~0.0.1.0',
        'Language.TextToSpeech~~~zh-HK~0.0.1.0',
        'Language.TextToSpeech~~~zh-TW~0.0.1.0',
        'MathRecognizer~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Onecore.StorageManagement~~~~0.0.1.0',
        'Microsoft.WebDriver~~~~0.0.1.0',
        'Microsoft.Windows.StorageManagement~~~~0.0.1.0',
        'Msix.PackagingTool.Driver~~~~0.0.1.0',
        'NetFX3~~~~',
        'Network.Irda~~~~0.0.1.0',
        'OneCoreUAP.OneSync~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'OpenSSH.Server~~~~0.0.1.0',
        'RasCMAK.Client~~~~0.0.1.0',
        'RIP.Listener~~~~0.0.1.0',
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',
        'Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0',
        'Rsat.CertificateServices.Tools~~~~0.0.1.0',
        'Rsat.DHCP.Tools~~~~0.0.1.0',
        'Rsat.Dns.Tools~~~~0.0.1.0',
        'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0',
        'Rsat.FileServices.Tools~~~~0.0.1.0',
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
        'Rsat.IPAM.Client.Tools~~~~0.0.1.0',
        'Rsat.LLDP.Tools~~~~0.0.1.0',
        'Rsat.NetworkController.Tools~~~~0.0.1.0',
        'Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0',
        'Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0',
        'Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0',
        'Rsat.ServerManager.Tools~~~~0.0.1.0',
        'Rsat.Shielded.VM.Tools~~~~0.0.1.0',
        'Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0',
        'Rsat.StorageReplica.Tools~~~~0.0.1.0',
        'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0',
        'Rsat.VolumeActivation.Tools~~~~0.0.1.0',
        'Rsat.WSUS.Tools~~~~0.0.1.0',
        'SNMP.Client~~~~0.0.1.0',
        'Tools.DeveloperMode.Core~~~~0.0.1.0',
        'Tools.DTrace.Platform~~~~0.0.1.0',
        'Tools.Graphics.DirectX~~~~0.0.1.0',
        'WMI-SNMP-Provider.Client~~~~0.0.1.0',
        'XPS.Viewer~~~~0.0.1.0')
    $Win10_1903_FODs = @('Accessibility.Braille~~~~0.0.1.0',
        'Analog.Holographic.Desktop~~~~0.0.1.0',
        'App.Support.QuickAssist~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'Hello.Face.17658~~~~0.0.1.0',
        'Hello.Face.Migration.17658~~~~0.0.1.0',
        'Language.Basic~~~af-ZA~0.0.1.0',
        'Language.Basic~~~ar-SA~0.0.1.0',
        'Language.Basic~~~as-IN~0.0.1.0',
        'Language.Basic~~~az-LATN-AZ~0.0.1.0',
        'Language.Basic~~~ba-RU~0.0.1.0',
        'Language.Basic~~~be-BY~0.0.1.0',
        'Language.Basic~~~bg-BG~0.0.1.0',
        'Language.Basic~~~bn-BD~0.0.1.0',
        'Language.Basic~~~bn-IN~0.0.1.0',
        'Language.Basic~~~bs-LATN-BA~0.0.1.0',
        'Language.Basic~~~ca-ES~0.0.1.0',
        'Language.Basic~~~cs-CZ~0.0.1.0',
        'Language.Basic~~~cy-GB~0.0.1.0',
        'Language.Basic~~~da-DK~0.0.1.0',
        'Language.Basic~~~de-DE~0.0.1.0',
        'Language.Basic~~~el-GR~0.0.1.0',
        'Language.Basic~~~en-GB~0.0.1.0',
        'Language.Basic~~~en-US~0.0.1.0',
        'Language.Basic~~~es-ES~0.0.1.0',
        'Language.Basic~~~es-MX~0.0.1.0',
        'Language.Basic~~~et-EE~0.0.1.0',
        'Language.Basic~~~eu-ES~0.0.1.0',
        'Language.Basic~~~fa-IR~0.0.1.0',
        'Language.Basic~~~fi-FI~0.0.1.0',
        'Language.Basic~~~fil-PH~0.0.1.0',
        'Language.Basic~~~fr-CA~0.0.1.0',
        'Language.Basic~~~fr-FR~0.0.1.0',
        'Language.Basic~~~ga-IE~0.0.1.0',
        'Language.Basic~~~gd-GB~0.0.1.0',
        'Language.Basic~~~gl-ES~0.0.1.0',
        'Language.Basic~~~gu-IN~0.0.1.0',
        'Language.Basic~~~ha-LATN-NG~0.0.1.0',
        'Language.Basic~~~haw-US~0.0.1.0',
        'Language.Basic~~~he-IL~0.0.1.0',
        'Language.Basic~~~hi-IN~0.0.1.0',
        'Language.Basic~~~hr-HR~0.0.1.0',
        'Language.Basic~~~hu-HU~0.0.1.0',
        'Language.Basic~~~hy-AM~0.0.1.0',
        'Language.Basic~~~id-ID~0.0.1.0',
        'Language.Basic~~~ig-NG~0.0.1.0',
        'Language.Basic~~~is-IS~0.0.1.0',
        'Language.Basic~~~it-IT~0.0.1.0',
        'Language.Basic~~~ja-JP~0.0.1.0',
        'Language.Basic~~~ka-GE~0.0.1.0',
        'Language.Basic~~~kk-KZ~0.0.1.0',
        'Language.Basic~~~kl-GL~0.0.1.0',
        'Language.Basic~~~kn-IN~0.0.1.0',
        'Language.Basic~~~ko-KR~0.0.1.0',
        'Language.Basic~~~kok-DEVA-IN~0.0.1.0',
        'Language.Basic~~~ky-KG~0.0.1.0',
        'Language.Basic~~~lb-LU~0.0.1.0',
        'Language.Basic~~~lt-LT~0.0.1.0',
        'Language.Basic~~~lv-LV~0.0.1.0',
        'Language.Basic~~~mi-NZ~0.0.1.0',
        'Language.Basic~~~ml-IN~0.0.1.0',
        'Language.Basic~~~mk-MK~0.0.1.0',
        'Language.Basic~~~mn-MN~0.0.1.0',
        'Language.Basic~~~mr-IN~0.0.1.0',
        'Language.Basic~~~ms-BN~0.0.1.0',
        'Language.Basic~~~ms-MY~0.0.1.0',
        'Language.Basic~~~mt-MT~0.0.1.0',
        'Language.Basic~~~nb-NO~0.0.1.0',
        'Language.Basic~~~ne-NP~0.0.1.0',
        'Language.Basic~~~nl-NL~0.0.1.0',
        'Language.Basic~~~nn-NO~0.0.1.0',
        'Language.Basic~~~nso-ZA~0.0.1.0',
        'Language.Basic~~~or-IN~0.0.1.0',
        'Language.Basic~~~pa-IN~0.0.1.0',
        'Language.Basic~~~pl-PL~0.0.1.0',
        'Language.Basic~~~ps-AF~0.0.1.0',
        'Language.Basic~~~pt-BR~0.0.1.0',
        'Language.Basic~~~pt-PT~0.0.1.0',
        'Language.Basic~~~rm-CH~0.0.1.0',
        'Language.Basic~~~ro-RO~0.0.1.0',
        'Language.Basic~~~ru-RU~0.0.1.0',
        'Language.Basic~~~rw-RW~0.0.1.0',
        'Language.Basic~~~sah-RU~0.0.1.0',
        'Language.Basic~~~si-LK~0.0.1.0',
        'Language.Basic~~~sk-SK~0.0.1.0',
        'Language.Basic~~~sl-SI~0.0.1.0',
        'Language.Basic~~~sq-AL~0.0.1.0',
        'Language.Basic~~~sr-CYRL-RS~0.0.1.0',
        'Language.Basic~~~sr-LATN-RS~0.0.1.0',
        'Language.Basic~~~sv-SE~0.0.1.0',
        'Language.Basic~~~sw-KE~0.0.1.0',
        'Language.Basic~~~ta-IN~0.0.1.0',
        'Language.Basic~~~te-IN~0.0.1.0',
        'Language.Basic~~~tg-CYRL-TJ~0.0.1.0',
        'Language.Basic~~~th-TH~0.0.1.0',
        'Language.Basic~~~tk-TM~0.0.1.0',
        'Language.Basic~~~tn-ZA~0.0.1.0',
        'Language.Basic~~~tr-TR~0.0.1.0',
        'Language.Basic~~~tt-RU~0.0.1.0',
        'Language.Basic~~~ug-CN~0.0.1.0',
        'Language.Basic~~~uk-UA~0.0.1.0',
        'Language.Basic~~~ur-PK~0.0.1.0',
        'Language.Basic~~~uz-LATN-UZ~0.0.1.0',
        'Language.Basic~~~vi-VN~0.0.1.0',
        'Language.Basic~~~wo-SN~0.0.1.0',
        'Language.Basic~~~xh-ZA~0.0.1.0',
        'Language.Basic~~~yo-NG~0.0.1.0',
        'Language.Basic~~~zh-CN~0.0.1.0',
        'Language.Basic~~~zh-HK~0.0.1.0',
        'Language.Basic~~~zh-TW~0.0.1.0',
        'Language.Basic~~~zu-ZA~0.0.1.0',
        'Language.Fonts.Arab~~~und-ARAB~0.0.1.0',
        'Language.Fonts.Beng~~~und-BENG~0.0.1.0',
        'Language.Fonts.Cans~~~und-CANS~0.0.1.0',
        'Language.Fonts.Cher~~~und-CHER~0.0.1.0',
        'Language.Fonts.Deva~~~und-DEVA~0.0.1.0',
        'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0',
        'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0',
        'Language.Fonts.Guru~~~und-GURU~0.0.1.0',
        'Language.Fonts.Hans~~~und-HANS~0.0.1.0',
        'Language.Fonts.Hant~~~und-HANT~0.0.1.0',
        'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0',
        'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0',
        'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0',
        'Language.Fonts.Knda~~~und-KNDA~0.0.1.0',
        'Language.Fonts.Kore~~~und-KORE~0.0.1.0',
        'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0',
        'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0',
        'Language.Fonts.Orya~~~und-ORYA~0.0.1.0',
        'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0',
        'Language.Fonts.Sinh~~~und-SINH~0.0.1.0',
        'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0',
        'Language.Fonts.Taml~~~und-TAML~0.0.1.0',
        'Language.Fonts.Telu~~~und-TELU~0.0.1.0',
        'Language.Fonts.Thai~~~und-THAI~0.0.1.0',
        'Language.Handwriting~~~af-ZA~0.0.1.0',
        'Language.Handwriting~~~bs-LATN-BA~0.0.1.0',
        'Language.Handwriting~~~ca-ES~0.0.1.0',
        'Language.Handwriting~~~cs-CZ~0.0.1.0',
        'Language.Handwriting~~~cy-GB~0.0.1.0',
        'Language.Handwriting~~~da-DK~0.0.1.0',
        'Language.Handwriting~~~de-DE~0.0.1.0',
        'Language.Handwriting~~~el-GR~0.0.1.0',
        'Language.Handwriting~~~en-GB~0.0.1.0',
        'Language.Handwriting~~~en-US~0.0.1.0',
        'Language.Handwriting~~~es-ES~0.0.1.0',
        'Language.Handwriting~~~es-MX~0.0.1.0',
        'Language.Handwriting~~~eu-ES~0.0.1.0',
        'Language.Handwriting~~~fi-FI~0.0.1.0',
        'Language.Handwriting~~~fr-FR~0.0.1.0',
        'Language.Handwriting~~~ga-IE~0.0.1.0',
        'Language.Handwriting~~~gd-GB~0.0.1.0',
        'Language.Handwriting~~~gl-ES~0.0.1.0',
        'Language.Handwriting~~~hi-IN~0.0.1.0',
        'Language.Handwriting~~~hr-HR~0.0.1.0',
        'Language.Handwriting~~~id-ID~0.0.1.0',
        'Language.Handwriting~~~it-IT~0.0.1.0',
        'Language.Handwriting~~~ja-JP~0.0.1.0',
        'Language.Handwriting~~~ko-KR~0.0.1.0',
        'Language.Handwriting~~~lb-LU~0.0.1.0',
        'Language.Handwriting~~~mi-NZ~0.0.1.0',
        'Language.Handwriting~~~ms-BN~0.0.1.0',
        'Language.Handwriting~~~ms-MY~0.0.1.0',
        'Language.Handwriting~~~nb-NO~0.0.1.0',
        'Language.Handwriting~~~nl-NL~0.0.1.0',
        'Language.Handwriting~~~nn-NO~0.0.1.0',
        'Language.Handwriting~~~nso-ZA~0.0.1.0',
        'Language.Handwriting~~~pl-PL~0.0.1.0',
        'Language.Handwriting~~~pt-BR~0.0.1.0',
        'Language.Handwriting~~~pt-PT~0.0.1.0',
        'Language.Handwriting~~~rm-CH~0.0.1.0',
        'Language.Handwriting~~~ro-RO~0.0.1.0',
        'Language.Handwriting~~~ru-RU~0.0.1.0',
        'Language.Handwriting~~~rw-RW~0.0.1.0',
        'Language.Handwriting~~~sk-SK~0.0.1.0',
        'Language.Handwriting~~~sl-SI~0.0.1.0',
        'Language.Handwriting~~~sq-AL~0.0.1.0',
        'Language.Handwriting~~~sr-CYRL-RS~0.0.1.0',
        'Language.Handwriting~~~sr-LATN-RS~0.0.1.0',
        'Language.Handwriting~~~sv-SE~0.0.1.0',
        'Language.Handwriting~~~sw-KE~0.0.1.0',
        'Language.Handwriting~~~tn-ZA~0.0.1.0',
        'Language.Handwriting~~~tr-TR~0.0.1.0',
        'Language.Handwriting~~~wo-SN~0.0.1.0',
        'Language.Handwriting~~~xh-ZA~0.0.1.0',
        'Language.Handwriting~~~zh-CN~0.0.1.0',
        'Language.Handwriting~~~zh-HK~0.0.1.0',
        'Language.Handwriting~~~zh-TW~0.0.1.0',
        'Language.Handwriting~~~zu-ZA~0.0.1.0',
        'Language.OCR~~~ar-SA~0.0.1.0',
        'Language.OCR~~~bg-BG~0.0.1.0',
        'Language.OCR~~~bs-LATN-BA~0.0.1.0',
        'Language.OCR~~~cs-CZ~0.0.1.0',
        'Language.OCR~~~da-DK~0.0.1.0',
        'Language.OCR~~~de-DE~0.0.1.0',
        'Language.OCR~~~el-GR~0.0.1.0',
        'Language.OCR~~~en-GB~0.0.1.0',
        'Language.OCR~~~en-US~0.0.1.0',
        'Language.OCR~~~es-ES~0.0.1.0',
        'Language.OCR~~~es-MX~0.0.1.0',
        'Language.OCR~~~fi-FI~0.0.1.0',
        'Language.OCR~~~fr-CA~0.0.1.0',
        'Language.OCR~~~fr-FR~0.0.1.0',
        'Language.OCR~~~hr-HR~0.0.1.0',
        'Language.OCR~~~hu-HU~0.0.1.0',
        'Language.OCR~~~it-IT~0.0.1.0',
        'Language.OCR~~~ja-JP~0.0.1.0',
        'Language.OCR~~~ko-KR~0.0.1.0',
        'Language.OCR~~~nb-NO~0.0.1.0',
        'Language.OCR~~~nl-NL~0.0.1.0',
        'Language.OCR~~~pl-PL~0.0.1.0',
        'Language.OCR~~~pt-BR~0.0.1.0',
        'Language.OCR~~~pt-PT~0.0.1.0',
        'Language.OCR~~~ro-RO~0.0.1.0',
        'Language.OCR~~~ru-RU~0.0.1.0',
        'Language.OCR~~~sk-SK~0.0.1.0',
        'Language.OCR~~~sl-SI~0.0.1.0',
        'Language.OCR~~~sr-CYRL-RS~0.0.1.0',
        'Language.OCR~~~sr-LATN-RS~0.0.1.0',
        'Language.OCR~~~sv-SE~0.0.1.0',
        'Language.OCR~~~tr-TR~0.0.1.0',
        'Language.OCR~~~zh-CN~0.0.1.0',
        'Language.OCR~~~zh-HK~0.0.1.0',
        'Language.OCR~~~zh-TW~0.0.1.0',
        'Language.Speech~~~de-DE~0.0.1.0',
        'Language.Speech~~~en-AU~0.0.1.0',
        'Language.Speech~~~en-CA~0.0.1.0',
        'Language.Speech~~~en-GB~0.0.1.0',
        'Language.Speech~~~en-IN~0.0.1.0',
        'Language.Speech~~~en-US~0.0.1.0',
        'Language.Speech~~~es-ES~0.0.1.0',
        'Language.Speech~~~es-MX~0.0.1.0',
        'Language.Speech~~~fr-CA~0.0.1.0',
        'Language.Speech~~~fr-FR~0.0.1.0',
        'Language.Speech~~~it-IT~0.0.1.0',
        'Language.Speech~~~ja-JP~0.0.1.0',
        'Language.Speech~~~pt-BR~0.0.1.0',
        'Language.Speech~~~zh-CN~0.0.1.0',
        'Language.Speech~~~zh-HK~0.0.1.0',
        'Language.Speech~~~zh-TW~0.0.1.0',
        'Language.TextToSpeech~~~ar-EG~0.0.1.0',
        'Language.TextToSpeech~~~ar-SA~0.0.1.0',
        'Language.TextToSpeech~~~bg-BG~0.0.1.0',
        'Language.TextToSpeech~~~ca-ES~0.0.1.0',
        'Language.TextToSpeech~~~cs-CZ~0.0.1.0',
        'Language.TextToSpeech~~~da-DK~0.0.1.0',
        'Language.TextToSpeech~~~de-AT~0.0.1.0',
        'Language.TextToSpeech~~~de-CH~0.0.1.0',
        'Language.TextToSpeech~~~de-DE~0.0.1.0',
        'Language.TextToSpeech~~~el-GR~0.0.1.0',
        'Language.TextToSpeech~~~en-AU~0.0.1.0',
        'Language.TextToSpeech~~~en-CA~0.0.1.0',
        'Language.TextToSpeech~~~en-GB~0.0.1.0',
        'Language.TextToSpeech~~~en-IE~0.0.1.0',
        'Language.TextToSpeech~~~en-IN~0.0.1.0',
        'Language.TextToSpeech~~~en-US~0.0.1.0',
        'Language.TextToSpeech~~~es-ES~0.0.1.0',
        'Language.TextToSpeech~~~es-MX~0.0.1.0',
        'Language.TextToSpeech~~~fi-FI~0.0.1.0',
        'Language.TextToSpeech~~~fr-CA~0.0.1.0',
        'Language.TextToSpeech~~~fr-CH~0.0.1.0',
        'Language.TextToSpeech~~~fr-FR~0.0.1.0',
        'Language.TextToSpeech~~~he-IL~0.0.1.0',
        'Language.TextToSpeech~~~hi-IN~0.0.1.0',
        'Language.TextToSpeech~~~hr-HR~0.0.1.0',
        'Language.TextToSpeech~~~hu-HU~0.0.1.0',
        'Language.TextToSpeech~~~id-ID~0.0.1.0',
        'Language.TextToSpeech~~~it-IT~0.0.1.0',
        'Language.TextToSpeech~~~ja-JP~0.0.1.0',
        'Language.TextToSpeech~~~ko-KR~0.0.1.0',
        'Language.TextToSpeech~~~ms-MY~0.0.1.0',
        'Language.TextToSpeech~~~nb-NO~0.0.1.0',
        'Language.TextToSpeech~~~nl-BE~0.0.1.0',
        'Language.TextToSpeech~~~nl-NL~0.0.1.0',
        'Language.TextToSpeech~~~pl-PL~0.0.1.0',
        'Language.TextToSpeech~~~pt-BR~0.0.1.0',
        'Language.TextToSpeech~~~pt-PT~0.0.1.0',
        'Language.TextToSpeech~~~ro-RO~0.0.1.0',
        'Language.TextToSpeech~~~ru-RU~0.0.1.0',
        'Language.TextToSpeech~~~sk-SK~0.0.1.0',
        'Language.TextToSpeech~~~sl-SI~0.0.1.0',
        'Language.TextToSpeech~~~sv-SE~0.0.1.0',
        'Language.TextToSpeech~~~ta-IN~0.0.1.0',
        'Language.TextToSpeech~~~th-TH~0.0.1.0',
        'Language.TextToSpeech~~~tr-TR~0.0.1.0',
        'Language.TextToSpeech~~~vi-VN~0.0.1.0',
        'Language.TextToSpeech~~~zh-CN~0.0.1.0',
        'Language.TextToSpeech~~~zh-HK~0.0.1.0',
        'Language.TextToSpeech~~~zh-TW~0.0.1.0',
        'MathRecognizer~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Onecore.StorageManagement~~~~0.0.1.0',
        'Microsoft.WebDriver~~~~0.0.1.0',
        'Microsoft.Windows.StorageManagement~~~~0.0.1.0',
        'Msix.PackagingTool.Driver~~~~0.0.1.0',
        'NetFX3~~~~',
        'OneCoreUAP.OneSync~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'OpenSSH.Server~~~~0.0.1.0',
        'RasCMAK.Client~~~~0.0.1.0',
        'RIP.Listener~~~~0.0.1.0',
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',
        'Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0',
        'Rsat.CertificateServices.Tools~~~~0.0.1.0',
        'Rsat.DHCP.Tools~~~~0.0.1.0',
        'Rsat.Dns.Tools~~~~0.0.1.0',
        'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0',
        'Rsat.FileServices.Tools~~~~0.0.1.0',
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
        'Rsat.IPAM.Client.Tools~~~~0.0.1.0',
        'Rsat.LLDP.Tools~~~~0.0.1.0',
        'Rsat.NetworkController.Tools~~~~0.0.1.0',
        'Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0',
        'Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0',
        'Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0',
        'Rsat.ServerManager.Tools~~~~0.0.1.0',
        'Rsat.Shielded.VM.Tools~~~~0.0.1.0',
        'Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0',
        'Rsat.StorageReplica.Tools~~~~0.0.1.0',
        'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0',
        'Rsat.VolumeActivation.Tools~~~~0.0.1.0',
        'Rsat.WSUS.Tools~~~~0.0.1.0',
        'SNMP.Client~~~~0.0.1.0',
        'Tools.DeveloperMode.Core~~~~0.0.1.0',
        'Tools.DTrace.Platform~~~~0.0.1.0',
        'Tools.Graphics.DirectX~~~~0.0.1.0',
        'WMI-SNMP-Provider.Client~~~~0.0.1.0',
        'XPS.Viewer~~~~0.0.1.0')
    $Win10_1809_FODs = @('Accessibility.Braille~~~~0.0.1.0',
        'Analog.Holographic.Desktop~~~~0.0.1.0',
        'App.Support.QuickAssist~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'Hello.Face.17658~~~~0.0.1.0',
        'Hello.Face.Migration.17658~~~~0.0.1.0',
        'Language.Basic~~~af-ZA~0.0.1.0',
        'Language.Basic~~~ar-SA~0.0.1.0',
        'Language.Basic~~~as-IN~0.0.1.0',
        'Language.Basic~~~az-LATN-AZ~0.0.1.0',
        'Language.Basic~~~ba-RU~0.0.1.0',
        'Language.Basic~~~be-BY~0.0.1.0',
        'Language.Basic~~~bg-BG~0.0.1.0',
        'Language.Basic~~~bn-BD~0.0.1.0',
        'Language.Basic~~~bn-IN~0.0.1.0',
        'Language.Basic~~~bs-LATN-BA~0.0.1.0',
        'Language.Basic~~~ca-ES~0.0.1.0',
        'Language.Basic~~~cs-CZ~0.0.1.0',
        'Language.Basic~~~cy-GB~0.0.1.0',
        'Language.Basic~~~da-DK~0.0.1.0',
        'Language.Basic~~~de-DE~0.0.1.0',
        'Language.Basic~~~el-GR~0.0.1.0',
        'Language.Basic~~~en-GB~0.0.1.0',
        'Language.Basic~~~en-US~0.0.1.0',
        'Language.Basic~~~es-ES~0.0.1.0',
        'Language.Basic~~~es-MX~0.0.1.0',
        'Language.Basic~~~et-EE~0.0.1.0',
        'Language.Basic~~~eu-ES~0.0.1.0',
        'Language.Basic~~~fa-IR~0.0.1.0',
        'Language.Basic~~~fi-FI~0.0.1.0',
        'Language.Basic~~~fil-PH~0.0.1.0',
        'Language.Basic~~~fr-CA~0.0.1.0',
        'Language.Basic~~~fr-FR~0.0.1.0',
        'Language.Basic~~~ga-IE~0.0.1.0',
        'Language.Basic~~~gd-GB~0.0.1.0',
        'Language.Basic~~~gl-ES~0.0.1.0',
        'Language.Basic~~~gu-IN~0.0.1.0',
        'Language.Basic~~~ha-LATN-NG~0.0.1.0',
        'Language.Basic~~~haw-US~0.0.1.0',
        'Language.Basic~~~he-IL~0.0.1.0',
        'Language.Basic~~~hi-IN~0.0.1.0',
        'Language.Basic~~~hr-HR~0.0.1.0',
        'Language.Basic~~~hu-HU~0.0.1.0',
        'Language.Basic~~~hy-AM~0.0.1.0',
        'Language.Basic~~~id-ID~0.0.1.0',
        'Language.Basic~~~ig-NG~0.0.1.0',
        'Language.Basic~~~is-IS~0.0.1.0',
        'Language.Basic~~~it-IT~0.0.1.0',
        'Language.Basic~~~ja-JP~0.0.1.0',
        'Language.Basic~~~ka-GE~0.0.1.0',
        'Language.Basic~~~kk-KZ~0.0.1.0',
        'Language.Basic~~~kl-GL~0.0.1.0',
        'Language.Basic~~~kn-IN~0.0.1.0',
        'Language.Basic~~~ko-KR~0.0.1.0',
        'Language.Basic~~~kok-DEVA-IN~0.0.1.0',
        'Language.Basic~~~ky-KG~0.0.1.0',
        'Language.Basic~~~lb-LU~0.0.1.0',
        'Language.Basic~~~lt-LT~0.0.1.0',
        'Language.Basic~~~lv-LV~0.0.1.0',
        'Language.Basic~~~mi-NZ~0.0.1.0',
        'Language.Basic~~~ml-IN~0.0.1.0',
        'Language.Basic~~~mk-MK~0.0.1.0',
        'Language.Basic~~~mn-MN~0.0.1.0',
        'Language.Basic~~~mr-IN~0.0.1.0',
        'Language.Basic~~~ms-BN~0.0.1.0',
        'Language.Basic~~~ms-MY~0.0.1.0',
        'Language.Basic~~~mt-MT~0.0.1.0',
        'Language.Basic~~~nb-NO~0.0.1.0',
        'Language.Basic~~~ne-NP~0.0.1.0',
        'Language.Basic~~~nl-NL~0.0.1.0',
        'Language.Basic~~~nn-NO~0.0.1.0',
        'Language.Basic~~~nso-ZA~0.0.1.0',
        'Language.Basic~~~or-IN~0.0.1.0',
        'Language.Basic~~~pa-IN~0.0.1.0',
        'Language.Basic~~~pl-PL~0.0.1.0',
        'Language.Basic~~~ps-AF~0.0.1.0',
        'Language.Basic~~~pt-BR~0.0.1.0',
        'Language.Basic~~~pt-PT~0.0.1.0',
        'Language.Basic~~~rm-CH~0.0.1.0',
        'Language.Basic~~~ro-RO~0.0.1.0',
        'Language.Basic~~~ru-RU~0.0.1.0',
        'Language.Basic~~~rw-RW~0.0.1.0',
        'Language.Basic~~~sah-RU~0.0.1.0',
        'Language.Basic~~~si-LK~0.0.1.0',
        'Language.Basic~~~sk-SK~0.0.1.0',
        'Language.Basic~~~sl-SI~0.0.1.0',
        'Language.Basic~~~sq-AL~0.0.1.0',
        'Language.Basic~~~sr-CYRL-RS~0.0.1.0',
        'Language.Basic~~~sr-LATN-RS~0.0.1.0',
        'Language.Basic~~~sv-SE~0.0.1.0',
        'Language.Basic~~~sw-KE~0.0.1.0',
        'Language.Basic~~~ta-IN~0.0.1.0',
        'Language.Basic~~~te-IN~0.0.1.0',
        'Language.Basic~~~tg-CYRL-TJ~0.0.1.0',
        'Language.Basic~~~th-TH~0.0.1.0',
        'Language.Basic~~~tk-TM~0.0.1.0',
        'Language.Basic~~~tn-ZA~0.0.1.0',
        'Language.Basic~~~tr-TR~0.0.1.0',
        'Language.Basic~~~tt-RU~0.0.1.0',
        'Language.Basic~~~ug-CN~0.0.1.0',
        'Language.Basic~~~uk-UA~0.0.1.0',
        'Language.Basic~~~ur-PK~0.0.1.0',
        'Language.Basic~~~uz-LATN-UZ~0.0.1.0',
        'Language.Basic~~~vi-VN~0.0.1.0',
        'Language.Basic~~~wo-SN~0.0.1.0',
        'Language.Basic~~~xh-ZA~0.0.1.0',
        'Language.Basic~~~yo-NG~0.0.1.0',
        'Language.Basic~~~zh-CN~0.0.1.0',
        'Language.Basic~~~zh-HK~0.0.1.0',
        'Language.Basic~~~zh-TW~0.0.1.0',
        'Language.Basic~~~zu-ZA~0.0.1.0',
        'Language.Fonts.Arab~~~und-ARAB~0.0.1.0',
        'Language.Fonts.Beng~~~und-BENG~0.0.1.0',
        'Language.Fonts.Cans~~~und-CANS~0.0.1.0',
        'Language.Fonts.Cher~~~und-CHER~0.0.1.0',
        'Language.Fonts.Deva~~~und-DEVA~0.0.1.0',
        'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0',
        'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0',
        'Language.Fonts.Guru~~~und-GURU~0.0.1.0',
        'Language.Fonts.Hans~~~und-HANS~0.0.1.0',
        'Language.Fonts.Hant~~~und-HANT~0.0.1.0',
        'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0',
        'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0',
        'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0',
        'Language.Fonts.Knda~~~und-KNDA~0.0.1.0',
        'Language.Fonts.Kore~~~und-KORE~0.0.1.0',
        'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0',
        'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0',
        'Language.Fonts.Orya~~~und-ORYA~0.0.1.0',
        'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0',
        'Language.Fonts.Sinh~~~und-SINH~0.0.1.0',
        'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0',
        'Language.Fonts.Taml~~~und-TAML~0.0.1.0',
        'Language.Fonts.Telu~~~und-TELU~0.0.1.0',
        'Language.Fonts.Thai~~~und-THAI~0.0.1.0',
        'Language.Handwriting~~~af-ZA~0.0.1.0',
        'Language.Handwriting~~~bs-LATN-BA~0.0.1.0',
        'Language.Handwriting~~~ca-ES~0.0.1.0',
        'Language.Handwriting~~~cs-CZ~0.0.1.0',
        'Language.Handwriting~~~cy-GB~0.0.1.0',
        'Language.Handwriting~~~da-DK~0.0.1.0',
        'Language.Handwriting~~~de-DE~0.0.1.0',
        'Language.Handwriting~~~el-GR~0.0.1.0',
        'Language.Handwriting~~~en-GB~0.0.1.0',
        'Language.Handwriting~~~en-US~0.0.1.0',
        'Language.Handwriting~~~es-ES~0.0.1.0',
        'Language.Handwriting~~~es-MX~0.0.1.0',
        'Language.Handwriting~~~eu-ES~0.0.1.0',
        'Language.Handwriting~~~fi-FI~0.0.1.0',
        'Language.Handwriting~~~fr-FR~0.0.1.0',
        'Language.Handwriting~~~ga-IE~0.0.1.0',
        'Language.Handwriting~~~gd-GB~0.0.1.0',
        'Language.Handwriting~~~gl-ES~0.0.1.0',
        'Language.Handwriting~~~hi-IN~0.0.1.0',
        'Language.Handwriting~~~hr-HR~0.0.1.0',
        'Language.Handwriting~~~id-ID~0.0.1.0',
        'Language.Handwriting~~~it-IT~0.0.1.0',
        'Language.Handwriting~~~ja-JP~0.0.1.0',
        'Language.Handwriting~~~ko-KR~0.0.1.0',
        'Language.Handwriting~~~lb-LU~0.0.1.0',
        'Language.Handwriting~~~mi-NZ~0.0.1.0',
        'Language.Handwriting~~~ms-BN~0.0.1.0',
        'Language.Handwriting~~~ms-MY~0.0.1.0',
        'Language.Handwriting~~~nb-NO~0.0.1.0',
        'Language.Handwriting~~~nl-NL~0.0.1.0',
        'Language.Handwriting~~~nn-NO~0.0.1.0',
        'Language.Handwriting~~~nso-ZA~0.0.1.0',
        'Language.Handwriting~~~pl-PL~0.0.1.0',
        'Language.Handwriting~~~pt-BR~0.0.1.0',
        'Language.Handwriting~~~pt-PT~0.0.1.0',
        'Language.Handwriting~~~rm-CH~0.0.1.0',
        'Language.Handwriting~~~ro-RO~0.0.1.0',
        'Language.Handwriting~~~ru-RU~0.0.1.0',
        'Language.Handwriting~~~rw-RW~0.0.1.0',
        'Language.Handwriting~~~sk-SK~0.0.1.0',
        'Language.Handwriting~~~sl-SI~0.0.1.0',
        'Language.Handwriting~~~sq-AL~0.0.1.0',
        'Language.Handwriting~~~sr-CYRL-RS~0.0.1.0',
        'Language.Handwriting~~~sr-LATN-RS~0.0.1.0',
        'Language.Handwriting~~~sv-SE~0.0.1.0',
        'Language.Handwriting~~~sw-KE~0.0.1.0',
        'Language.Handwriting~~~tn-ZA~0.0.1.0',
        'Language.Handwriting~~~tr-TR~0.0.1.0',
        'Language.Handwriting~~~wo-SN~0.0.1.0',
        'Language.Handwriting~~~xh-ZA~0.0.1.0',
        'Language.Handwriting~~~zh-CN~0.0.1.0',
        'Language.Handwriting~~~zh-HK~0.0.1.0',
        'Language.Handwriting~~~zh-TW~0.0.1.0',
        'Language.Handwriting~~~zu-ZA~0.0.1.0',
        'Language.OCR~~~ar-SA~0.0.1.0',
        'Language.OCR~~~bg-BG~0.0.1.0',
        'Language.OCR~~~bs-LATN-BA~0.0.1.0',
        'Language.OCR~~~cs-CZ~0.0.1.0',
        'Language.OCR~~~da-DK~0.0.1.0',
        'Language.OCR~~~de-DE~0.0.1.0',
        'Language.OCR~~~el-GR~0.0.1.0',
        'Language.OCR~~~en-GB~0.0.1.0',
        'Language.OCR~~~en-US~0.0.1.0',
        'Language.OCR~~~es-ES~0.0.1.0',
        'Language.OCR~~~es-MX~0.0.1.0',
        'Language.OCR~~~fi-FI~0.0.1.0',
        'Language.OCR~~~fr-CA~0.0.1.0',
        'Language.OCR~~~fr-FR~0.0.1.0',
        'Language.OCR~~~hr-HR~0.0.1.0',
        'Language.OCR~~~hu-HU~0.0.1.0',
        'Language.OCR~~~it-IT~0.0.1.0',
        'Language.OCR~~~ja-JP~0.0.1.0',
        'Language.OCR~~~ko-KR~0.0.1.0',
        'Language.OCR~~~nb-NO~0.0.1.0',
        'Language.OCR~~~nl-NL~0.0.1.0',
        'Language.OCR~~~pl-PL~0.0.1.0',
        'Language.OCR~~~pt-BR~0.0.1.0',
        'Language.OCR~~~pt-PT~0.0.1.0',
        'Language.OCR~~~ro-RO~0.0.1.0',
        'Language.OCR~~~ru-RU~0.0.1.0',
        'Language.OCR~~~sk-SK~0.0.1.0',
        'Language.OCR~~~sl-SI~0.0.1.0',
        'Language.OCR~~~sr-CYRL-RS~0.0.1.0',
        'Language.OCR~~~sr-LATN-RS~0.0.1.0',
        'Language.OCR~~~sv-SE~0.0.1.0',
        'Language.OCR~~~tr-TR~0.0.1.0',
        'Language.OCR~~~zh-CN~0.0.1.0',
        'Language.OCR~~~zh-HK~0.0.1.0',
        'Language.OCR~~~zh-TW~0.0.1.0',
        'Language.Speech~~~de-DE~0.0.1.0',
        'Language.Speech~~~en-AU~0.0.1.0',
        'Language.Speech~~~en-CA~0.0.1.0',
        'Language.Speech~~~en-GB~0.0.1.0',
        'Language.Speech~~~en-IN~0.0.1.0',
        'Language.Speech~~~en-US~0.0.1.0',
        'Language.Speech~~~es-ES~0.0.1.0',
        'Language.Speech~~~es-MX~0.0.1.0',
        'Language.Speech~~~fr-CA~0.0.1.0',
        'Language.Speech~~~fr-FR~0.0.1.0',
        'Language.Speech~~~it-IT~0.0.1.0',
        'Language.Speech~~~ja-JP~0.0.1.0',
        'Language.Speech~~~pt-BR~0.0.1.0',
        'Language.Speech~~~zh-CN~0.0.1.0',
        'Language.Speech~~~zh-HK~0.0.1.0',
        'Language.Speech~~~zh-TW~0.0.1.0',
        'Language.TextToSpeech~~~ar-EG~0.0.1.0',
        'Language.TextToSpeech~~~ar-SA~0.0.1.0',
        'Language.TextToSpeech~~~bg-BG~0.0.1.0',
        'Language.TextToSpeech~~~ca-ES~0.0.1.0',
        'Language.TextToSpeech~~~cs-CZ~0.0.1.0',
        'Language.TextToSpeech~~~da-DK~0.0.1.0',
        'Language.TextToSpeech~~~de-AT~0.0.1.0',
        'Language.TextToSpeech~~~de-CH~0.0.1.0',
        'Language.TextToSpeech~~~de-DE~0.0.1.0',
        'Language.TextToSpeech~~~el-GR~0.0.1.0',
        'Language.TextToSpeech~~~en-AU~0.0.1.0',
        'Language.TextToSpeech~~~en-CA~0.0.1.0',
        'Language.TextToSpeech~~~en-GB~0.0.1.0',
        'Language.TextToSpeech~~~en-IE~0.0.1.0',
        'Language.TextToSpeech~~~en-IN~0.0.1.0',
        'Language.TextToSpeech~~~en-US~0.0.1.0',
        'Language.TextToSpeech~~~es-ES~0.0.1.0',
        'Language.TextToSpeech~~~es-MX~0.0.1.0',
        'Language.TextToSpeech~~~fi-FI~0.0.1.0',
        'Language.TextToSpeech~~~fr-CA~0.0.1.0',
        'Language.TextToSpeech~~~fr-CH~0.0.1.0',
        'Language.TextToSpeech~~~fr-FR~0.0.1.0',
        'Language.TextToSpeech~~~he-IL~0.0.1.0',
        'Language.TextToSpeech~~~hi-IN~0.0.1.0',
        'Language.TextToSpeech~~~hr-HR~0.0.1.0',
        'Language.TextToSpeech~~~hu-HU~0.0.1.0',
        'Language.TextToSpeech~~~id-ID~0.0.1.0',
        'Language.TextToSpeech~~~it-IT~0.0.1.0',
        'Language.TextToSpeech~~~ja-JP~0.0.1.0',
        'Language.TextToSpeech~~~ko-KR~0.0.1.0',
        'Language.TextToSpeech~~~ms-MY~0.0.1.0',
        'Language.TextToSpeech~~~nb-NO~0.0.1.0',
        'Language.TextToSpeech~~~nl-BE~0.0.1.0',
        'Language.TextToSpeech~~~nl-NL~0.0.1.0',
        'Language.TextToSpeech~~~pl-PL~0.0.1.0',
        'Language.TextToSpeech~~~pt-BR~0.0.1.0',
        'Language.TextToSpeech~~~pt-PT~0.0.1.0',
        'Language.TextToSpeech~~~ro-RO~0.0.1.0',
        'Language.TextToSpeech~~~ru-RU~0.0.1.0',
        'Language.TextToSpeech~~~sk-SK~0.0.1.0',
        'Language.TextToSpeech~~~sl-SI~0.0.1.0',
        'Language.TextToSpeech~~~sv-SE~0.0.1.0',
        'Language.TextToSpeech~~~ta-IN~0.0.1.0',
        'Language.TextToSpeech~~~th-TH~0.0.1.0',
        'Language.TextToSpeech~~~tr-TR~0.0.1.0',
        'Language.TextToSpeech~~~vi-VN~0.0.1.0',
        'Language.TextToSpeech~~~zh-CN~0.0.1.0',
        'Language.TextToSpeech~~~zh-HK~0.0.1.0',
        'Language.TextToSpeech~~~zh-TW~0.0.1.0',
        'MathRecognizer~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Onecore.StorageManagement~~~~0.0.1.0',
        'Microsoft.WebDriver~~~~0.0.1.0',
        'Microsoft.Windows.StorageManagement~~~~0.0.1.0',
        'Msix.PackagingTool.Driver~~~~0.0.1.0',
        'NetFX3~~~~'
        'OneCoreUAP.OneSync~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'OpenSSH.Server~~~~0.0.1.0',
        'RasCMAK.Client~~~~0.0.1.0',
        'RIP.Listener~~~~0.0.1.0',
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',
        'Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0',
        'Rsat.CertificateServices.Tools~~~~0.0.1.0',
        'Rsat.DHCP.Tools~~~~0.0.1.0',
        'Rsat.Dns.Tools~~~~0.0.1.0',
        'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0',
        'Rsat.FileServices.Tools~~~~0.0.1.0',
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
        'Rsat.IPAM.Client.Tools~~~~0.0.1.0',
        'Rsat.LLDP.Tools~~~~0.0.1.0',
        'Rsat.NetworkController.Tools~~~~0.0.1.0',
        'Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0',
        'Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0',
        'Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0',
        'Rsat.ServerManager.Tools~~~~0.0.1.0',
        'Rsat.Shielded.VM.Tools~~~~0.0.1.0',
        'Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0',
        'Rsat.StorageReplica.Tools~~~~0.0.1.0',
        'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0',
        'Rsat.VolumeActivation.Tools~~~~0.0.1.0',
        'Rsat.WSUS.Tools~~~~0.0.1.0',
        'SNMP.Client~~~~0.0.1.0',
        'Tools.DeveloperMode.Core~~~~0.0.1.0',
        'Tools.DTrace.Platform~~~~0.0.1.0',
        'Tools.Graphics.DirectX~~~~0.0.1.0',
        'WMI-SNMP-Provider.Client~~~~0.0.1.0',
        'XPS.Viewer~~~~0.0.1.0'
    )
    $Win10_1809_server_FODs = @('Accessibility.Braille~~~~0.0.1.0',
        'Analog.Holographic.Desktop~~~~0.0.1.0',
        'App.Support.QuickAssist~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'Hello.Face.17658~~~~0.0.1.0',
        'Hello.Face.Migration.17658~~~~0.0.1.0',
        'Language.Basic~~~af-ZA~0.0.1.0',
        'Language.Basic~~~ar-SA~0.0.1.0',
        'Language.Basic~~~as-IN~0.0.1.0',
        'Language.Basic~~~az-LATN-AZ~0.0.1.0',
        'Language.Basic~~~ba-RU~0.0.1.0',
        'Language.Basic~~~be-BY~0.0.1.0',
        'Language.Basic~~~bg-BG~0.0.1.0',
        'Language.Basic~~~bn-BD~0.0.1.0',
        'Language.Basic~~~bn-IN~0.0.1.0',
        'Language.Basic~~~bs-LATN-BA~0.0.1.0',
        'Language.Basic~~~ca-ES~0.0.1.0',
        'Language.Basic~~~cs-CZ~0.0.1.0',
        'Language.Basic~~~cy-GB~0.0.1.0',
        'Language.Basic~~~da-DK~0.0.1.0',
        'Language.Basic~~~de-DE~0.0.1.0',
        'Language.Basic~~~el-GR~0.0.1.0',
        'Language.Basic~~~en-GB~0.0.1.0',
        'Language.Basic~~~en-US~0.0.1.0',
        'Language.Basic~~~es-ES~0.0.1.0',
        'Language.Basic~~~es-MX~0.0.1.0',
        'Language.Basic~~~et-EE~0.0.1.0',
        'Language.Basic~~~eu-ES~0.0.1.0',
        'Language.Basic~~~fa-IR~0.0.1.0',
        'Language.Basic~~~fi-FI~0.0.1.0',
        'Language.Basic~~~fil-PH~0.0.1.0',
        'Language.Basic~~~fr-CA~0.0.1.0',
        'Language.Basic~~~fr-FR~0.0.1.0',
        'Language.Basic~~~ga-IE~0.0.1.0',
        'Language.Basic~~~gd-GB~0.0.1.0',
        'Language.Basic~~~gl-ES~0.0.1.0',
        'Language.Basic~~~gu-IN~0.0.1.0',
        'Language.Basic~~~ha-LATN-NG~0.0.1.0',
        'Language.Basic~~~haw-US~0.0.1.0',
        'Language.Basic~~~he-IL~0.0.1.0',
        'Language.Basic~~~hi-IN~0.0.1.0',
        'Language.Basic~~~hr-HR~0.0.1.0',
        'Language.Basic~~~hu-HU~0.0.1.0',
        'Language.Basic~~~hy-AM~0.0.1.0',
        'Language.Basic~~~id-ID~0.0.1.0',
        'Language.Basic~~~ig-NG~0.0.1.0',
        'Language.Basic~~~is-IS~0.0.1.0',
        'Language.Basic~~~it-IT~0.0.1.0',
        'Language.Basic~~~ja-JP~0.0.1.0',
        'Language.Basic~~~ka-GE~0.0.1.0',
        'Language.Basic~~~kk-KZ~0.0.1.0',
        'Language.Basic~~~kl-GL~0.0.1.0',
        'Language.Basic~~~kn-IN~0.0.1.0',
        'Language.Basic~~~ko-KR~0.0.1.0',
        'Language.Basic~~~kok-DEVA-IN~0.0.1.0',
        'Language.Basic~~~ky-KG~0.0.1.0',
        'Language.Basic~~~lb-LU~0.0.1.0',
        'Language.Basic~~~lt-LT~0.0.1.0',
        'Language.Basic~~~lv-LV~0.0.1.0',
        'Language.Basic~~~mi-NZ~0.0.1.0',
        'Language.Basic~~~ml-IN~0.0.1.0',
        'Language.Basic~~~mk-MK~0.0.1.0',
        'Language.Basic~~~mn-MN~0.0.1.0',
        'Language.Basic~~~mr-IN~0.0.1.0',
        'Language.Basic~~~ms-BN~0.0.1.0',
        'Language.Basic~~~ms-MY~0.0.1.0',
        'Language.Basic~~~mt-MT~0.0.1.0',
        'Language.Basic~~~nb-NO~0.0.1.0',
        'Language.Basic~~~ne-NP~0.0.1.0',
        'Language.Basic~~~nl-NL~0.0.1.0',
        'Language.Basic~~~nn-NO~0.0.1.0',
        'Language.Basic~~~nso-ZA~0.0.1.0',
        'Language.Basic~~~or-IN~0.0.1.0',
        'Language.Basic~~~pa-IN~0.0.1.0',
        'Language.Basic~~~pl-PL~0.0.1.0',
        'Language.Basic~~~ps-AF~0.0.1.0',
        'Language.Basic~~~pt-BR~0.0.1.0',
        'Language.Basic~~~pt-PT~0.0.1.0',
        'Language.Basic~~~rm-CH~0.0.1.0',
        'Language.Basic~~~ro-RO~0.0.1.0',
        'Language.Basic~~~ru-RU~0.0.1.0',
        'Language.Basic~~~rw-RW~0.0.1.0',
        'Language.Basic~~~sah-RU~0.0.1.0',
        'Language.Basic~~~si-LK~0.0.1.0',
        'Language.Basic~~~sk-SK~0.0.1.0',
        'Language.Basic~~~sl-SI~0.0.1.0',
        'Language.Basic~~~sq-AL~0.0.1.0',
        'Language.Basic~~~sr-CYRL-RS~0.0.1.0',
        'Language.Basic~~~sr-LATN-RS~0.0.1.0',
        'Language.Basic~~~sv-SE~0.0.1.0',
        'Language.Basic~~~sw-KE~0.0.1.0',
        'Language.Basic~~~ta-IN~0.0.1.0',
        'Language.Basic~~~te-IN~0.0.1.0',
        'Language.Basic~~~tg-CYRL-TJ~0.0.1.0',
        'Language.Basic~~~th-TH~0.0.1.0',
        'Language.Basic~~~tk-TM~0.0.1.0',
        'Language.Basic~~~tn-ZA~0.0.1.0',
        'Language.Basic~~~tr-TR~0.0.1.0',
        'Language.Basic~~~tt-RU~0.0.1.0',
        'Language.Basic~~~ug-CN~0.0.1.0',
        'Language.Basic~~~uk-UA~0.0.1.0',
        'Language.Basic~~~ur-PK~0.0.1.0',
        'Language.Basic~~~uz-LATN-UZ~0.0.1.0',
        'Language.Basic~~~vi-VN~0.0.1.0',
        'Language.Basic~~~wo-SN~0.0.1.0',
        'Language.Basic~~~xh-ZA~0.0.1.0',
        'Language.Basic~~~yo-NG~0.0.1.0',
        'Language.Basic~~~zh-CN~0.0.1.0',
        'Language.Basic~~~zh-HK~0.0.1.0',
        'Language.Basic~~~zh-TW~0.0.1.0',
        'Language.Basic~~~zu-ZA~0.0.1.0',
        'Language.Fonts.Arab~~~und-ARAB~0.0.1.0',
        'Language.Fonts.Beng~~~und-BENG~0.0.1.0',
        'Language.Fonts.Cans~~~und-CANS~0.0.1.0',
        'Language.Fonts.Cher~~~und-CHER~0.0.1.0',
        'Language.Fonts.Deva~~~und-DEVA~0.0.1.0',
        'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0',
        'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0',
        'Language.Fonts.Guru~~~und-GURU~0.0.1.0',
        'Language.Fonts.Hans~~~und-HANS~0.0.1.0',
        'Language.Fonts.Hant~~~und-HANT~0.0.1.0',
        'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0',
        'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0',
        'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0',
        'Language.Fonts.Knda~~~und-KNDA~0.0.1.0',
        'Language.Fonts.Kore~~~und-KORE~0.0.1.0',
        'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0',
        'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0',
        'Language.Fonts.Orya~~~und-ORYA~0.0.1.0',
        'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0',
        'Language.Fonts.Sinh~~~und-SINH~0.0.1.0',
        'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0',
        'Language.Fonts.Taml~~~und-TAML~0.0.1.0',
        'Language.Fonts.Telu~~~und-TELU~0.0.1.0',
        'Language.Fonts.Thai~~~und-THAI~0.0.1.0',
        'Language.Handwriting~~~af-ZA~0.0.1.0',
        'Language.Handwriting~~~bs-LATN-BA~0.0.1.0',
        'Language.Handwriting~~~ca-ES~0.0.1.0',
        'Language.Handwriting~~~cs-CZ~0.0.1.0',
        'Language.Handwriting~~~cy-GB~0.0.1.0',
        'Language.Handwriting~~~da-DK~0.0.1.0',
        'Language.Handwriting~~~de-DE~0.0.1.0',
        'Language.Handwriting~~~el-GR~0.0.1.0',
        'Language.Handwriting~~~en-GB~0.0.1.0',
        'Language.Handwriting~~~en-US~0.0.1.0',
        'Language.Handwriting~~~es-ES~0.0.1.0',
        'Language.Handwriting~~~es-MX~0.0.1.0',
        'Language.Handwriting~~~eu-ES~0.0.1.0',
        'Language.Handwriting~~~fi-FI~0.0.1.0',
        'Language.Handwriting~~~fr-FR~0.0.1.0',
        'Language.Handwriting~~~ga-IE~0.0.1.0',
        'Language.Handwriting~~~gd-GB~0.0.1.0',
        'Language.Handwriting~~~gl-ES~0.0.1.0',
        'Language.Handwriting~~~hi-IN~0.0.1.0',
        'Language.Handwriting~~~hr-HR~0.0.1.0',
        'Language.Handwriting~~~id-ID~0.0.1.0',
        'Language.Handwriting~~~it-IT~0.0.1.0',
        'Language.Handwriting~~~ja-JP~0.0.1.0',
        'Language.Handwriting~~~ko-KR~0.0.1.0',
        'Language.Handwriting~~~lb-LU~0.0.1.0',
        'Language.Handwriting~~~mi-NZ~0.0.1.0',
        'Language.Handwriting~~~ms-BN~0.0.1.0',
        'Language.Handwriting~~~ms-MY~0.0.1.0',
        'Language.Handwriting~~~nb-NO~0.0.1.0',
        'Language.Handwriting~~~nl-NL~0.0.1.0',
        'Language.Handwriting~~~nn-NO~0.0.1.0',
        'Language.Handwriting~~~nso-ZA~0.0.1.0',
        'Language.Handwriting~~~pl-PL~0.0.1.0',
        'Language.Handwriting~~~pt-BR~0.0.1.0',
        'Language.Handwriting~~~pt-PT~0.0.1.0',
        'Language.Handwriting~~~rm-CH~0.0.1.0',
        'Language.Handwriting~~~ro-RO~0.0.1.0',
        'Language.Handwriting~~~ru-RU~0.0.1.0',
        'Language.Handwriting~~~rw-RW~0.0.1.0',
        'Language.Handwriting~~~sk-SK~0.0.1.0',
        'Language.Handwriting~~~sl-SI~0.0.1.0',
        'Language.Handwriting~~~sq-AL~0.0.1.0',
        'Language.Handwriting~~~sr-CYRL-RS~0.0.1.0',
        'Language.Handwriting~~~sr-LATN-RS~0.0.1.0',
        'Language.Handwriting~~~sv-SE~0.0.1.0',
        'Language.Handwriting~~~sw-KE~0.0.1.0',
        'Language.Handwriting~~~tn-ZA~0.0.1.0',
        'Language.Handwriting~~~tr-TR~0.0.1.0',
        'Language.Handwriting~~~wo-SN~0.0.1.0',
        'Language.Handwriting~~~xh-ZA~0.0.1.0',
        'Language.Handwriting~~~zh-CN~0.0.1.0',
        'Language.Handwriting~~~zh-HK~0.0.1.0',
        'Language.Handwriting~~~zh-TW~0.0.1.0',
        'Language.Handwriting~~~zu-ZA~0.0.1.0',
        'Language.OCR~~~ar-SA~0.0.1.0',
        'Language.OCR~~~bg-BG~0.0.1.0',
        'Language.OCR~~~bs-LATN-BA~0.0.1.0',
        'Language.OCR~~~cs-CZ~0.0.1.0',
        'Language.OCR~~~da-DK~0.0.1.0',
        'Language.OCR~~~de-DE~0.0.1.0',
        'Language.OCR~~~el-GR~0.0.1.0',
        'Language.OCR~~~en-GB~0.0.1.0',
        'Language.OCR~~~en-US~0.0.1.0',
        'Language.OCR~~~es-ES~0.0.1.0',
        'Language.OCR~~~es-MX~0.0.1.0',
        'Language.OCR~~~fi-FI~0.0.1.0',
        'Language.OCR~~~fr-CA~0.0.1.0',
        'Language.OCR~~~fr-FR~0.0.1.0',
        'Language.OCR~~~hr-HR~0.0.1.0',
        'Language.OCR~~~hu-HU~0.0.1.0',
        'Language.OCR~~~it-IT~0.0.1.0',
        'Language.OCR~~~ja-JP~0.0.1.0',
        'Language.OCR~~~ko-KR~0.0.1.0',
        'Language.OCR~~~nb-NO~0.0.1.0',
        'Language.OCR~~~nl-NL~0.0.1.0',
        'Language.OCR~~~pl-PL~0.0.1.0',
        'Language.OCR~~~pt-BR~0.0.1.0',
        'Language.OCR~~~pt-PT~0.0.1.0',
        'Language.OCR~~~ro-RO~0.0.1.0',
        'Language.OCR~~~ru-RU~0.0.1.0',
        'Language.OCR~~~sk-SK~0.0.1.0',
        'Language.OCR~~~sl-SI~0.0.1.0',
        'Language.OCR~~~sr-CYRL-RS~0.0.1.0',
        'Language.OCR~~~sr-LATN-RS~0.0.1.0',
        'Language.OCR~~~sv-SE~0.0.1.0',
        'Language.OCR~~~tr-TR~0.0.1.0',
        'Language.OCR~~~zh-CN~0.0.1.0',
        'Language.OCR~~~zh-HK~0.0.1.0',
        'Language.OCR~~~zh-TW~0.0.1.0',
        'Language.Speech~~~de-DE~0.0.1.0',
        'Language.Speech~~~en-AU~0.0.1.0',
        'Language.Speech~~~en-CA~0.0.1.0',
        'Language.Speech~~~en-GB~0.0.1.0',
        'Language.Speech~~~en-IN~0.0.1.0',
        'Language.Speech~~~en-US~0.0.1.0',
        'Language.Speech~~~es-ES~0.0.1.0',
        'Language.Speech~~~es-MX~0.0.1.0',
        'Language.Speech~~~fr-CA~0.0.1.0',
        'Language.Speech~~~fr-FR~0.0.1.0',
        'Language.Speech~~~it-IT~0.0.1.0',
        'Language.Speech~~~ja-JP~0.0.1.0',
        'Language.Speech~~~pt-BR~0.0.1.0',
        'Language.Speech~~~zh-CN~0.0.1.0',
        'Language.Speech~~~zh-HK~0.0.1.0',
        'Language.Speech~~~zh-TW~0.0.1.0',
        'Language.TextToSpeech~~~ar-EG~0.0.1.0',
        'Language.TextToSpeech~~~ar-SA~0.0.1.0',
        'Language.TextToSpeech~~~bg-BG~0.0.1.0',
        'Language.TextToSpeech~~~ca-ES~0.0.1.0',
        'Language.TextToSpeech~~~cs-CZ~0.0.1.0',
        'Language.TextToSpeech~~~da-DK~0.0.1.0',
        'Language.TextToSpeech~~~de-AT~0.0.1.0',
        'Language.TextToSpeech~~~de-CH~0.0.1.0',
        'Language.TextToSpeech~~~de-DE~0.0.1.0',
        'Language.TextToSpeech~~~el-GR~0.0.1.0',
        'Language.TextToSpeech~~~en-AU~0.0.1.0',
        'Language.TextToSpeech~~~en-CA~0.0.1.0',
        'Language.TextToSpeech~~~en-GB~0.0.1.0',
        'Language.TextToSpeech~~~en-IE~0.0.1.0',
        'Language.TextToSpeech~~~en-IN~0.0.1.0',
        'Language.TextToSpeech~~~en-US~0.0.1.0',
        'Language.TextToSpeech~~~es-ES~0.0.1.0',
        'Language.TextToSpeech~~~es-MX~0.0.1.0',
        'Language.TextToSpeech~~~fi-FI~0.0.1.0',
        'Language.TextToSpeech~~~fr-CA~0.0.1.0',
        'Language.TextToSpeech~~~fr-CH~0.0.1.0',
        'Language.TextToSpeech~~~fr-FR~0.0.1.0',
        'Language.TextToSpeech~~~he-IL~0.0.1.0',
        'Language.TextToSpeech~~~hi-IN~0.0.1.0',
        'Language.TextToSpeech~~~hr-HR~0.0.1.0',
        'Language.TextToSpeech~~~hu-HU~0.0.1.0',
        'Language.TextToSpeech~~~id-ID~0.0.1.0',
        'Language.TextToSpeech~~~it-IT~0.0.1.0',
        'Language.TextToSpeech~~~ja-JP~0.0.1.0',
        'Language.TextToSpeech~~~ko-KR~0.0.1.0',
        'Language.TextToSpeech~~~ms-MY~0.0.1.0',
        'Language.TextToSpeech~~~nb-NO~0.0.1.0',
        'Language.TextToSpeech~~~nl-BE~0.0.1.0',
        'Language.TextToSpeech~~~nl-NL~0.0.1.0',
        'Language.TextToSpeech~~~pl-PL~0.0.1.0',
        'Language.TextToSpeech~~~pt-BR~0.0.1.0',
        'Language.TextToSpeech~~~pt-PT~0.0.1.0',
        'Language.TextToSpeech~~~ro-RO~0.0.1.0',
        'Language.TextToSpeech~~~ru-RU~0.0.1.0',
        'Language.TextToSpeech~~~sk-SK~0.0.1.0',
        'Language.TextToSpeech~~~sl-SI~0.0.1.0',
        'Language.TextToSpeech~~~sv-SE~0.0.1.0',
        'Language.TextToSpeech~~~ta-IN~0.0.1.0',
        'Language.TextToSpeech~~~th-TH~0.0.1.0',
        'Language.TextToSpeech~~~tr-TR~0.0.1.0',
        'Language.TextToSpeech~~~vi-VN~0.0.1.0',
        'Language.TextToSpeech~~~zh-CN~0.0.1.0',
        'Language.TextToSpeech~~~zh-HK~0.0.1.0',
        'Language.TextToSpeech~~~zh-TW~0.0.1.0',
        'MathRecognizer~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Onecore.StorageManagement~~~~0.0.1.0',
        'Microsoft.WebDriver~~~~0.0.1.0',
        'Microsoft.Windows.StorageManagement~~~~0.0.1.0',
        'Msix.PackagingTool.Driver~~~~0.0.1.0',
        'NetFX3~~~~'
        'OneCoreUAP.OneSync~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'OpenSSH.Server~~~~0.0.1.0',
        'RasCMAK.Client~~~~0.0.1.0',
        'RIP.Listener~~~~0.0.1.0',
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',
        'Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0',
        'Rsat.CertificateServices.Tools~~~~0.0.1.0',
        'Rsat.DHCP.Tools~~~~0.0.1.0',
        'Rsat.Dns.Tools~~~~0.0.1.0',
        'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0',
        'Rsat.FileServices.Tools~~~~0.0.1.0',
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
        'Rsat.IPAM.Client.Tools~~~~0.0.1.0',
        'Rsat.LLDP.Tools~~~~0.0.1.0',
        'Rsat.NetworkController.Tools~~~~0.0.1.0',
        'Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0',
        'Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0',
        'Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0',
        'Rsat.ServerManager.Tools~~~~0.0.1.0',
        'Rsat.Shielded.VM.Tools~~~~0.0.1.0',
        'Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0',
        'Rsat.StorageReplica.Tools~~~~0.0.1.0',
        'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0',
        'Rsat.VolumeActivation.Tools~~~~0.0.1.0',
        'Rsat.WSUS.Tools~~~~0.0.1.0',
        'ServerCore.AppCompatibility~~~~0.0.1.0',
        'SNMP.Client~~~~0.0.1.0',
        'Tools.DeveloperMode.Core~~~~0.0.1.0',
        'Tools.DTrace.Platform~~~~0.0.1.0',
        'Tools.Graphics.DirectX~~~~0.0.1.0',
        'WMI-SNMP-Provider.Client~~~~0.0.1.0',
        'XPS.Viewer~~~~0.0.1.0'
    )
    $Win10_2004_FODs = @('Accessibility.Braille~~~~0.0.1.0',
        'Analog.Holographic.Desktop~~~~0.0.1.0',
        'App.StepsRecorder~~~~0.0.1.0',
        'App.Support.QuickAssist~~~~0.0.1.0',
        'App.WirelessDisplay.Connect~~~~0.0.1.0',
        'Browser.InternetExplorer~~~~0.0.11.0',
        'DirectX.Configuration.Database~~~~0.0.1.0',
        'Hello.Face.18967~~~~0.0.1.0',
        'Hello.Face.Migration.18967~~~~0.0.1.0',
        'Language.Basic~~~af-ZA~0.0.1.0',
        'Language.Basic~~~ar-SA~0.0.1.0',
        'Language.Basic~~~as-IN~0.0.1.0',
        'Language.Basic~~~az-LATN-AZ~0.0.1.0',
        'Language.Basic~~~ba-RU~0.0.1.0',
        'Language.Basic~~~be-BY~0.0.1.0',
        'Language.Basic~~~bg-BG~0.0.1.0',
        'Language.Basic~~~bn-BD~0.0.1.0',
        'Language.Basic~~~bn-IN~0.0.1.0',
        'Language.Basic~~~bs-LATN-BA~0.0.1.0',
        'Language.Basic~~~ca-ES~0.0.1.0',
        'Language.Basic~~~cs-CZ~0.0.1.0',
        'Language.Basic~~~cy-GB~0.0.1.0',
        'Language.Basic~~~da-DK~0.0.1.0',
        'Language.Basic~~~de-CH~0.0.1.0',
        'Language.Basic~~~de-DE~0.0.1.0',
        'Language.Basic~~~el-GR~0.0.1.0',
        'Language.Basic~~~en-AU~0.0.1.0',
        'Language.Basic~~~en-CA~0.0.1.0',
        'Language.Basic~~~en-GB~0.0.1.0',
        'Language.Basic~~~en-IN~0.0.1.0',
        'Language.Basic~~~en-US~0.0.1.0',
        'Language.Basic~~~es-ES~0.0.1.0',
        'Language.Basic~~~es-MX~0.0.1.0',
        'Language.Basic~~~es-US~0.0.1.0',
        'Language.Basic~~~et-EE~0.0.1.0',
        'Language.Basic~~~eu-ES~0.0.1.0',
        'Language.Basic~~~fa-IR~0.0.1.0',
        'Language.Basic~~~fi-FI~0.0.1.0',
        'Language.Basic~~~fil-PH~0.0.1.0',
        'Language.Basic~~~fr-BE~0.0.1.0',
        'Language.Basic~~~fr-CA~0.0.1.0',
        'Language.Basic~~~fr-CH~0.0.1.0',
        'Language.Basic~~~fr-FR~0.0.1.0',
        'Language.Basic~~~ga-IE~0.0.1.0',
        'Language.Basic~~~gd-GB~0.0.1.0',
        'Language.Basic~~~gl-ES~0.0.1.0',
        'Language.Basic~~~gu-IN~0.0.1.0',
        'Language.Basic~~~ha-LATN-NG~0.0.1.0',
        'Language.Basic~~~haw-US~0.0.1.0',
        'Language.Basic~~~he-IL~0.0.1.0',
        'Language.Basic~~~hi-IN~0.0.1.0',
        'Language.Basic~~~hr-HR~0.0.1.0',
        'Language.Basic~~~hu-HU~0.0.1.0',
        'Language.Basic~~~hy-AM~0.0.1.0',
        'Language.Basic~~~id-ID~0.0.1.0',
        'Language.Basic~~~ig-NG~0.0.1.0',
        'Language.Basic~~~is-IS~0.0.1.0',
        'Language.Basic~~~it-IT~0.0.1.0',
        'Language.Basic~~~ja-JP~0.0.1.0',
        'Language.Basic~~~ka-GE~0.0.1.0',
        'Language.Basic~~~kk-KZ~0.0.1.0',
        'Language.Basic~~~kl-GL~0.0.1.0',
        'Language.Basic~~~kn-IN~0.0.1.0',
        'Language.Basic~~~ko-KR~0.0.1.0',
        'Language.Basic~~~kok-DEVA-IN~0.0.1.0',
        'Language.Basic~~~ky-KG~0.0.1.0',
        'Language.Basic~~~lb-LU~0.0.1.0',
        'Language.Basic~~~lt-LT~0.0.1.0',
        'Language.Basic~~~lv-LV~0.0.1.0',
        'Language.Basic~~~mi-NZ~0.0.1.0',
        'Language.Basic~~~mk-MK~0.0.1.0',
        'Language.Basic~~~ml-IN~0.0.1.0',
        'Language.Basic~~~mn-MN~0.0.1.0',
        'Language.Basic~~~mr-IN~0.0.1.0',
        'Language.Basic~~~ms-BN~0.0.1.0',
        'Language.Basic~~~ms-MY~0.0.1.0',
        'Language.Basic~~~mt-MT~0.0.1.0',
        'Language.Basic~~~nb-NO~0.0.1.0',
        'Language.Basic~~~ne-NP~0.0.1.0',
        'Language.Basic~~~nl-NL~0.0.1.0',
        'Language.Basic~~~nn-NO~0.0.1.0',
        'Language.Basic~~~nso-ZA~0.0.1.0',
        'Language.Basic~~~or-IN~0.0.1.0',
        'Language.Basic~~~pa-IN~0.0.1.0',
        'Language.Basic~~~pl-PL~0.0.1.0',
        'Language.Basic~~~ps-AF~0.0.1.0',
        'Language.Basic~~~pt-BR~0.0.1.0',
        'Language.Basic~~~pt-PT~0.0.1.0',
        'Language.Basic~~~rm-CH~0.0.1.0',
        'Language.Basic~~~ro-RO~0.0.1.0',
        'Language.Basic~~~ru-RU~0.0.1.0',
        'Language.Basic~~~rw-RW~0.0.1.0',
        'Language.Basic~~~sah-RU~0.0.1.0',
        'Language.Basic~~~si-LK~0.0.1.0',
        'Language.Basic~~~sk-SK~0.0.1.0',
        'Language.Basic~~~sl-SI~0.0.1.0',
        'Language.Basic~~~sq-AL~0.0.1.0',
        'Language.Basic~~~sr-CYRL-RS~0.0.1.0',
        'Language.Basic~~~sr-LATN-RS~0.0.1.0',
        'Language.Basic~~~sv-SE~0.0.1.0',
        'Language.Basic~~~sw-KE~0.0.1.0',
        'Language.Basic~~~ta-IN~0.0.1.0',
        'Language.Basic~~~te-IN~0.0.1.0',
        'Language.Basic~~~tg-CYRL-TJ~0.0.1.0',
        'Language.Basic~~~th-TH~0.0.1.0',
        'Language.Basic~~~tk-TM~0.0.1.0',
        'Language.Basic~~~tn-ZA~0.0.1.0',
        'Language.Basic~~~tr-TR~0.0.1.0',
        'Language.Basic~~~tt-RU~0.0.1.0',
        'Language.Basic~~~ug-CN~0.0.1.0',
        'Language.Basic~~~uk-UA~0.0.1.0',
        'Language.Basic~~~ur-PK~0.0.1.0',
        'Language.Basic~~~uz-LATN-UZ~0.0.1.0',
        'Language.Basic~~~vi-VN~0.0.1.0',
        'Language.Basic~~~wo-SN~0.0.1.0',
        'Language.Basic~~~xh-ZA~0.0.1.0',
        'Language.Basic~~~yo-NG~0.0.1.0',
        'Language.Basic~~~zh-CN~0.0.1.0',
        'Language.Basic~~~zh-HK~0.0.1.0',
        'Language.Basic~~~zh-TW~0.0.1.0',
        'Language.Basic~~~zu-ZA~0.0.1.0',
        'Language.Fonts.Arab~~~und-ARAB~0.0.1.0',
        'Language.Fonts.Beng~~~und-BENG~0.0.1.0',
        'Language.Fonts.Cans~~~und-CANS~0.0.1.0',
        'Language.Fonts.Cher~~~und-CHER~0.0.1.0',
        'Language.Fonts.Deva~~~und-DEVA~0.0.1.0',
        'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0',
        'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0',
        'Language.Fonts.Guru~~~und-GURU~0.0.1.0',
        'Language.Fonts.Hans~~~und-HANS~0.0.1.0',
        'Language.Fonts.Hant~~~und-HANT~0.0.1.0',
        'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0',
        'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0',
        'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0',
        'Language.Fonts.Knda~~~und-KNDA~0.0.1.0',
        'Language.Fonts.Kore~~~und-KORE~0.0.1.0',
        'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0',
        'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0',
        'Language.Fonts.Orya~~~und-ORYA~0.0.1.0',
        'Language.Fonts.PanEuropeanSupplementalFonts~~~~0.0.1.0',
        'Language.Fonts.Sinh~~~und-SINH~0.0.1.0',
        'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0',
        'Language.Fonts.Taml~~~und-TAML~0.0.1.0',
        'Language.Fonts.Telu~~~und-TELU~0.0.1.0',
        'Language.Fonts.Thai~~~und-THAI~0.0.1.0',
        'Language.Handwriting~~~af-ZA~0.0.1.0',
        'Language.Handwriting~~~bs-LATN-BA~0.0.1.0',
        'Language.Handwriting~~~ca-ES~0.0.1.0',
        'Language.Handwriting~~~cs-CZ~0.0.1.0',
        'Language.Handwriting~~~cy-GB~0.0.1.0',
        'Language.Handwriting~~~da-DK~0.0.1.0',
        'Language.Handwriting~~~de-DE~0.0.1.0',
        'Language.Handwriting~~~el-GR~0.0.1.0',
        'Language.Handwriting~~~en-GB~0.0.1.0',
        'Language.Handwriting~~~en-US~0.0.1.0',
        'Language.Handwriting~~~es-ES~0.0.1.0',
        'Language.Handwriting~~~es-MX~0.0.1.0',
        'Language.Handwriting~~~eu-ES~0.0.1.0',
        'Language.Handwriting~~~fi-FI~0.0.1.0',
        'Language.Handwriting~~~fr-FR~0.0.1.0',
        'Language.Handwriting~~~ga-IE~0.0.1.0',
        'Language.Handwriting~~~gd-GB~0.0.1.0',
        'Language.Handwriting~~~gl-ES~0.0.1.0',
        'Language.Handwriting~~~hi-IN~0.0.1.0',
        'Language.Handwriting~~~hr-HR~0.0.1.0',
        'Language.Handwriting~~~id-ID~0.0.1.0',
        'Language.Handwriting~~~it-IT~0.0.1.0',
        'Language.Handwriting~~~ja-JP~0.0.1.0',
        'Language.Handwriting~~~ko-KR~0.0.1.0',
        'Language.Handwriting~~~lb-LU~0.0.1.0',
        'Language.Handwriting~~~mi-NZ~0.0.1.0',
        'Language.Handwriting~~~ms-BN~0.0.1.0',
        'Language.Handwriting~~~ms-MY~0.0.1.0',
        'Language.Handwriting~~~nb-NO~0.0.1.0',
        'Language.Handwriting~~~nl-NL~0.0.1.0',
        'Language.Handwriting~~~nn-NO~0.0.1.0',
        'Language.Handwriting~~~nso-ZA~0.0.1.0',
        'Language.Handwriting~~~pl-PL~0.0.1.0',
        'Language.Handwriting~~~pt-BR~0.0.1.0',
        'Language.Handwriting~~~pt-PT~0.0.1.0',
        'Language.Handwriting~~~rm-CH~0.0.1.0',
        'Language.Handwriting~~~ro-RO~0.0.1.0',
        'Language.Handwriting~~~ru-RU~0.0.1.0',
        'Language.Handwriting~~~rw-RW~0.0.1.0',
        'Language.Handwriting~~~sk-SK~0.0.1.0',
        'Language.Handwriting~~~sl-SI~0.0.1.0',
        'Language.Handwriting~~~sq-AL~0.0.1.0',
        'Language.Handwriting~~~sr-CYRL-RS~0.0.1.0',
        'Language.Handwriting~~~sr-LATN-RS~0.0.1.0',
        'Language.Handwriting~~~sv-SE~0.0.1.0',
        'Language.Handwriting~~~sw-KE~0.0.1.0',
        'Language.Handwriting~~~tn-ZA~0.0.1.0',
        'Language.Handwriting~~~tr-TR~0.0.1.0',
        'Language.Handwriting~~~wo-SN~0.0.1.0',
        'Language.Handwriting~~~xh-ZA~0.0.1.0',
        'Language.Handwriting~~~zh-CN~0.0.1.0',
        'Language.Handwriting~~~zh-HK~0.0.1.0',
        'Language.Handwriting~~~zh-TW~0.0.1.0',
        'Language.Handwriting~~~zu-ZA~0.0.1.0',
        'Language.OCR~~~ar-SA~0.0.1.0',
        'Language.OCR~~~bg-BG~0.0.1.0',
        'Language.OCR~~~bs-LATN-BA~0.0.1.0',
        'Language.OCR~~~cs-CZ~0.0.1.0',
        'Language.OCR~~~da-DK~0.0.1.0',
        'Language.OCR~~~de-DE~0.0.1.0',
        'Language.OCR~~~el-GR~0.0.1.0',
        'Language.OCR~~~en-GB~0.0.1.0',
        'Language.OCR~~~en-US~0.0.1.0',
        'Language.OCR~~~es-ES~0.0.1.0',
        'Language.OCR~~~es-MX~0.0.1.0',
        'Language.OCR~~~fi-FI~0.0.1.0',
        'Language.OCR~~~fr-CA~0.0.1.0',
        'Language.OCR~~~fr-FR~0.0.1.0',
        'Language.OCR~~~hr-HR~0.0.1.0',
        'Language.OCR~~~hu-HU~0.0.1.0',
        'Language.OCR~~~it-IT~0.0.1.0',
        'Language.OCR~~~ja-JP~0.0.1.0',
        'Language.OCR~~~ko-KR~0.0.1.0',
        'Language.OCR~~~nb-NO~0.0.1.0',
        'Language.OCR~~~nl-NL~0.0.1.0',
        'Language.OCR~~~pl-PL~0.0.1.0',
        'Language.OCR~~~pt-BR~0.0.1.0',
        'Language.OCR~~~pt-PT~0.0.1.0',
        'Language.OCR~~~ro-RO~0.0.1.0',
        'Language.OCR~~~ru-RU~0.0.1.0',
        'Language.OCR~~~sk-SK~0.0.1.0',
        'Language.OCR~~~sl-SI~0.0.1.0',
        'Language.OCR~~~sr-CYRL-RS~0.0.1.0',
        'Language.OCR~~~sr-LATN-RS~0.0.1.0',
        'Language.OCR~~~sv-SE~0.0.1.0',
        'Language.OCR~~~tr-TR~0.0.1.0',
        'Language.OCR~~~zh-CN~0.0.1.0',
        'Language.OCR~~~zh-HK~0.0.1.0',
        'Language.OCR~~~zh-TW~0.0.1.0',
        'Language.Speech~~~da-DK~0.0.1.0',
        'Language.Speech~~~de-DE~0.0.1.0',
        'Language.Speech~~~en-AU~0.0.1.0',
        'Language.Speech~~~en-CA~0.0.1.0',
        'Language.Speech~~~en-GB~0.0.1.0',
        'Language.Speech~~~en-IN~0.0.1.0',
        'Language.Speech~~~en-US~0.0.1.0',
        'Language.Speech~~~es-ES~0.0.1.0',
        'Language.Speech~~~es-MX~0.0.1.0',
        'Language.Speech~~~fr-CA~0.0.1.0',
        'Language.Speech~~~fr-FR~0.0.1.0',
        'Language.Speech~~~it-IT~0.0.1.0',
        'Language.Speech~~~ja-JP~0.0.1.0',
        'Language.Speech~~~pt-BR~0.0.1.0',
        'Language.Speech~~~zh-CN~0.0.1.0',
        'Language.Speech~~~zh-HK~0.0.1.0',
        'Language.Speech~~~zh-TW~0.0.1.0',
        'Language.TextToSpeech~~~ar-EG~0.0.1.0',
        'Language.TextToSpeech~~~ar-SA~0.0.1.0',
        'Language.TextToSpeech~~~bg-BG~0.0.1.0',
        'Language.TextToSpeech~~~ca-ES~0.0.1.0',
        'Language.TextToSpeech~~~cs-CZ~0.0.1.0',
        'Language.TextToSpeech~~~da-DK~0.0.1.0',
        'Language.TextToSpeech~~~de-AT~0.0.1.0',
        'Language.TextToSpeech~~~de-CH~0.0.1.0',
        'Language.TextToSpeech~~~de-DE~0.0.1.0',
        'Language.TextToSpeech~~~el-GR~0.0.1.0',
        'Language.TextToSpeech~~~en-AU~0.0.1.0',
        'Language.TextToSpeech~~~en-CA~0.0.1.0',
        'Language.TextToSpeech~~~en-GB~0.0.1.0',
        'Language.TextToSpeech~~~en-IE~0.0.1.0',
        'Language.TextToSpeech~~~en-IN~0.0.1.0',
        'Language.TextToSpeech~~~en-US~0.0.1.0',
        'Language.TextToSpeech~~~es-ES~0.0.1.0',
        'Language.TextToSpeech~~~es-MX~0.0.1.0',
        'Language.TextToSpeech~~~fi-FI~0.0.1.0',
        'Language.TextToSpeech~~~fr-CA~0.0.1.0',
        'Language.TextToSpeech~~~fr-CH~0.0.1.0',
        'Language.TextToSpeech~~~fr-FR~0.0.1.0',
        'Language.TextToSpeech~~~he-IL~0.0.1.0',
        'Language.TextToSpeech~~~hi-IN~0.0.1.0',
        'Language.TextToSpeech~~~hr-HR~0.0.1.0',
        'Language.TextToSpeech~~~hu-HU~0.0.1.0',
        'Language.TextToSpeech~~~id-ID~0.0.1.0',
        'Language.TextToSpeech~~~it-IT~0.0.1.0',
        'Language.TextToSpeech~~~ja-JP~0.0.1.0',
        'Language.TextToSpeech~~~ko-KR~0.0.1.0',
        'Language.TextToSpeech~~~ms-MY~0.0.1.0',
        'Language.TextToSpeech~~~nb-NO~0.0.1.0',
        'Language.TextToSpeech~~~nl-BE~0.0.1.0',
        'Language.TextToSpeech~~~nl-NL~0.0.1.0',
        'Language.TextToSpeech~~~pl-PL~0.0.1.0',
        'Language.TextToSpeech~~~pt-BR~0.0.1.0',
        'Language.TextToSpeech~~~pt-PT~0.0.1.0',
        'Language.TextToSpeech~~~ro-RO~0.0.1.0',
        'Language.TextToSpeech~~~ru-RU~0.0.1.0',
        'Language.TextToSpeech~~~sk-SK~0.0.1.0',
        'Language.TextToSpeech~~~sl-SI~0.0.1.0',
        'Language.TextToSpeech~~~sv-SE~0.0.1.0',
        'Language.TextToSpeech~~~ta-IN~0.0.1.0',
        'Language.TextToSpeech~~~th-TH~0.0.1.0',
        'Language.TextToSpeech~~~tr-TR~0.0.1.0',
        'Language.TextToSpeech~~~vi-VN~0.0.1.0',
        'Language.TextToSpeech~~~zh-CN~0.0.1.0',
        'Language.TextToSpeech~~~zh-HK~0.0.1.0',
        'Language.TextToSpeech~~~zh-TW~0.0.1.0',
        'MathRecognizer~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0',
        'Microsoft.Onecore.StorageManagement~~~~0.0.1.0',
        'Microsoft.WebDriver~~~~0.0.1.0',
        'Microsoft.Windows.MSPaint~~~~0.0.1.0',
        'Microsoft.Windows.Notepad~~~~0.0.1.0',
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',
        'Microsoft.Windows.StorageManagement~~~~0.0.1.0',
        'Microsoft.Windows.WordPad~~~~0.0.1.0',
        'Msix.PackagingTool.Driver~~~~0.0.1.0',
        'NetFX3~~~~',
        'Network.Irda~~~~0.0.1.0',
        'OneCoreUAP.OneSync~~~~0.0.1.0',
        'OpenSSH.Client~~~~0.0.1.0',
        'OpenSSH.Server~~~~0.0.1.0',
        'Print.Fax.Scan~~~~0.0.1.0',
        'Print.Management.Console~~~~0.0.1.0',
        'RasCMAK.Client~~~~0.0.1.0',
        'RIP.Listener~~~~0.0.1.0',
        'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0',
        'Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0',
        'Rsat.CertificateServices.Tools~~~~0.0.1.0',
        'Rsat.DHCP.Tools~~~~0.0.1.0',
        'Rsat.Dns.Tools~~~~0.0.1.0',
        'Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0',
        'Rsat.FileServices.Tools~~~~0.0.1.0',
        'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0',
        'Rsat.IPAM.Client.Tools~~~~0.0.1.0',
        'Rsat.LLDP.Tools~~~~0.0.1.0',
        'Rsat.NetworkController.Tools~~~~0.0.1.0',
        'Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0',
        'Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0',
        'Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0',
        'Rsat.ServerManager.Tools~~~~0.0.1.0',
        'Rsat.Shielded.VM.Tools~~~~0.0.1.0',
        'Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0',
        'Rsat.StorageReplica.Tools~~~~0.0.1.0',
        'Rsat.SystemInsights.Management.Tools~~~~0.0.1.0',
        'Rsat.VolumeActivation.Tools~~~~0.0.1.0',
        'Rsat.WSUS.Tools~~~~0.0.1.0',
        'SNMP.Client~~~~0.0.1.0',
        'Tools.DeveloperMode.Core~~~~0.0.1.0',
        'Tools.Graphics.DirectX~~~~0.0.1.0',
        'Windows.Client.ShellComponents~~~~0.0.1.0',
        'Windows.Desktop.EMS-SAC.Tools~~~~0.0.1.0',
        'WMI-SNMP-Provider.Client~~~~0.0.1.0',
        'XPS.Viewer~~~~0.0.1.0')


    If ($Winver -eq '2004') { $items = ($Win10_2004_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
    If ($Winver -eq '1909') { $items = ($Win10_1909_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
    If ($Winver -eq '1903') { $items = ($Win10_1903_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
    If ($Winver -eq '1809') {
        if ($WinOS -eq 'Windows 10') { $items = ($Win10_1809_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
        if ($WinOS -eq 'Windows Server') { $items = ($Win10_1809_server_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
    }

    #(Get-ChildItem -path $LPSourceFolder | Select-Object -Property Name | Out-GridView -title "Select Local Experience Packs" -PassThru)

    if ($WinOS -eq 'Windows 11') {
        $items = (Get-ChildItem -Path "$global:workdir\imports\fods\Windows 11\$winver" | Select-Object -Property Name | Out-GridView -Title 'Select Featres' -PassThru)
        foreach ($item in $items) { $WPFCustomLBFOD.Items.Add($item.name) }
    } else {

        foreach ($item in $items) { $WPFCustomLBFOD.Items.Add($item) }
    }
}

#Function to apply the selected Langauge Packs to the mounted WIM
<#
.SYNOPSIS
    Applies selected language packs to the mounted WIM image.

.DESCRIPTION
    Injects language pack (.cab) files that were previously selected and added to the form listbox
    into the currently mounted WIM image. Uses Add-WindowsPackage to apply each language pack.
    Normalizes Windows 10 version numbers (20H2, 21H1, 2009, 21H2, 22H2 map to 2004).
    Supports demo mode for testing without actual injection.
    Logs all operations and handles errors appropriately.

.EXAMPLE
    Install-LanguagePacks
    Applies all language packs listed in $WPFCustomLBLangPacks to the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Add-WindowsPackage PowerShell cmdlet (DISM module)
    Source path: imports\Lang\{WinOS}\{version}\LanguagePacks\
    Mount point: Retrieved from $WPFMISMountTextBox
    Demo mode: When $demomode is $true, shows what would be applied without actual injection

.OUTPUTS
    None. Logs progress and results via Update-Log function.
#>
Function Install-LanguagePacks {
    Update-Log -data 'Applying Language Packs...' -Class Information

    $WinOS = Get-WindowsType
    $Winver = Get-WinVersionNumber

    if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }

    $mountdir = $WPFMISMountTextBox.text

    $LPSourceFolder = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\LanguagePacks\'
    $items = $WPFCustomLBLangPacks.items

    foreach ($item in $items) {
        $source = $LPSourceFolder + $item

        $text = 'Applying ' + $item
        Update-Log -Data $text -Class Information

        try {

            if ($demomode -eq $true) {
                $string = 'Demo mode active - not applying ' + $source
                Update-Log -data $string -Class Warning
            } else {
                Add-WindowsPackage -PackagePath $source -Path $mountdir -ErrorAction Stop | Out-Null
                Update-Log -Data 'Injection Successful' -Class Information
            }

        } catch {
            Update-Log -Data 'Failed to inject Language Pack' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

    }
    Update-Log -Data 'Language Pack injections complete' -Class Information
}

<#
.SYNOPSIS
    Applies selected Local Experience Packs to the mounted WIM image.

.DESCRIPTION
    Injects Local Experience Pack (.appx) files with their associated license files (.xml)
    that were previously selected and added to the form listbox into the currently mounted WIM image.
    Uses Add-ProvisionedAppxPackage to apply each LXP with its license file.
    Normalizes Windows 10 version numbers (20H2, 21H1, 2009, 21H2, 22H2 map to 2004).
    Logs all operations and handles errors appropriately.

.EXAMPLE
    Install-LocalExperiencePack
    Applies all Local Experience Packs listed in $WPFCustomLBLEP to the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Add-ProvisionedAppxPackage PowerShell cmdlet (DISM module)
    Source path: imports\Lang\{WinOS}\{version}\localexperiencepack\
    Each LXP folder must contain: *.appx and *.xml (license) files
    Mount point: Retrieved from $WPFMISMountTextBox

.OUTPUTS
    None. Logs progress and results via Update-Log function.
#>
Function Install-LocalExperiencePack {
    Update-Log -data 'Applying Local Experience Packs...' -Class Information

    $mountdir = $WPFMISMountTextBox.text

    $WinOS = Get-WindowsType
    $Winver = Get-WinVersionNumber

    if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }

    $LPSourceFolder = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\localexperiencepack\'
    $items = $WPFCustomLBLEP.items

    foreach ($item in $items) {
        $source = $LPSourceFolder + $item
        $license = Get-Item -Path $source\*.xml
        $file = Get-Item -Path $source\*.appx
        $text = 'Applying ' + $item
        Update-Log -Data $text -Class Information
        try {
            Add-ProvisionedAppxPackage -PackagePath $file -LicensePath $license -Path $mountdir -ErrorAction Stop | Out-Null
            Update-Log -Data 'Injection Successful' -Class Information
        } catch {
            Update-Log -data 'Failed to apply Local Experience Pack' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }
    }
    Update-Log -Data 'Local Experience Pack injections complete' -Class Information
}

<#
.SYNOPSIS
    Applies selected Features On Demand to the mounted WIM image.

.DESCRIPTION
    Injects Windows Features On Demand (FOD) capabilities that were previously selected and added
    to the form listbox into the currently mounted WIM image.
    Uses Add-WindowsCapability to apply each FOD with the specified source location.
    Normalizes Windows 10 version numbers (20H2, 21H1, 2009, 21H2, 22H2 map to 2004).
    Logs all operations and handles errors appropriately.

.EXAMPLE
    Install-FeaturesOnDemand
    Applies all Features On Demand listed in $WPFCustomLBFOD to the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Add-WindowsCapability PowerShell cmdlet (DISM module)
    Source path: imports\FODs\{WinOS}\{version}\
    Mount point: Retrieved from $WPFMISMountTextBox
    FOD capabilities use standardized naming (e.g., 'Browser.InternetExplorer~~~~0.0.11.0')

.OUTPUTS
    None. Logs progress and results via Update-Log function.
#>
Function Install-FeaturesOnDemand {
    Update-Log -data 'Applying Features On Demand...' -Class Information

    $mountdir = $WPFMISMountTextBox.text

    $WinOS = Get-WindowsType
    $Winver = Get-WinVersionNumber

    if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }


    $FODsource = $global:workdir + '\imports\FODs\' + $winOS + '\' + $Winver + '\'
    $items = $WPFCustomLBFOD.items

    foreach ($item in $items) {
        $text = 'Applying ' + $item
        Update-Log -Data $text -Class Information

        try {
            Add-WindowsCapability -Path $mountdir -Name $item -Source $FODsource -ErrorAction Stop | Out-Null
            Update-Log -Data 'Injection Successful' -Class Information
        } catch {
            Update-Log -data 'Failed to apply Feature On Demand' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }


    }
    Update-Log -Data 'Feature on Demand injections complete' -Class Information
}

<#
.SYNOPSIS
    Imports language pack files into the application's import directory structure.

.DESCRIPTION
    Copies language pack (.cab) files from a source location into the application's organized
    import directory structure (imports\Lang\{WinOS}\{version}\LanguagePacks\).
    Creates the destination directory structure if it does not exist.
    Handles version normalization: version 1903 is mapped to 1909 (same packages).
    Supports batch importing of multiple language packs selected in the form listbox.

.PARAMETER Winver
    The Windows version for which the language packs are being imported (e.g., '22H2', '23H2', '2004', '1903', '1909').

.PARAMETER LPSourceFolder
    The source folder path containing the language pack files to be imported.

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Import-LanguagePacks -Winver '22H2' -LPSourceFolder 'D:\LanguagePacks\' -WinOS 'Windows 10'
    Imports all language packs from D:\LanguagePacks\ to the local import directory.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Write access to $global:workdir\imports\ directory
    Items to import: Retrieved from $WPFImportOtherLBList listbox
    Version mapping: 1903 → 1909 (Windows 10 versions that use same packages)
    Destination: $global:workdir\imports\Lang\{WinOS}\{version}\LanguagePacks\

.OUTPUTS
    None. Creates directory structure and copies files. Logs all operations via Update-Log function.
#>
Function Import-LanguagePacks($Winver, $LPSourceFolder, $WinOS) {
    Update-Log -Data 'Importing Language Packs...' -Class Information

    #Note To Donna - Make a step that checks if $winver -eq 1903, and if so, set $winver to 1909
    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$winver\LanguagePacks) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\LanguagePacks'
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\Lang\$WinOS\$winver -Name LanguagePacks -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }

    $items = $WPFImportOtherLBList.items
    foreach ($item in $items) {
        $source = $LPSourceFolder + $item
        $text = 'Importing ' + $item
        Update-Log -Data $text -Class Information
        Copy-Item $source -Destination $global:workdir\imports\Lang\$WinOS\$Winver\LanguagePacks -Force
    }
    Update-Log -Data 'Importation Complete' -Class Information
}

<#
.SYNOPSIS
    Imports Local Experience Pack files into the application's import directory structure.

.DESCRIPTION
    Copies Local Experience Pack files from a source location into the application's organized
    import directory structure (imports\Lang\{WinOS}\{version}\localexperiencepack\).
    Creates the destination directory structure and per-package subdirectories as needed.
    Handles version normalization: version 1903 is mapped to 1909 (same packages).
    Each LXP package gets its own subdirectory containing the .appx and .xml files.
    Supports batch importing of multiple LXP packages selected in the form listbox.

.PARAMETER Winver
    The Windows version for which the LXP files are being imported (e.g., '22H2', '23H2', '2004', '1903', '1909').

.PARAMETER LPSourceFolder
    The source folder path containing the Local Experience Pack files to be imported.

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Import-LocalExperiencePack -Winver '23H2' -LPSourceFolder 'D:\LocalExperiencePacks\' -WinOS 'Windows 11'
    Imports all Local Experience Packs from D:\LocalExperiencePacks\ to the local import directory.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Write access to $global:workdir\imports\ directory
    Items to import: Retrieved from $WPFImportOtherLBList listbox
    Version mapping: 1903 → 1909 (Windows 10 versions that use same packages)
    Destination: $global:workdir\imports\Lang\{WinOS}\{version}\localexperiencepack\{PackageName}\
    Each LXP gets its own subdirectory with .appx and .xml license files

.OUTPUTS
    None. Creates directory structure and copies files. Logs all operations via Update-Log function.
#>
Function Import-LocalExperiencePack($Winver, $LPSourceFolder, $WinOS) {

    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    Update-Log -Data 'Importing Local Experience Packs...' -Class Information

    if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$winver\localexperiencepack) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\localexperiencepack'
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\Lang\$WinOS\$winver -Name localexperiencepack -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }

    $items = $WPFImportOtherLBList.items
    foreach ($item in $items) {
        $name = $item
        $source = $LPSourceFolder + $name
        $text = 'Creating destination folder for ' + $item
        Update-Log -Data $text -Class Information

        if ((Test-Path -Path $global:workdir\imports\lang\$WinOS\$winver\localexperiencepack\$name) -eq $False) { New-Item -Path $global:workdir\imports\lang\$WinOS\$winver\localexperiencepack -Name $name -ItemType Directory }
        else {
            $text = 'The folder for ' + $item + ' already exists. Skipping creation...'
            Update-Log -Data $text -Class Warning
        }

        Update-Log -Data 'Copying source to destination folders...' -Class Information
        Get-ChildItem -Path $source | Copy-Item -Destination $global:workdir\imports\Lang\$WinOS\$Winver\LocalExperiencePack\$name -Force
    }
    Update-log -Data 'Importation complete' -Class Information
}

<#
.SYNOPSIS
    Imports Features On Demand files into the application's import directory structure.

.DESCRIPTION
    Copies Features On Demand capability packages from a source location into the application's organized
    import directory structure (imports\FODs\{WinOS}\{version}\).
    Creates the destination directory structure if it does not exist.
    Handles version normalization: version 1903 is mapped to 1909 (same packages).
    Supports different import patterns for Windows 11 (individual FODs) vs other versions (language pack structure).
    Also imports the metadata subfolder required for FOD functionality.
    Supports batch importing of multiple FOD packages selected in the form listbox.

.PARAMETER Winver
    The Windows version for which the FOD files are being imported (e.g., '22H2', '23H2', '2004', '1903', '1909').

.PARAMETER LPSourceFolder
    The source folder path containing the Features On Demand files to be imported.

.PARAMETER WinOS
    The Windows operating system type ('Windows 10', 'Windows 11', 'Windows Server').

.EXAMPLE
    Import-FeatureOnDemand -Winver '22H2' -LPSourceFolder 'D:\FODs\' -WinOS 'Windows 10'
    Imports all Features On Demand from D:\FODs\ to the local import directory.

.EXAMPLE
    Import-FeatureOnDemand -Winver '23H2' -LPSourceFolder 'D:\FODs\' -WinOS 'Windows 11'
    Imports Windows 11 FODs using per-FOD import pattern.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Write access to $global:workdir\imports\ directory
    Items to import: Retrieved from $WPFImportOtherLBList listbox
    Version mapping: 1903 → 1909 (Windows 10 versions that use same packages)
    Destination: $global:workdir\imports\FODs\{WinOS}\{version}\
    Windows 11: Imports individual FOD packages directly
    Other versions: Imports language pack directory structure then metadata subfolder
    Required: Source must include a \metadata\ subfolder

.OUTPUTS
    None. Creates directory structure and copies files. Logs all operations via Update-Log function.
#>
Function Import-FeatureOnDemand($Winver, $LPSourceFolder, $WinOS) {

    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    $path = $WPFImportOtherTBPath.text
    $text = 'Starting importation of Feature On Demand binaries from ' + $path
    Update-Log -Data $text -Class Information

    $langpacks = Get-ChildItem -Path $LPSourceFolder

    if ((Test-Path -Path $global:workdir\imports\FODs\$WinOS\$Winver) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\FODs\' + $WinOS + '\' + $winver
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\fods\$WinOS -Name $winver -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }
    #If Windows 11

    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 11') {
        $items = $WPFImportOtherLBList.items
        foreach ($item in $items) {
            $source = $LPSourceFolder + $item
            $text = 'Importing ' + $item
            Update-Log -Data $text -Class Information
            Copy-Item $source -Destination $global:workdir\imports\FODs\$WinOS\$Winver\ -Force
        }

    }


    #If not Windows 11
    if ($WPFImportOtherCBWinOS.SelectedItem -ne 'Windows 11') {
        foreach ($langpack in $langpacks) {
            $source = $LPSourceFolder + $langpack.name

            Copy-Item $source -Destination $global:workdir\imports\FODs\$WinOS\$Winver\ -Force
            $name = $langpack.name
            $text = 'Copying ' + $name
            Update-Log -Data $text -Class Information

        }
    }

    Update-Log -Data 'Importing metadata subfolder...' -Class Information
    Get-ChildItem -Path ($LPSourceFolder + '\metadata\') | Copy-Item -Destination $global:workdir\imports\FODs\$WinOS\$Winver\metadata -Force
    Update-Log -data 'Feature On Demand imporation complete.'
}

#Function to update winver cobmo box
Function Update-ImportVersionCB {
    $WPFImportOtherCBWinVer.Items.Clear()
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows Server') { Foreach ($WinSrvVer in $WinSrvVer) { $WPFImportOtherCBWinVer.Items.Add($WinSrvVer) } }
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 10') { Foreach ($Win10Ver in $Win10ver) { $WPFImportOtherCBWinVer.Items.Add($Win10Ver) } }
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 11') { Foreach ($Win11Ver in $Win11ver) { $WPFImportOtherCBWinVer.Items.Add($Win11Ver) } }
}

#Function to select other object import source path
<#
.SYNOPSIS
    Prompts user to select an import source folder for custom content.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select an import source directory
    containing custom content to be imported into the WIM image processing.
    Updates the form textbox with the selected folder path (including trailing backslash).

.EXAMPLE
    Select-ImportOtherPath
    Opens folder dialog and updates import path field.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFImportOtherTBPath
    A trailing backslash is automatically appended to the selected path.

.OUTPUTS
    None. Updates form variable.
#>
Function Select-ImportOtherPath {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Source folder'
    $null = $browser.ShowDialog()
    $ImportPath = $browser.SelectedPath + '\'
    $WPFImportOtherTBPath.text = $ImportPath

}

#Function to allow user to pause MAke it so process
<#
.SYNOPSIS
    Pauses the image build process and prompts the user to continue or cancel.

.DESCRIPTION
    Displays a Windows MessageBox dialog that interrupts the WIM customization workflow,
    allowing the user to inspect the current state before proceeding. This interactive
    pause point is typically used after mounting the WIM or before dismounting, giving
    administrators an opportunity to manually verify or modify the mounted image.
    The user can choose to continue the build process or cancel and discard all changes.
    This function supports the pause checkboxes in the MakeItSo workflow.

.EXAMPLE
    $result = Suspend-MakeItSo
    if ($result -eq 'Yes') { Write-Host 'Continuing with build...' }
    Pauses execution and waits for user decision, then continues based on response.

.EXAMPLE
    Suspend-MakeItSo
    Displays pause dialog during image customization workflow.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is called by Invoke-MakeItSo when pause options are enabled.
    Requires Windows Forms assembly for MessageBox display.
    User selections: 'Yes' continues the build, 'No' discards the WIM and aborts.

.OUTPUTS
    System.String. Returns 'Yes' if user chooses to continue, 'No' if user chooses to cancel.
#>
Function Suspend-MakeItSo {
    $MISPause = ([System.Windows.MessageBox]::Show('Click Yes to continue the image build. Click No to cancel and discard the wim file.', 'WIM Witch Paused', 'YesNo', 'Warning'))
    if ($MISPause -eq 'Yes') { return 'Yes' }

    if ($MISPause -eq 'No') { return 'No' }
}

<#
.SYNOPSIS
    Executes a custom PowerShell script with specified parameters during the image build process.

.DESCRIPTION
    Invokes a user-supplied PowerShell script at designated points in the WIM customization workflow.
    This function enables advanced customization scenarios by allowing administrators to inject
    custom logic and modifications that aren't covered by WIMWitch-tNG's built-in features.
    Scripts can be executed at three different stages: after image mount, before image dismount,
    or on build completion. The function combines the file path and parameters into a single
    command string, executes it using Invoke-Expression, and logs success or failure.

.PARAMETER file
    The full path to the PowerShell script file (.ps1) to execute.
    This should be a valid, existing PowerShell script file.

.PARAMETER parameter
    Optional parameters to pass to the script. These are appended to the script path
    and can include command-line arguments, switches, or named parameters that the
    target script accepts. Can be an empty string if no parameters are needed.

.EXAMPLE
    Start-Script -file 'C:\Scripts\CustomizeImage.ps1' -parameter '-MountPath C:\Mount'
    Executes CustomizeImage.ps1 with the MountPath parameter.

.EXAMPLE
    Start-Script 'D:\Tools\ApplyTweaks.ps1' ''
    Runs ApplyTweaks.ps1 without any parameters.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is called by Invoke-MakeItSo when custom script execution is enabled.
    The script runs in the current PowerShell session context with access to WIMWitch-tNG variables.
    Errors during script execution are caught and logged but do not halt the image build process.
    Use with caution as scripts have full access to the mounted image and system.

.OUTPUTS
    None. Logs execution status via Update-Log function with Information or Error classification.
#>
Function Start-Script($file, $parameter) {
    $string = "$file $parameter"
    try {
        Update-Log -Data 'Running script' -Class Information
        Invoke-Expression -Command $string -ErrorAction Stop
        Update-Log -data 'Script complete' -Class Information
    } catch {
        Update-Log -Data 'Script failed' -Class Error
    }
}

#Function to select existing configMgr image package
<#
.SYNOPSIS
    Retrieves and displays detailed information about a ConfigMgr OS image package.

.DESCRIPTION
    Queries the ConfigMgr SMS Provider to retrieve comprehensive details about an operating system image package,
    including package ID, version, OS build number, distribution points, and configuration settings. Updates the
    form controls with the retrieved information and logs all discovered properties. Detects Binary Differential
    Replication and Package Share settings.

.PARAMETER PackID
    The ConfigMgr Package ID of the operating system image to retrieve information about.

.EXAMPLE
    Get-ImageInfo -PackID "NTP00001"
    Retrieves and displays information for the OS image with Package ID NTP00001.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, valid site connection, and appropriate WMI permissions.
    Updates multiple WPF form controls with retrieved image information.

.OUTPUTS
    None. Updates form controls and logging output.
#>
Function Get-ImageInfo {
    Param(
        [parameter(mandatory = $true)]
        [string]$PackID

    )


    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $image = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_ImagePackage -ComputerName $global:SiteServer) | Where-Object { ($_.PackageID -eq $PackID) }

        $WPFCMTBImageName.text = $image.name
        $WPFCMTBWinBuildNum.text = $image.ImageOSversion
        $WPFCMTBPackageID.text = $image.PackageID
        $WPFCMTBImageVer.text = $image.version
        $WPFCMTBDescription.text = $image.Description

        $text = 'Image ' + $WPFCMTBImageName.text + ' selected'
        Update-Log -data $text -class Information

        $text = 'Package ID is ' + $image.PackageID
        Update-Log -data $text -class Information

        $text = 'Image build number is ' + $image.ImageOSversion
        Update-Log -data $text -class Information

        $packageID = (Get-CMOperatingSystemImage -Id $image.PackageID)
        # $packageID.PkgSourcePath

        $WPFMISWimFolderTextBox.text = (Split-Path -Path $packageID.PkgSourcePath)
        $WPFMISWimNameTextBox.text = (Split-Path -Path $packageID.PkgSourcePath -Leaf)

        $Package = $packageID.PackageID
        $DPs = Get-CMDistributionPoint
        $NALPaths = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -ComputerName $global:SiteServer -Query "SELECT * FROM SMS_DistributionPoint WHERE PackageID='$Package'")

        Update-Log -Data 'Retrieving Distrbution Point Information' -Class Information
        foreach ($NALPath in $NALPaths) {
            foreach ($dp in $dps) {
                $DPPath = $dp.NetworkOSPath
                if ($NALPath.ServerNALPath -like ("*$DPPath*")) {
                    Update-Log -data "Image has been previously distributed to $DPPath" -class Information
                    $WPFCMLBDPs.Items.Add($DPPath)

                }
            }
        }

        #Detect Binary Diff Replication
        Update-Log -data 'Checking Binary Differential Replication setting' -Class Information
        if ($image.PkgFlags -eq ($image.PkgFlags -bor 0x04000000)) {
            $WPFCMCBBinDirRep.IsChecked = $True
        } else {
            $WPFCMCBBinDirRep.IsChecked = $False
        }

        #Detect Package Share Enabled
        Update-Log -data 'Checking package share settings' -Class Information
        if ($image.PkgFlags -eq ($image.PkgFlags -bor 0x80)) {
            $WPFCMCBDeploymentShare.IsChecked = $true
        } else
        { $WPFCMCBDeploymentShare.IsChecked = $false }
    } finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Displays ConfigMgr Distribution Points or Distribution Point Groups for selection.

.DESCRIPTION
    Connects to Configuration Manager and retrieves either individual Distribution Points or
    Distribution Point Groups based on the form dropdown selection. Displays the list in a
    grid view dialog for multi-select and adds selected items to the form listbox.
    Requires ConfigMgr module and proper site connection.

.EXAMPLE
    Select-DistributionPoints
    Displays DPs or DPGs based on form selection and adds chosen items to distribution list.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module and valid site connection
    Updates: $WPFCMLBDPs listbox control
    Form selection: $WPFCMCBDPDPG determines DP vs DPG retrieval

.OUTPUTS
    None. Updates form listbox.
#>
Function Select-DistributionPoints {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Points') {

            $SelectedDPs = (Get-CMDistributionPoint -SiteCode $global:sitecode).NetworkOSPath | Out-GridView -Title 'Select Distribution Points' -PassThru
            foreach ($SelectedDP in $SelectedDPs) { $WPFCMLBDPs.Items.Add($SelectedDP) }
        }
        if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Point Groups') {
            $SelectedDPs = (Get-CMDistributionPointGroup).Name | Out-GridView -Title 'Select Distribution Point Groups' -PassThru
            foreach ($SelectedDP in $SelectedDPs) { $WPFCMLBDPs.Items.Add($SelectedDP) }
        }
    } finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Creates a new operating system image package in ConfigMgr.

.DESCRIPTION
    Creates a new OS image package in ConfigMgr using the specified WIM file path and name from form controls.
    Applies image properties including version, description, and Binary Differential Replication settings.
    Distributes the package content to selected Distribution Points or Distribution Point Groups.
    Saves the configuration with the assigned Package ID.

.EXAMPLE
    New-CMImagePackage
    Creates a new OS image package in ConfigMgr using form values and distributes to selected DPs.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, valid site connection.
    Prerequisites: WIM file path, image name, and distribution points must be configured in form controls.
    Calls Set-ImageProperties to apply additional configuration settings.

.OUTPUTS
    None. Creates image package, distributes content, and saves configuration.
#>
Function New-CMImagePackage {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $Path = $WPFMISWimFolderTextBox.text + '\' + $WPFMISWimNameTextBox.text

        try {
            New-CMOperatingSystemImage -Name $WPFCMTBImageName.text -Path $Path -ErrorAction Stop
            Update-Log -data 'Image was created. Check ConfigMgr console' -Class Information
        } catch {
            Update-Log -data 'Failed to create the image' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

        $PackageID = (Get-CMOperatingSystemImage -Name $WPFCMTBImageName.text).PackageID
        Update-Log -Data "The Package ID of the new image is $PackageID" -Class Information

        Set-ImageProperties -PackageID $PackageID

        Update-Log -Data 'Retriveing Distribution Point information...' -Class Information
        $DPs = $WPFCMLBDPs.Items

        foreach ($DP in $DPs) {
            # Hello! This line was written on 3/3/2020.
            $DP = $DP -replace '\\', ''

            Update-Log -Data 'Distributiong image package content...' -Class Information
            if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Points') {
                Start-CMContentDistribution -OperatingSystemImageId $PackageID -DistributionPointName $DP
            }
            if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Point Groups') {
                Start-CMContentDistribution -OperatingSystemImageId $PackageID -DistributionPointGroupName $DP
            }

            Update-Log -Data 'Content has been distributed.' -Class Information
        }

        Save-Configuration -CM $PackageID
    } finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Enables or disables ConfigMgr tab UI controls based on selected image type.

.DESCRIPTION
    Dynamically enables and disables form controls on the ConfigMgr tab based on the selected image type
    (New Image, Update Existing Image, or Disabled). Configures the appropriate UI state for each operation mode,
    controlling access to distribution points, package properties, and configuration options.
    Logs the selected ConfigMgr feature mode.

.EXAMPLE
    Enable-ConfigMgrOptions
    Configures UI controls based on current ConfigMgr image type selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Triggered by changes to the WPFCMCBImageType dropdown control.
    Controls visibility and enabled state of: distribution points, image properties, versioning, and deployment options.

.OUTPUTS
    None. Updates form control states.
#>
Function Enable-ConfigMgrOptions {

    #"Disabled","New Image","Update Existing Image"
    if ($WPFCMCBImageType.SelectedItem -eq 'New Image') {
        $WPFCMBAddDP.IsEnabled = $True
        $WPFCMBRemoveDP.IsEnabled = $True
        $WPFCMBSelectImage.IsEnabled = $False
        $WPFCMCBBinDirRep.IsEnabled = $True
        $WPFCMCBDPDPG.IsEnabled = $True
        $WPFCMLBDPs.IsEnabled = $True
        $WPFCMTBDescription.IsEnabled = $True
        $WPFCMTBImageName.IsEnabled = $True
        $WPFCMTBImageVer.IsEnabled = $True
        $WPFCMTBPackageID.IsEnabled = $False
        #        $WPFCMTBSitecode.IsEnabled = $True
        #        $WPFCMTBSiteServer.IsEnabled = $True
        $WPFCMTBWinBuildNum.IsEnabled = $False
        $WPFCMCBImageVerAuto.IsEnabled = $True
        $WPFCMCBDescriptionAuto.IsEnabled = $True
        $WPFCMCBDeploymentShare.IsEnabled = $True


        # $MEMCMsiteinfo = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification"
        # $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
        # $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'
        Update-Log -data 'ConfigMgr feature enabled. New Image selected' -class Information
        #    Update-Log -data $WPFCMTBSitecode.text -class Information
        #    Update-Log -data $WPFCMTBSiteServer.text -class Information
    }

    if ($WPFCMCBImageType.SelectedItem -eq 'Update Existing Image') {
        $WPFCMBAddDP.IsEnabled = $False
        $WPFCMBRemoveDP.IsEnabled = $False
        $WPFCMBSelectImage.IsEnabled = $True
        $WPFCMCBBinDirRep.IsEnabled = $True
        $WPFCMCBDPDPG.IsEnabled = $False
        $WPFCMLBDPs.IsEnabled = $False
        $WPFCMTBDescription.IsEnabled = $True
        $WPFCMTBImageName.IsEnabled = $False
        $WPFCMTBImageVer.IsEnabled = $True
        $WPFCMTBPackageID.IsEnabled = $True
        $WPFCMTBSitecode.IsEnabled = $True
        $WPFCMTBSiteServer.IsEnabled = $True
        $WPFCMTBWinBuildNum.IsEnabled = $False
        $WPFCMCBImageVerAuto.IsEnabled = $True
        $WPFCMCBDescriptionAuto.IsEnabled = $True
        $WPFCMCBDeploymentShare.IsEnabled = $True

        #  $MEMCMsiteinfo = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification"
        #  $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
        #  $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'
        Update-Log -data 'ConfigMgr feature enabled. Update an existing image selected' -class Information
        #   Update-Log -data $WPFCMTBSitecode.text -class Information
        #   Update-Log -data $WPFCMTBSiteServer.text -class Information
    }

    if ($WPFCMCBImageType.SelectedItem -eq 'Disabled') {
        $WPFCMBAddDP.IsEnabled = $False
        $WPFCMBRemoveDP.IsEnabled = $False
        $WPFCMBSelectImage.IsEnabled = $False
        $WPFCMCBBinDirRep.IsEnabled = $False
        $WPFCMCBDPDPG.IsEnabled = $False
        $WPFCMLBDPs.IsEnabled = $False
        $WPFCMTBDescription.IsEnabled = $False
        $WPFCMTBImageName.IsEnabled = $False
        $WPFCMTBImageVer.IsEnabled = $False
        $WPFCMTBPackageID.IsEnabled = $False
        #       $WPFCMTBSitecode.IsEnabled = $False
        #       $WPFCMTBSiteServer.IsEnabled = $False
        $WPFCMTBWinBuildNum.IsEnabled = $False
        $WPFCMCBImageVerAuto.IsEnabled = $False
        $WPFCMCBDescriptionAuto.IsEnabled = $False
        $WPFCMCBDeploymentShare.IsEnabled = $False
        Update-Log -data 'ConfigMgr feature disabled' -class Information

    }

}

<#
.SYNOPSIS
    Updates an existing ConfigMgr OS image package and refreshes distribution points.

.DESCRIPTION
    Updates an existing operating system image package in ConfigMgr by refreshing the package source,
    reloading image properties from the WIM file, and updating distribution points with the new content.
    Applies current image property settings and saves the updated configuration.

.EXAMPLE
    Update-CMImage
    Refreshes the image package specified in the form's Package ID field.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, valid site connection, and WMI permissions.
    Uses WPFCMTBPackageID control to identify the package to update.
    Calls Set-ImageProperties to apply configuration updates.

.OUTPUTS
    None. Updates ConfigMgr package and distribution points.
#>
Function Update-CMImage {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $wmi = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_ImagePackage -ComputerName $global:SiteServer) | Where-Object { $_.PackageID -eq $WPFCMTBPackageID.text }



        Update-Log -Data 'Updating images on the Distribution Points...'
        $WMI.RefreshPkgSource() | Out-Null

        Update-Log -Data 'Refreshing image proprties from the WIM' -Class Information
        $WMI.ReloadImageProperties() | Out-Null

        Set-ImageProperties -PackageID $WPFCMTBPackageID.Text
        Save-Configuration -CM -filename $WPFCMTBPackageID.Text
    } finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Configures UI controls on the Software Update Catalog tab based on selected catalog source.

.DESCRIPTION
    Enables or disables update-related form controls based on the selected catalog source (None, OSDSUS, or ConfigMgr).
    Adjusts availability of update download buttons, update checking options, and catalog-specific features.
    Logs the selected update catalog source and performs necessary initialization checks.

.EXAMPLE
    Invoke-UpdateTabOptions
    Configures update tab controls based on current catalog source selection.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Triggered by changes to WPFUSCBSelectCatalogSource dropdown control.
    Calls Invoke-OSDCheck when OSDSUS is selected to validate installation.

.OUTPUTS
    None. Updates form control states.
#>
Function Invoke-UpdateTabOptions {

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'None' ) {

        $WPFUpdateOSDBUpdateButton.IsEnabled = $false
        $WPFUpdatesDownloadNewButton.IsEnabled = $false
        $WPFUpdatesW10Main.IsEnabled = $false

        $WPFMISCBCheckForUpdates.IsEnabled = $false
        $WPFMISCBCheckForUpdates.IsChecked = $false

    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'OSDSUS') {
        $WPFUpdateOSDBUpdateButton.IsEnabled = $true
        $WPFUpdatesDownloadNewButton.IsEnabled = $true
        $WPFUpdatesW10Main.IsEnabled = $true

        $WPFMISCBCheckForUpdates.IsEnabled = $false
        $WPFMISCBCheckForUpdates.IsChecked = $false
        Update-Log -data 'OSDSUS selected as update catalog' -class Information
        Invoke-OSDCheck

    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'ConfigMgr') {
        $WPFUpdateOSDBUpdateButton.IsEnabled = $false
        $WPFUpdatesDownloadNewButton.IsEnabled = $true
        $WPFUpdatesW10Main.IsEnabled = $true
        $WPFMISCBCheckForUpdates.IsEnabled = $true
        #        $MEMCMsiteinfo = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification"

        #   $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
        #   $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'
        Update-Log -data 'ConfigMgr is selected as the update catalog' -Class Information

    }

}

<#
.SYNOPSIS
    Downloads Microsoft update packages from ConfigMgr catalog.

.DESCRIPTION
    Downloads update content files (CAB and MSU) from the ConfigMgr software update catalog based on update name
    and classification. Supports multiple update types including Cumulative Updates (LCU), Servicing Stack Updates (SSU),
    .NET Framework updates, Adobe updates, and Dynamic Updates. Filters out incompatible packages (express, baseless,
    FOD metadata servicing). Validates CAB files for update.mum metadata. Organizes downloads by update class and name.

.PARAMETER FilePath
    The destination path where update files will be downloaded and organized into subfolders.

.PARAMETER UpdateName
    The localized display name of the update to download from the ConfigMgr catalog.

.EXAMPLE
    Invoke-MSUpdateItemDownload -FilePath "C:\Updates\" -UpdateName "2024-01 Cumulative Update for Windows 10 Version 22H2 for x64-based Systems (KB5034441)"
    Downloads the specified cumulative update to the designated path.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, valid site connection, and WMI access.
    Supports optional updates when WPFUpdatesCBEnableOptional is checked.
    Supports Dynamic Updates when WPFUpdatesCBEnableDynamic is checked.
    Skips previously downloaded files.

.OUTPUTS
    System.Int32. Returns 0 on success, 1 on error, 2 if update not found.
#>
Function Invoke-MSUpdateItemDownload {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true, HelpMessage = 'Specify the path to where the update item will be downloaded.')]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        $UpdateName
    )
    #write-host $updatename
    #write-host $filepath

    $OptionalUpdateCheck = 0

    #Adding in optional updates


    if ($UpdateName -like '*Adobe*') {
        $UpdateClass = 'AdobeSU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Microsoft .NET Framework*') {
        $UpdateClass = 'DotNet'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Cumulative Update for .NET Framework*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'DotNetCU'
    }
    if ($UpdateName -like '*Cumulative Update for Windows*') {
        $UpdateClass = 'LCU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Cumulative Update for Microsoft*') {
        $UpdateClass = 'LCU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Servicing Stack Update*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'SSU'
    }
    if ($UpdateName -like '*Dynamic*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'Dynamic'
    }

    if ($OptionalUpdateCheck -eq '0') {

        #Update-Log -data "This update appears to be optional. Skipping..." -Class Warning
        #return
        if ($WPFUpdatesCBEnableOptional.IsChecked -eq $True) { Update-Log -data 'This update appears to be optional. Downloading...' -Class Information }
        else {
            Update-Log -data 'This update appears to be optional, but are not enabled for download. Skipping...' -Class Information
            return
        }
        #Update-Log -data "This update appears to be optional. Downloading..." -Class Information

        $UpdateClass = 'Optional'

    }

    if ($UpdateName -like '*Windows 10*') {
        #here
        #if (($UpdateName -like "* 1903 *") -or ($UpdateName -like "* 1909 *") -or ($UpdateName -like "* 2004 *") -or ($UpdateName -like "* 20H2 *") -or ($UpdateName -like "* 21H1 *") -or ($UpdateName -like "* 21H2 *") -or ($UpdateName -like "* 22H2 *")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}

        if (($UpdateName -like '* 1903 *') -or ($UpdateName -like '* 1909 *') -or ($UpdateName -like '* 2004 *') -or ($UpdateName -like '* 20H2 *') -or ($UpdateName -like '* 21H1 *') -or ($UpdateName -like '* 21H2 *') -or ($UpdateName -like '* 22H2 *')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'" }
        else { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10'" }
        if ($updateName -like '*Dynamic*') {
            if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10 Dynamic Update'" }
        }
        #else{
        #Update-Log -data "Dynamic updates have not been selected for downloading. Skipping..." -Class Information
        #return
        #}
    }

    if ($UpdateName -like '*Windows 11*') {
        { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11'" }

        if ($updateName -like '*Dynamic*') {
            if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11 Dynamic Update'" }
        }

    }



    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '1607')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2016'" }
    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '1809')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2019'" }
    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '21H2')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Microsoft Server operating system-21H2'" }


    $UpdateItem = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.LocalizedDisplayName -eq $UpdateName) }

    if ($null -ne $UpdateItem) {

        # Determine the ContentID instances associated with the update instance
        $UpdateItemContentIDs = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_CIToContent -ComputerName $global:SiteServer -Filter "CI_ID = $($UpdateItem.CI_ID)" -ErrorAction Stop
        if ($null -ne $UpdateItemContentIDs) {

            # Account for multiple content ID items
            foreach ($UpdateItemContentID in $UpdateItemContentIDs) {
                # Get the content files associated with current Content ID
                $UpdateItemContent = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_CIContentFiles -ComputerName $global:SiteServer -Filter "ContentID = $($UpdateItemContentID.ContentID)" -ErrorAction Stop
                if ($null -ne $UpdateItemContent) {
                    # Handle both single object and array of objects
                    $UpdateItemContentArray = @($UpdateItemContent)

                    foreach ($ContentItem in $UpdateItemContentArray) {
                        # Filter: Only download .cab and .msu files
                        $fileExtension = [System.IO.Path]::GetExtension($ContentItem.filename).ToLower()
                        if ($fileExtension -ne '.cab' -and $fileExtension -ne '.msu') {
                            Update-Log -Data "Skipping non-CAB/MSU file: $($ContentItem.filename)" -Class Information
                            continue
                        }

                        # Filter: Skip incompatible CAB patterns (offline servicing not supported)
                        if ($ContentItem.filename -like '*FodMetadataServicing*') {
                            Update-Log -Data "Skipping FodMetadataServicing package (not compatible with offline servicing): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        if ($ContentItem.filename -like '*-express.cab') {
                            Update-Log -Data "Skipping express CAB (requires online servicing): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        if ($ContentItem.filename -like '*-baseless.cab') {
                            Update-Log -Data "Skipping baseless CAB (requires baseline already installed): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        # Create new custom object for the update content
                        #write-host $ContentItem.filename
                        $PSObject = [PSCustomObject]@{
                            'DisplayName' = $UpdateItem.LocalizedDisplayName
                            'ArticleID'   = $UpdateItem.ArticleID
                            'FileName'    = $ContentItem.filename
                            'SourceURL'   = $ContentItem.SourceURL
                            'DateRevised' = [System.Management.ManagementDateTimeConverter]::ToDateTime($UpdateItem.DateRevised)
                        }

                        $variable = $FilePath + $UpdateClass + '\' + $UpdateName

                        if ((Test-Path -Path $variable) -eq $false) {
                            Update-Log -Data "Creating folder $variable" -Class Information
                            New-Item -Path $variable -ItemType Directory | Out-Null
                            Update-Log -data 'Created folder' -Class Information
                        }

                        $testpath = $variable + '\' + $PSObject.FileName

                        if ((Test-Path -Path $testpath) -eq $true) {
                            Update-Log -Data "Update item already exists. Skipping download of: $($PSObject.FileName)" -Class Information
                            continue
                        }

                        try {
                            Update-Log -Data "Downloading update item content from: $($PSObject.SourceURL)" -Class Information

                            $DNLDPath = $variable + '\' + $PSObject.FileName

                            $WebClient = New-Object -TypeName System.Net.WebClient
                            $WebClient.DownloadFile($PSObject.SourceURL, $DNLDPath)

                            Update-Log -Data "Download completed successfully, file: $($PSObject.FileName)" -Class Information

                            # Validate .cab files contain update.mum metadata
                            if ($PSObject.FileName -like '*.cab') {
                                Update-Log -Data "Validating CAB file contains update.mum metadata..." -Class Information
                                $validationPassed = $false
                                $validationAttempted = $false

                                try {
                                    # Method 1: Try PowerShell/COM approach using Shell.Application
                                    $shell = New-Object -ComObject Shell.Application
                                    $cabFolder = $shell.NameSpace($DNLDPath)

                                    if ($null -ne $cabFolder) {
                                        $updateMumFound = $false
                                        foreach ($item in $cabFolder.Items()) {
                                            if ($item.Name -match 'update\.mum') {
                                                $updateMumFound = $true
                                                break
                                            }
                                        }
                                        $validationAttempted = $true

                                        if (-not $updateMumFound) {
                                            Update-Log -Data "CAB file is invalid - does not contain update.mum metadata. Deleting: $($PSObject.FileName)" -Class Error
                                            Remove-Item -Path $DNLDPath -Force -ErrorAction Stop
                                            $ReturnValue = 1
                                        } else {
                                            Update-Log -Data "CAB file validation passed - update.mum metadata found (via COM)" -Class Information
                                            $validationPassed = $true
                                            $ReturnValue = 0
                                        }
                                    }
                                } catch {
                                    Update-Log -Data "COM validation method failed: $($_.Exception.Message)" -Class Warning
                                    $validationAttempted = $false
                                }

                                # Method 2: Fallback to expand.exe if COM method failed
                                if (-not $validationAttempted) {
                                    try {
                                        Update-Log -Data "Attempting validation with expand.exe..." -Class Information
                                        $expandExe = "$env:windir\system32\expand.exe"
                                        # List contents of CAB without extracting
                                        $cabContents = & $expandExe -D $DNLDPath 2>&1 | Out-String

                                        if ($cabContents -notmatch 'update\.mum') {
                                            Update-Log -Data "CAB file is invalid - does not contain update.mum metadata. Deleting: $($PSObject.FileName)" -Class Error
                                            Remove-Item -Path $DNLDPath -Force -ErrorAction Stop
                                            $ReturnValue = 1
                                        } else {
                                            Update-Log -Data "CAB file validation passed - update.mum metadata found (via expand.exe)" -Class Information
                                            $validationPassed = $true
                                            $ReturnValue = 0
                                        }
                                    } catch {
                                        Update-Log -Data "Failed to validate CAB file with expand.exe: $($_.Exception.Message)" -Class Warning
                                        $ReturnValue = 0  # Continue even if validation fails
                                    }
                                }

                                if (-not $validationPassed -and $ReturnValue -eq 0) {
                                    Update-Log -Data "CAB validation could not be completed - keeping file as fallback" -Class Warning
                                }
                            } else {
                                $ReturnValue = 0
                            }
                        } catch [System.Exception] {
                            Update-Log -data "Unable to download update item content. Error message: $($_.Exception.Message)" -Class Error
                            $ReturnValue = 1
                        }
                    }
                } else {
                    Update-Log -data "Unable to determine update content instance for CI_ID: $($UpdateItemContentID.ContentID)" -Class Error
                    $ReturnValue = 1
                }
            }
        } else {
            Update-Log -Data "Unable to determine ContentID instance for CI_ID: $($UpdateItem.CI_ID)" -Class Error
            $ReturnValue = 1
        }
    } else {
        Update-Log -data "Unable to locate update item from SMS Provider for update type: $($UpdateType)" -Class Error
        $ReturnValue = 2
    }


    # Handle return value from Function
    return $ReturnValue | Out-Null
}

<#
.SYNOPSIS
    Retrieves and downloads non-superseded updates from ConfigMgr catalog for specified Windows product and version.

.DESCRIPTION
    Queries the ConfigMgr SMS Provider for non-superseded software updates matching the specified Windows product
    (Windows 10, Windows 11, Windows Server) and version. Filters out feature updates, language packs, and edition-specific
    updates. Downloads applicable updates including Cumulative Updates, Servicing Stack Updates, .NET updates, and
    optionally Dynamic Updates. Supports Windows 10 (various versions), Windows 11, Windows Server 2016/2019/2022.

.PARAMETER prod
    The Windows product name: 'Windows 10', 'Windows 11', or 'Windows Server'.

.PARAMETER ver
    The version identifier (e.g., '22H2', '21H2', '1809', '1607').

.EXAMPLE
    Invoke-MEMCMUpdatecatalog -prod "Windows 10" -ver "22H2"
    Downloads all current updates for Windows 10 version 22H2.

.EXAMPLE
    Invoke-MEMCMUpdatecatalog -prod "Windows 11" -ver "23H2"
    Downloads all current updates for Windows 11 version 23H2.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, synchronized software update catalog.
    Updates must be synchronized in ConfigMgr before they can be downloaded.
    Respects WPFUpdatesCBEnableDynamic checkbox for Dynamic Update inclusion.

.OUTPUTS
    None. Downloads update files via Invoke-MSUpdateItemDownload.
#>
Function Invoke-MEMCMUpdatecatalog($prod, $ver) {

    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $Arch = 'x64'

        if ($prod -eq 'Windows 10') {
            #        if (($ver -ge '1903') -or ($ver -eq "21H1")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}
            #        if (($ver -ge '1903') -or ($ver -eq "21H1") -or ($ver -eq "20H2") -or ($ver -eq "21H2") -or ($ver -eq "22H2")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}
            #here
            if (($ver -ge '1903') -or ($ver -like '2*')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'" }


            if ($ver -le '1809') { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10'" }

            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } )
        }


        if (($prod -like '*Windows Server*') -and ($ver -eq '1607')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2016'"
            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -notlike '* Next *') -and ($_.LocalizedDisplayName -notlike '*(1703)*') -and ($_.LocalizedDisplayName -notlike '*(1709)*') -and ($_.LocalizedDisplayName -notlike '*(1803)*') })
        }

        if (($prod -like '*Windows Server*') -and ($ver -eq '1809')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2019'"
            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
        }

        if (($prod -like '*Windows Server*') -and ($ver -eq '21H2')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Microsoft Server operating system-21H2'"
        $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
    }

    if ($prod -eq 'Windows 11') {
        $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11'"
        #$Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
        if ($ver -eq '21H2') { $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*Windows 11 for $($Arch)*") } ) }
        else { $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } ) }


    }

    if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) {

        if ($prod -eq 'Windows 10') { $Updates = $Updates + (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter "LocalizedCategoryInstanceNames = 'Windows 10 Dynamic Update'" -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } ) }
        if ($prod -eq 'Windows 11') { $Updates = $Updates + (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter "LocalizedCategoryInstanceNames = 'Windows 11 Dynamic Update'" -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$prod*") -and ($_.LocalizedDisplayName -like "*$arch*") } ) }


    }


    if ($null -eq $updates) {
        Update-Log -data 'No updates found. Product is likely not synchronized. Continuing with build...' -class Warning
        return
    }


    foreach ($update in $updates) {
        if ((($update.localizeddisplayname -notlike 'Feature update*') -and ($update.localizeddisplayname -notlike 'Upgrade to Windows 11*' )) -and ($update.localizeddisplayname -notlike '*Language Pack*') -and ($update.localizeddisplayname -notlike '*editions),*')) {
            Update-Log -Data 'Checking the following update:' -Class Information
            Update-Log -data $update.localizeddisplayname -Class Information
            #write-host "Display Name"
            #write-host $update.LocalizedDisplayName
            #            if ($ver -eq  "20H2"){$ver = "2009"} #Another 20H2 naming work around
            Invoke-MSUpdateItemDownload -FilePath "$global:workdir\updates\$Prod\$ver\" -UpdateName $update.LocalizedDisplayName
        }
    }
    } finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Checks downloaded updates for supersedence and removes outdated update files.

.DESCRIPTION
    Scans the local update directory structure for previously downloaded updates and verifies their supersedence
    status against the ConfigMgr software update catalog. Removes update files that have been superseded by newer
    updates. Cleans up empty folders after removing superseded content. Helps maintain a lean update repository
    with only current, applicable updates.

.PARAMETER prod
    The Windows product name: 'Windows 10', 'Windows 11', or 'Windows Server'.

.PARAMETER Ver
    The version identifier (e.g., '22H2', '21H2', '1809', '1607').

.EXAMPLE
    Invoke-MEMCMUpdateSupersedence -prod "Windows 10" -Ver "22H2"
    Removes superseded updates from the Windows 10 22H2 update folder.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module, valid site connection.
    Operates on the local update directory structure: updates\product\version\class\updatename
    Should be run before downloading new updates to maintain folder cleanliness.

.OUTPUTS
    None. Deletes superseded update files and empty folders.
#>
Function Invoke-MEMCMUpdateSupersedence($prod, $Ver) {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $Arch = 'x64'

        if (($prod -eq 'Windows 10') -and (($ver -ge '1903') -or ($ver -eq '20H2') -or ($ver -eq '21H1') -or ($ver -eq '21H2')  )) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'" }
        if (($prod -eq 'Windows 10') -and ($ver -le '1809')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10'" }
        if (($prod -eq 'Windows Server') -and ($ver = '1607')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2016'" }
        if (($prod -eq 'Windows Server') -and ($ver -eq '1809')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2019'" }
        if (($prod -eq 'Windows Server') -and ($ver -eq '21H2')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Microsoft Server operating system-21H2'" }

        Update-Log -data 'Checking files for supersedense...' -Class Information

        if ((Test-Path -Path "$global:workdir\updates\$Prod\$ver\") -eq $False) {
            Update-Log -Data 'Folder doesnt exist. Skipping supersedence check...' -Class Warning
            return
        }

    #For every folder under updates\prod\ver
    $FolderFirstLevels = Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\"
    foreach ($FolderFirstLevel in $FolderFirstLevels) {

        #For every folder under updates\prod\ver\class
        $FolderSecondLevels = Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel"
        foreach ($FolderSecondLevel in $FolderSecondLevels) {

            #for every cab under updates\prod\ver\class\update
            $UpdateCabs = (Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel\$FolderSecondLevel")
            foreach ($UpdateCab in $UpdateCabs) {
                Update-Log -data "Checking update file name $UpdateCab" -Class Information
                $UpdateItem = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.LocalizedDisplayName -eq $FolderSecondLevel) }

                if ($UpdateItem.IsSuperseded -eq $false) {

                    Update-Log -data "Update $FolderSecondLevel is current" -Class Information
                } else {
                    Update-Log -Data "Update $UpdateCab is superseded. Deleting file..." -Class Warning
                    Remove-Item -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel\$FolderSecondLevel\$UpdateCab"
                }
            }
        }
    }

    Update-Log -Data 'Cleaning folders...' -Class Information
    $FolderFirstLevels = Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\"
    foreach ($FolderFirstLevel in $FolderFirstLevels) {

        #For every folder under updates\prod\ver\class
        $FolderSecondLevels = Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel"
        foreach ($FolderSecondLevel in $FolderSecondLevels) {

            #for every cab under updates\prod\ver\class\update
            $UpdateCabs = (Get-ChildItem -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel\$FolderSecondLevel")

            if ($null -eq $UpdateCabs) {
                Update-Log -Data "$FolderSecondLevel is empty. Deleting...." -Class Warning
                Remove-Item -Path "$global:workdir\updates\$Prod\$ver\$FolderFirstLevel\$FolderSecondLevel"
            }
        }
    }
    } finally {
        Pop-Location
    }
    Update-Log -data 'Supersedence check complete' -class Information
}

#Function to update source from ConfigMgr when Making It So
Function Invoke-MISUpdates {

    $OS = get-Windowstype
    $ver = Get-WinVersionNumber

    if ($ver -eq '2009') { $ver = '20H2' }

    Invoke-MEMCMUpdateSupersedence -prod $OS -Ver $ver
    Invoke-MEMCMUpdatecatalog -prod $OS -ver $ver

    #fucking 2009 to 20h2

}

#Function to run the osdsus and osdupdate update check Functions
Function Invoke-OSDCheck {

    Get-OSDBInstallation #Sets OSDUpate version info
    Get-OSDBCurrentVer #Discovers current version of OSDUpdate
    Compare-OSDBuilderVer #determines if an update of OSDUpdate can be applied
    get-osdsusinstallation #Sets OSDSUS version info
    Get-OSDSUSCurrentVer #Discovers current version of OSDSUS
    Compare-OSDSUSVer #determines if an update of OSDSUS can be applied
}

<#
.SYNOPSIS
    Configures properties for a ConfigMgr operating system image package.

.DESCRIPTION
    Updates operating system image package properties in ConfigMgr including version, description,
    Binary Differential Replication, and deployment share settings. Supports both automatic and manual
    version/description assignment. Auto-description mode generates a description listing all applied
    customizations (updates, language packs, drivers, Autopilot, etc.).

.PARAMETER PackageID
    The ConfigMgr Package ID of the operating system image to configure.

.EXAMPLE
    Set-ImageProperties -PackageID "NTP00001"
    Applies configured properties to the OS image package NTP00001.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr PowerShell module and valid site connection.
    Reads configuration from form controls: version, description, Binary Diff Replication, and Deployment Share.
    Auto-version mode uses current date; auto-description mode builds from enabled customizations.

.OUTPUTS
    None. Updates ConfigMgr package properties.
#>
Function Set-ImageProperties($PackageID) {
    #write-host $PackageID
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        #Version Text Box
        if ($WPFCMCBImageVerAuto.IsChecked -eq $true) {
            $string = 'Built ' + (Get-Date -DisplayHint Date)
            Update-Log -Data "Updating image version to $string" -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -Version $string
        }

        if ($WPFCMCBImageVerAuto.IsChecked -eq $false) {

            if ($null -ne $WPFCMTBImageVer.text) {
                Update-Log -Data 'Updating version of the image...' -Class Information
                Set-CMOperatingSystemImage -Id $PackageID -Version $WPFCMTBImageVer.text
            }
        }

        #Description Text Box
        if ($WPFCMCBDescriptionAuto.IsChecked -eq $true) {
            $string = 'This image contains the following customizations: '
            if ($WPFUpdatesEnableCheckBox.IsChecked -eq $true) { $string = $string + 'Software Updates, ' }
            if ($WPFCustomCBLangPacks.IsChecked -eq $true) { $string = $string + 'Language Packs, ' }
            if ($WPFCustomCBLEP.IsChecked -eq $true) { $string = $string + 'Local Experience Packs, ' }
            if ($WPFCustomCBFOD.IsChecked -eq $true) { $string = $string + 'Features on Demand, ' }
            if ($WPFMISDotNetCheckBox.IsChecked -eq $true) { $string = $string + '.Net 3.5, ' }
            if ($WPFMISOneDriveCheckBox.IsChecked -eq $true) { $string = $string + 'OneDrive Consumer, ' }
            if ($WPFAppxCheckBox.IsChecked -eq $true) { $string = $string + 'APPX Removal, ' }
            if ($WPFDriverCheckBox.IsChecked -eq $true) { $string = $string + 'Drivers, ' }
            if ($WPFJSONEnableCheckBox.IsChecked -eq $true) { $string = $string + 'Autopilot, ' }
            if ($WPFCustomCBRunScript.IsChecked -eq $true) { $string = $string + 'Custom Script, ' }
            Update-Log -data 'Setting image description...' -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -Description $string
        }

        if ($WPFCMCBDescriptionAuto.IsChecked -eq $false) {

            if ($null -ne $WPFCMTBDescription.Text) {
                Update-Log -Data 'Updating description of the image...' -Class Information
                Set-CMOperatingSystemImage -Id $PackageID -Description $WPFCMTBDescription.Text
            }
        }

        #Check Box properties
        #Binary Differnential Replication
        if ($WPFCMCBBinDirRep.IsChecked -eq $true) {
            Update-Log -Data 'Enabling Binary Differential Replication' -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -EnableBinaryDeltaReplication $true
        } else {
            Update-Log -Data 'Disabling Binary Differential Replication' -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -EnableBinaryDeltaReplication $false
        }

        #Package Share
        if ($WPFCMCBDeploymentShare.IsChecked -eq $true) {
            Update-Log -Data 'Enabling Package Share' -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -CopyToPackageShareOnDistributionPoint $true
        } else {
            Update-Log -Data 'Disabling Package Share' -Class Information
            Set-CMOperatingSystemImage -Id $PackageID -CopyToPackageShareOnDistributionPoint $false
        }
    } finally {
        Pop-Location
    }

}

<#
.SYNOPSIS
    Detects ConfigMgr installation and retrieves site configuration.

.DESCRIPTION
    Attempts to locate ConfigMgr site information from multiple sources in priority order:
    1. Local registry (HKLM\SOFTWARE\Microsoft\SMS\Identification)
    2. Saved configuration file (ConfigMgr\SiteInfo.XML)
    Sets global ConfigMgr variables (SiteCode, SiteServer, CMDrive) and populates form controls.
    Optionally enables ConfigMgr options if called during new image creation.

.EXAMPLE
    $result = Find-ConfigManager
    Detects ConfigMgr and returns 0 if found, 1 if not detected.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Sets global variables: $global:SiteCode, $global:SiteServer, $global:CMDrive
    Updates form controls: WPFCMTBSiteServer, WPFCMTBSitecode
    Enables ConfigMgr options if $CM variable equals 'New'.

.OUTPUTS
    System.Int32. Returns 0 if ConfigMgr detected, 1 if not detected.
#>
Function Find-ConfigManager() {

    If ((Test-Path -Path HKLM:\SOFTWARE\Microsoft\SMS\Identification) -eq $true) {
        Update-Log -Data 'Site Information found in Registry' -Class Information
        try {

            $MEMCMsiteinfo = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification' -ErrorAction Stop

            $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
            $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'

            #$WPFCMTBSiteServer.text = "nt-tpmemcm.notorious.local"
            #$WPFCMTBSitecode.text = "NTP"

            $global:SiteCode = $WPFCMTBSitecode.text
            $global:SiteServer = $WPFCMTBSiteServer.Text
            $global:CMDrive = $WPFCMTBSitecode.text + ':'

            Update-Log -Data 'ConfigMgr detected and properties set' -Class Information
            Update-Log -Data 'ConfigMgr feature enabled' -Class Information
            $sitecodetext = 'Site Code - ' + $WPFCMTBSitecode.text
            Update-Log -Data $sitecodetext -Class Information
            $siteservertext = 'Site Server - ' + $WPFCMTBSiteServer.text
            Update-Log -Data $siteservertext -Class Information
            if ($CM -eq 'New') {
                $WPFCMCBImageType.SelectedIndex = 1
                Enable-ConfigMgrOptions
            }

            return 0
        } catch {
            Update-Log -Data 'ConfigMgr not detected' -Class Information
            $WPFCMTBSiteServer.text = 'Not Detected'
            $WPFCMTBSitecode.text = 'Not Detected'
            return 1
        }
    }

    if ((Test-Path -Path $global:workdir\ConfigMgr\SiteInfo.XML) -eq $true) {
        Update-Log -data 'ConfigMgr Site info XML found' -class Information

        $settings = Import-Clixml -Path $global:workdir\ConfigMgr\SiteInfo.xml -ErrorAction Stop

        $WPFCMTBSitecode.text = $settings.SiteCode
        $WPFCMTBSiteServer.text = $settings.SiteServer

        Update-Log -Data 'ConfigMgr detected and properties set' -Class Information
        Update-Log -Data 'ConfigMgr feature enabled' -Class Information
        $sitecodetext = 'Site Code - ' + $WPFCMTBSitecode.text
        Update-Log -Data $sitecodetext -Class Information
        $siteservertext = 'Site Server - ' + $WPFCMTBSiteServer.text
        Update-Log -Data $siteservertext -Class Information

        $global:SiteCode = $WPFCMTBSitecode.text
        $global:SiteServer = $WPFCMTBSiteServer.Text
        $global:CMDrive = $WPFCMTBSitecode.text + ':'

        return 0
    }

    Update-Log -Data 'ConfigMgr not detected' -Class Information
    $WPFCMTBSiteServer.text = 'Not Detected'
    $WPFCMTBSitecode.text = 'Not Detected'
    Return 1

}

<#
.SYNOPSIS
    Manually configures ConfigMgr site properties from form input.

.DESCRIPTION
    Sets ConfigMgr site connection properties using values entered in form controls.
    Creates and saves site configuration to XML file for persistence across sessions.
    Establishes global ConfigMgr variables (SiteCode, SiteServer, CMDrive) and logs the configuration.
    Optionally enables ConfigMgr UI options if called during new image creation.

.EXAMPLE
    $result = Set-ConfigMgr
    Configures ConfigMgr using form values and returns 0 on success, 1 on failure.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Sets global variables: $global:SiteCode, $global:SiteServer, $global:CMDrive
    Saves configuration to: workdir\ConfigMgr\SiteInfo.xml
    Enables ConfigMgr options if $CM variable equals 'New'.

.OUTPUTS
    System.Int32. Returns 0 on success, 1 on error.
#>
Function Set-ConfigMgr() {

    try {

        # $MEMCMsiteinfo = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification" -ErrorAction Stop

        # $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
        # $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'

        #$WPFCMTBSiteServer.text = "nt-tpmemcm.notorious.local"
        #$WPFCMTBSitecode.text = "NTP"

        $global:SiteCode = $WPFCMTBSitecode.text
        $global:SiteServer = $WPFCMTBSiteServer.Text
        $global:CMDrive = $WPFCMTBSitecode.text + ':'

        Update-Log -Data 'ConfigMgr detected and properties set' -Class Information
        Update-Log -Data 'ConfigMgr feature enabled' -Class Information
        $sitecodetext = 'Site Code - ' + $WPFCMTBSitecode.text
        Update-Log -Data $sitecodetext -Class Information
        $siteservertext = 'Site Server - ' + $WPFCMTBSiteServer.text
        Update-Log -Data $siteservertext -Class Information

        $CMConfig = @{
            SiteCode   = $WPFCMTBSitecode.text
            SiteServer = $WPFCMTBSiteServer.text
        }
        Update-Log -data 'Saving ConfigMgr site information...'
        $CMConfig | Export-Clixml -Path $global:workdir\ConfigMgr\SiteInfo.xml -ErrorAction Stop

        if ($CM -eq 'New') {
            $WPFCMCBImageType.SelectedIndex = 1
            Enable-ConfigMgrOptions
        }

        return 0
    }

    catch {
        Update-Log -Data 'ConfigMgr not detected' -Class Information
        $WPFCMTBSiteServer.text = 'Not Detected'
        $WPFCMTBSitecode.text = 'Not Detected'
        return 1
    }


}

<#
.SYNOPSIS
    Imports the ConfigMgr PowerShell module.

.DESCRIPTION
    Locates and imports the Configuration Manager PowerShell module using the SMS_ADMIN_UI_PATH environment variable.
    This module is required for all ConfigMgr cmdlet operations including package creation, distribution,
    and site management. Validates successful import and logs the result.

.EXAMPLE
    $result = Import-CMModule
    Imports ConfigMgr module and returns 0 on success, 1 on failure.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: ConfigMgr Console installed on the local machine.
    Depends on SMS_ADMIN_UI_PATH environment variable set by ConfigMgr Console installation.
    Module path: SMS_ADMIN_UI_PATH\ConfigurationManager.psd1

.OUTPUTS
    System.Int32. Returns 0 if module imported successfully, 1 on error.
#>
Function Import-CMModule() {
    try {
        $path = (($env:SMS_ADMIN_UI_PATH -replace 'i386', '') + 'ConfigurationManager.psd1')

        #           $path = "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1"
        Import-Module $path -ErrorAction Stop
        Update-Log -Data 'ConfigMgr PowerShell module imported' -Class Information
        return 0
    }

    catch {
        Update-Log -Data 'Could not import CM PowerShell module.' -Class Warning
        return 1
    }
}

#Function to apply the start menu layout
<#
.SYNOPSIS
    Installs a custom Start Menu layout file into the mounted Windows image.

.DESCRIPTION
    Copies a custom Start Menu layout file into the mounted Windows image's default user profile.
    The function automatically handles Windows 10 (XML format) and Windows 11 (JSON format) layouts.
    Ensures the file is properly renamed to the correct layout filename based on the Windows version:
    - Windows 10: LayoutModification.xml
    - Windows 11: LayoutModification.json

.PARAMETER
    This function uses form variables:
    - $WPFMISMountTextBox.Text: Path to mounted Windows image
    - $WPFCustomTBStartMenu.Text: Path to source Start Menu layout file
    - $Windowstype: Windows version (Windows 11 or Windows 10)

.EXAMPLE
    Install-StartLayout
    Installs the selected Start Menu layout file into the mounted image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Target path: [MountPoint]\users\default\appdata\local\microsoft\windows\shell
    Windows 10 uses XML format, Windows 11 uses JSON format.
    File is automatically renamed if needed to match expected filename.

.OUTPUTS
    None. Logs operations via Update-Log function.
#>
Function Install-StartLayout {
    try {
        $startpath = $WPFMISMountTextBox.Text + '\users\default\appdata\local\microsoft\windows\shell'
        Update-Log -Data 'Copying the start menu file...' -Class Information
        Copy-Item $WPFCustomTBStartMenu.Text -Destination $startpath -ErrorAction Stop
        $filename = (Split-Path -Path $WPFCustomTBStartMenu.Text -Leaf)

        $OS = $Windowstype

        if ($os -eq 'Windows 11') {
            if ($filename -ne 'LayoutModification.json') {
                $newpath = $startpath + '\' + $filename
                Update-Log -Data 'Renaming json file...' -Class Warning
                Rename-Item -Path $newpath -NewName 'LayoutModification.json'
                Update-Log -Data 'file renamed to LayoutModification.json' -Class Information
            }
        }

        if ($os -ne 'Windows 11') {
            if ($filename -ne 'LayoutModification.xml') {
                $newpath = $startpath + '\' + $filename
                Update-Log -Data 'Renaming xml file...' -Class Warning
                Rename-Item -Path $newpath -NewName 'LayoutModification.xml'
                Update-Log -Data 'file renamed to LayoutModification.xml' -Class Information
            }
        }



    } catch {
        Update-Log -Data "Couldn't apply the start menu XML" -Class Error
        Update-Log -data $_.Exception.Message -Class Error
    }
}

#Function to apply the default application association
<#
.SYNOPSIS
    Applies a default application associations XML file to the mounted Windows image.

.DESCRIPTION
    Uses DISM to import a default application associations XML configuration into the mounted
    Windows image. This XML file defines which applications should be the default handlers for
    specific file types and protocols. The associations are applied system-wide and affect all
    user profiles in the deployed image.

.PARAMETER
    This function uses form variables:
    - $WPFMISMountTextBox.text: Path to mounted Windows image
    - $WPFCustomTBDefaultApp.text: Path to default app associations XML file

.EXAMPLE
    Install-DefaultApplicationAssociations
    Applies the selected default application associations XML to the mounted image using DISM.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Uses DISM /Import-DefaultAppAssociations command.
    XML file typically exported from Windows using DISM or Group Policy tools.
    Changes take effect when the image is deployed and Windows starts.

.OUTPUTS
    None. Logs DISM operations via Update-Log function.
#>
Function Install-DefaultApplicationAssociations {
    try {
        Update-Log -Data 'Applying Default Application Association XML...'
        "Dism.exe /image:$WPFMISMountTextBox.text /Import-DefaultAppAssociations:$WPFCustomTBDefaultApp.text"
        Update-log -data 'Default Application Association applied' -Class Information

    } catch {
        Update-Log -Data 'Could not apply Default Appklication Association XML...' -Class Error
        Update-Log -data $_.Exception.Message -Class Error
    }
}

#Function to select default app association xml
<#
.SYNOPSIS
    Prompts user to select an XML file containing default application associations.

.DESCRIPTION
    Opens a file dialog to allow the user to select a Windows default application associations XML file.
    This file defines which applications handle specific file types and protocols.
    Updates the form textbox with the selected file path and validates the file extension.

.EXAMPLE
    Select-DefaultApplicationAssociations
    Opens file dialog to select default application associations XML file.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomTBDefaultApp
    XML file is typically exported from Windows using Windows Settings or Group Policy.

.OUTPUTS
    None. Updates form variable.
#>
Function Select-DefaultApplicationAssociations {

    $Sourcexml = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'XML (*.xml)|'
    }
    $null = $Sourcexml.ShowDialog()
    $WPFCustomTBDefaultApp.text = $Sourcexml.FileName


    if ($Sourcexml.FileName -notlike '*.xml') {
        Update-Log -Data 'A XML file not selected. Please select a valid file to continue.' -Class Warning
        return
    }
    $text = $WPFCustomTBDefaultApp.text + ' selected as the default application XML'
    Update-Log -Data $text -class Information
}

<#
.SYNOPSIS
    Prompts user to select a Start Menu layout file (XML for Windows 10, JSON for Windows 11).

.DESCRIPTION
    Opens a file dialog to allow the user to select a Start Menu layout customization file.
    The file format depends on the detected Windows version:
    - Windows 10 and earlier: XML format (.xml extension)
    - Windows 11: JSON format (.json extension)
    Updates the form textbox with the selected file path and validates the file extension.

.EXAMPLE
    Select-StartMenu
    Opens file dialog to select Start Menu layout file in appropriate format.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomTBStartMenu
    Windows version detected via Get-WindowsType function.
    XML/JSON files can be exported from Windows using Group Policy or custom tools.

.OUTPUTS
    None. Updates form variable.
#>
Function Select-StartMenu {

    $OS = Get-WindowsType

    if ($OS -ne 'Windows 11') {
        $Sourcexml = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter           = 'XML (*.xml)|'
        }
    }

    if ($OS -eq 'Windows 11') {
        $Sourcexml = New-Object System.Windows.Forms.OpenFileDialog -Property @{
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter           = 'JSON (*.JSON)|'
        }
    }

    $null = $Sourcexml.ShowDialog()
    $WPFCustomTBStartMenu.text = $Sourcexml.FileName

    if ($OS -ne 'Windows 11') {
        if ($Sourcexml.FileName -notlike '*.xml') {
            Update-Log -Data 'A XML file not selected. Please select a valid file to continue.' -Class Warning
            return
        }
    }

    if ($OS -eq 'Windows 11') {
        if ($Sourcexml.FileName -notlike '*.json') {
            Update-Log -Data 'A JSON file not selected. Please select a valid file to continue.' -Class Warning
            return
        }
    }




    $text = $WPFCustomTBStartMenu.text + ' selected as the start menu file'
    Update-Log -Data $text -class Information
}

<#
.SYNOPSIS
    Prompts user to select one or more registry files to import.

.DESCRIPTION
    Opens a file dialog with multi-select enabled to allow the user to select one or more
    Windows registry (.reg) files. Validates each file to ensure it has a .reg extension,
    then adds valid files to the form's registry files listbox for injection into the image.
    Invalid files are logged and skipped.

.EXAMPLE
    Select-RegFiles
    Opens multi-select file dialog and adds selected .reg files to import list.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFCustomLBRegistry listbox control
    Supports multi-select for importing multiple registry files at once.
    Only .reg format files are accepted.

.OUTPUTS
    None. Updates form listbox.
#>
Function Select-RegFiles {

    $Regfiles = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Multiselect      = $true # Multiple files can be chosen
        Filter           = 'REG (*.reg)|'
    }
    $null = $Regfiles.ShowDialog()

    $filepaths = $regfiles.FileNames
    Update-Log -data 'Importing REG files...' -class information
    foreach ($filepath in $filepaths) {
        if ($filepath -notlike '*.reg') {
            Update-Log -Data $filepath -Class Warning
            Update-Log -Data 'Ignoring this file as it is not a .REG file....' -Class Warning
            return
        }
        Update-Log -Data $filepath -Class Information
        $WPFCustomLBRegistry.Items.Add($filepath)
    }
    Update-Log -data 'REG file importation complete' -class information

    #Fix this shit, then you can release her.
}

#Function to apply registry files to mounted image
<#
.SYNOPSIS
    Imports registry (.reg) files into the mounted Windows image's offline registry hives.

.DESCRIPTION
    Mounts the offline registry hives from the Windows image, processes and imports selected
    .reg files by remapping registry paths to offline hive locations, then dismounts the hives.
    Supports importing to HKCU (default user), HKU\.DEFAULT, HKLM\SOFTWARE, and HKLM\SYSTEM.

    The function performs the following operations:
    1. Mounts four offline registry hives:
       - HKLM\OfflineDefaultUser (Users\Default\NTUser.dat)
       - HKLM\OfflineDefault (Windows\System32\Config\DEFAULT)
       - HKLM\OfflineSoftware (Windows\System32\Config\SOFTWARE)
       - HKLM\OfflineSystem (Windows\System32\Config\SYSTEM)
    2. Copies each .reg file to staging folder
    3. Parses and replaces registry paths to point to offline hives
    4. Imports modified .reg files using reg.exe
    5. Dismounts all offline registry hives

.PARAMETER
    This function uses form and global variables:
    - $WPFMISMountTextBox.text: Path to mounted Windows image
    - $WPFCustomLBRegistry.items: ListBox containing paths to .reg files
    - $global:workdir: Base working directory for staging files

.EXAMPLE
    Install-RegistryFiles
    Imports all .reg files from the registry listbox into the mounted Windows image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Registry path remapping:
    - HKEY_CURRENT_USER → HKEY_LOCAL_MACHINE\OfflineDefaultUser
    - HKEY_LOCAL_MACHINE\SOFTWARE → HKEY_LOCAL_MACHINE\OfflineSoftware
    - HKEY_LOCAL_MACHINE\SYSTEM → HKEY_LOCAL_MACHINE\OfflineSystem
    - HKEY_USERS\.DEFAULT → HKEY_LOCAL_MACHINE\OfflineDefault

    Registry files are staged to: $global:workdir\staging\
    Failure to dismount hives will prevent proper Windows image dismounting.

.OUTPUTS
    None. Logs all mount/dismount and import operations via Update-Log function.
#>
Function Install-RegistryFiles {

    #mount offline hives
    Update-Log -Data 'Mounting the offline registry hives...' -Class Information

    try {
        $Path = $WPFMISMountTextBox.text + '\Users\Default\NTUser.dat'
        Update-Log -Data $path -Class Information
        Invoke-Command { reg load HKLM\OfflineDefaultUser $Path } -ErrorAction Stop | Out-Null

        $Path = $WPFMISMountTextBox.text + '\Windows\System32\Config\DEFAULT'
        Update-Log -Data $path -Class Information
        Invoke-Command { reg load HKLM\OfflineDefault $Path } -ErrorAction Stop | Out-Null

        $Path = $WPFMISMountTextBox.text + '\Windows\System32\Config\SOFTWARE'
        Update-Log -Data $path -Class Information
        Invoke-Command { reg load HKLM\OfflineSoftware $Path } -ErrorAction Stop | Out-Null

        $Path = $WPFMISMountTextBox.text + '\Windows\System32\Config\SYSTEM'
        Update-Log -Data $path -Class Information
        Invoke-Command { reg load HKLM\OfflineSystem $Path } -ErrorAction Stop | Out-Null
    } catch {
        Update-Log -Data "Failed to mount $Path" -Class Error
        Update-Log -data $_.Exception.Message -Class Error
    }

    #get reg files from list box
    $RegFiles = $WPFCustomLBRegistry.items

    #For Each to process Reg Files and Apply
    Update-Log -Data 'Processing Reg Files...' -Class Information
    foreach ($RegFile in $Regfiles) {

        Update-Log -Data $RegFile -Class Information
        #write-host $RegFile

        Try {
            $Destination = $global:workdir + '\staging\'
            Update-Log -Data 'Copying file to staging folder...' -Class Information
            Copy-Item -Path $regfile -Destination $Destination -Force -ErrorAction Stop  #Copy Source Registry File to staging
        } Catch {
            Update-Log -Data "Couldn't copy reg file" -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

        $regtemp = Split-Path $regfile -Leaf #get file name
        $regpath = $global:workdir + '\staging' + '\' + $regtemp

        # Write-Host $regpath
        Try {
            Update-Log -Data 'Parsing reg file...'
           ((Get-Content -Path $regpath -Raw) -replace 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE\OfflineDefaultUser') | Set-Content -Path $regpath -ErrorAction Stop
           ((Get-Content -Path $regpath -Raw) -replace 'HKEY_LOCAL_MACHINE\\SOFTWARE', 'HKEY_LOCAL_MACHINE\OfflineSoftware') | Set-Content -Path $regpath -ErrorAction Stop
           ((Get-Content -Path $regpath -Raw) -replace 'HKEY_LOCAL_MACHINE\\SYSTEM', 'HKEY_LOCAL_MACHINE\OfflineSystem') | Set-Content -Path $regpath -ErrorAction Stop
           ((Get-Content -Path $regpath -Raw) -replace 'HKEY_USERS\\.DEFAULT', 'HKEY_LOCAL_MACHINE\OfflineDefault') | Set-Content -Path $regpath -ErrorAction Stop
        } Catch {
            Update-log -Data "Couldn't read or update reg file $regpath" -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

        Update-Log -Data 'Reg file has been parsed' -Class Information

        #import the registry file

        Try {
            Update-Log -Data 'Importing registry file into mounted wim' -Class Information
            Start-Process reg -ArgumentList ('import', "`"$RegPath`"") -Wait -WindowStyle Hidden -ErrorAction stop
            Update-Log -Data 'Import successful' -Class Information
        } Catch {
            Update-Log -Data "Couldn't import $Regpath" -Class Error
            Update-Log -data $_.Exception.Message -Class Error

        }
    }


    #dismount offline hives
    try {
        Update-Log -Data 'Dismounting registry...' -Class Information
        Invoke-Command { reg unload HKLM\OfflineDefaultUser } -ErrorAction Stop | Out-Null
        Invoke-Command { reg unload HKLM\OfflineDefault } -ErrorAction Stop | Out-Null
        Invoke-Command { reg unload HKLM\OfflineSoftware } -ErrorAction Stop | Out-Null
        Invoke-Command { reg unload HKLM\OfflineSystem } -ErrorAction Stop | Out-Null
        Update-Log -Data 'Dismount complete' -Class Information
    } catch {
        Update-Log -Data "Couldn't dismount the registry hives" -Class Error
        Update-Log -Data 'This will prevent the Windows image from properly dismounting' -Class Error
        Update-Log -data $_.Exception.Message -Class Error

    }

}

#Function to augment close out window text
<#
.SYNOPSIS
    Retrieves a random dad joke from the icanhazdadjoke.com API.

.DESCRIPTION
    Fetches a random dad joke from the public icanhazdadjoke.com REST API service.
    Returns the joke as a text string for display or logging purposes. Provides a
    lighthearted element to the application and can be used for user engagement
    or Easter egg functionality.

.EXAMPLE
    Invoke-DadJoke
    Returns a random dad joke such as: "Why don't scientists trust atoms? Because they make up everything!"

.EXAMPLE
    $joke = Invoke-DadJoke
    Update-Log -Data $joke -Class Information
    Retrieves a joke and logs it to the application log.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires internet connectivity to access icanhazdadjoke.com API.
    API returns jokes in JSON format with 'joke' property containing the text.

.OUTPUTS
    System.String
    Returns a random dad joke as a plain text string.
#>
Function Invoke-DadJoke {
    $header = @{accept = 'Application/json' }
    $joke = Invoke-RestMethod -Uri 'https://icanhazdadjoke.com' -Method Get -Headers $header
    return $joke.joke
}

#Function to stage and build installer media
<#
.SYNOPSIS
    Copies ISO media binaries from the import folder to a staging directory.

.DESCRIPTION
    Creates a staging folder for media and copies the appropriate OS-specific and version-specific
    ISO binaries from the imports folder structure to the staging\media directory. These staged
    files are then used as the foundation for building new Windows installation media and ISOs.
    Detects Windows type (Windows 10, Windows 11, or Windows Server) automatically.

.PARAMETER
    This function uses global variables:
    - $global:workdir: Base working directory path
    - $MISWinVer: Windows version number for media files

.EXAMPLE
    Copy-StageIsoMedia
    Stages media files for the current Windows type and version to $global:workdir\staging\media

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Creates directory: $global:workdir\staging\Media if it doesn't exist
    Copies from: $global:workdir\imports\iso\[OS]\[Version]\*
    Copies to: $global:workdir\staging\media\*
    Requires ISO binaries to be present in the imports folder

.OUTPUTS
    None. Creates staging directory structure and copies media files.
    Logs all operations via Update-Log function.
#>
Function Copy-StageIsoMedia {
    # if($WPFSourceWIMImgDesTextBox.Text -like '*Windows 10*'){$OS = 'Windows 10'}
    # if($WPFSourceWIMImgDesTextBox.Text -like '*Server*'){$OS = 'Windows Server'}

    $OS = Get-WindowsType


    #$Ver = (Get-WinVersionNumber)
    $Ver = $MISWinVer


    #create staging folder
    try {
        Update-Log -Data 'Creating staging folder for media' -Class Information
        New-Item -Path $global:workdir\staging -Name 'Media' -ItemType Directory -ErrorAction Stop | Out-Null
        Update-Log -Data 'Media staging folder has been created' -Class Information
    } catch {
        Update-Log -Data 'Could not create staging folder' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    #copy source to staging
    try {
        Update-Log -data 'Staging media binaries...' -Class Information
        Copy-Item -Path $global:workdir\imports\iso\$OS\$Ver\* -Destination $global:workdir\staging\media -Force -Recurse -ErrorAction Stop
        Update-Log -data 'Media files have been staged' -Class Information
    } catch {
        Update-Log -Data 'Failed to stage media binaries...' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

}

#Function to create the ISO file from staged installer media
<#
.SYNOPSIS
    Creates a bootable Windows installation ISO file from staged media.

.DESCRIPTION
    Builds a bootable ISO file using the Windows ADK oscdimg.exe tool from previously staged
    media files. Validates the existence of oscdimg.exe, ensures the ISO filename has proper
    extension, and handles file naming conflicts by renaming existing files with backup extensions.
    Uses EFI boot binaries for UEFI compatibility.

.PARAMETER
    This function uses global form variables:
    - $WPFMISTBISOFileName: Desired ISO file name (with or without .iso extension)
    - $WPFMISTBFilePath: Destination folder path for the ISO file

.EXAMPLE
    New-WindowsISO
    Creates a bootable ISO from staged media using the configured filename and location.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires Windows ADK to be installed with oscdimg.exe available
    Source media: $global:workdir\staging\media
    Uses EFI boot file: efisys.bin from the staged media
    Automatically appends .iso extension if not provided
    Renames conflicting existing ISO files before creating new one

.OUTPUTS
    None. Creates ISO file at specified destination.
    Logs all operations and errors via Update-Log function.
#>
Function New-WindowsISO {

    if ((Test-Path -Path ${env:ProgramFiles(x86)}'\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe' -PathType Leaf) -eq $false) {
        Update-Log -Data 'The file oscdimg.exe was not found. Skipping ISO creation...' -Class Error
        return
    }

    If ($WPFMISTBISOFileName.Text -notlike '*.iso') {

        $WPFMISTBISOFileName.Text = $WPFMISTBISOFileName.Text + '.iso'
        Update-Log -Data 'Appending new file name with an extension' -Class Information
    }

    $Location = ${env:ProgramFiles(x86)}
    $executable = $location + '\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe'
    $bootbin = $global:workdir + '\staging\media\efi\microsoft\boot\efisys.bin'
    $source = $global:workdir + '\staging\media'
    $folder = $WPFMISTBFilePath.text
    $file = $WPFMISTBISOFileName.text
    $dest = "$folder\$file"
    $text = "-b$bootbin"

    if ((Test-Path -Path $dest) -eq $true) { Rename-Name -file $dest -extension '.iso' }
    try {
        Update-Log -Data 'Starting to build ISO...' -Class Information
        # write-host $executable
        Start-Process $executable -args @("`"$text`"", '-pEF', '-u1', '-udfver102', "`"$source`"", "`"$dest`"") -Wait -ErrorAction Stop
        Update-Log -Data 'ISO has been built' -Class Information
    } catch {
        Update-Log -Data "Couldn't create the ISO file" -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }
}

#Function to copy staged installer media to CM Package Share
Function Copy-UpgradePackage {
    #copy staging folder to destination with force parameter
    try {
        Update-Log -data 'Copying updated media to Upgrade Package folder...' -Class Information
        Copy-Item -Path $global:workdir\staging\media\* -Destination $WPFMISTBUpgradePackage.text -Force -Recurse -ErrorAction Stop
        Update-Log -Data 'Updated media has been copied' -Class Information
    } catch {
        Update-Log -Data "Couldn't copy the updated media to the upgrade package folder" -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

}

#Function to update the boot wim in the staged installer media folder
<#
.SYNOPSIS
    Updates the boot.wim file with the latest servicing stack and cumulative updates.

.DESCRIPTION
    The Update-BootWIM function processes the boot.wim file by mounting each Windows PE image,
    applying servicing stack updates (SSU) and latest cumulative updates (LCU), then exporting
    and optimizing the updated image. This ensures the Windows PE environment used during
    installation has the latest security and stability improvements.

    The function performs the following operations:
    - Creates a mount point in the staging directory
    - Sets boot.wim file attributes to Normal
    - Mounts each Windows PE image index in boot.wim
    - Applies SSU and LCU updates to each image
    - Dismounts and exports each updated image
    - Overwrites the original boot.wim with the optimized version

.PARAMETER None
    This function does not accept parameters. It operates on the global $workdir variable.

.EXAMPLE
    Update-BootWIM
    Processes and updates the boot.wim file in the staging media sources directory.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: Mounted WIM working directory via $global:workdir
    Dependencies: Deploy-Updates, Update-Log functions
    The function expects boot.wim to be located at $global:workdir\staging\media\sources\boot.wim

.OUTPUTS
    None. Updates boot.wim file in place and logs progress via Update-Log.
#>
Function Update-BootWIM {
    #create mount point in staging

    try {
        Update-Log -Data 'Creating mount point in staging folder...'
        New-Item -Path $global:workdir\staging -Name 'mount' -ItemType Directory -ErrorAction Stop
        Update-Log -Data 'Staging folder mount point created successfully' -Class Information
    } catch {
        Update-Log -data 'Failed to create the staging folder mount point' -Class Error
        Update-Log -data $_.Exception.Message -class Error
        return
    }


    #change attribute of boot.wim
    #Change file attribute to normal
    Update-Log -Data 'Setting file attribute of boot.wim to Normal' -Class Information
    $attrib = Get-Item $global:workdir\staging\media\sources\boot.wim
    $attrib.Attributes = 'Normal'

    $BootImages = Get-WindowsImage -ImagePath $global:workdir\staging\media\sources\boot.wim
    Foreach ($BootImage in $BootImages) {

        #Mount the PE Image
        try {
            $text = 'Mounting PE image number ' + $BootImage.ImageIndex
            Update-Log -data $text -Class Information
            Mount-WindowsImage -ImagePath $global:workdir\staging\media\sources\boot.wim -Path $global:workdir\staging\mount -Index $BootImage.ImageIndex -ErrorAction Stop
        } catch {
            Update-Log -Data 'Could not mount the boot.wim' -Class Error
            Update-Log -data $_.Exception.Message -class Error
            return
        }

        Update-Log -data 'Applying SSU Update' -Class Information
        Deploy-Updates -class 'PESSU'
        Update-Log -data 'Applying LCU Update' -Class Information
        Deploy-Updates -class 'PELCU'

        #Dismount the PE Image
        try {
            Update-Log -data 'Dismounting Windows PE image...' -Class Information
            Dismount-WindowsImage -Path $global:workdir\staging\mount -Save -ErrorAction Stop
        } catch {
            Update-Log -data 'Could not dismount the winpe image.' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }

        #Export the WinPE Image
        Try {
            Update-Log -data 'Exporting WinPE image index...' -Class Information
            Export-WindowsImage -SourceImagePath $global:workdir\staging\media\sources\boot.wim -SourceIndex $BootImage.ImageIndex -DestinationImagePath $global:workdir\staging\tempboot.wim -ErrorAction Stop
        } catch {
            Update-Log -Data 'Failed to export WinPE image' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }

    }

    #Overwrite the stock boot.wim file with the updated one
    try {
        Update-Log -Data 'Overwriting boot.wim with updated and optimized version...' -Class Information
        Move-Item -Path $global:workdir\staging\tempboot.wim -Destination $global:workdir\staging\media\sources\boot.wim -Force -ErrorAction Stop
        Update-Log -Data 'Boot.WIM updated successfully' -Class Information
    } catch {
        Update-Log -Data 'Could not copy the updated boot.wim' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }
}

#Function to update windows recovery in the mounted offline image
<#
.SYNOPSIS
    Updates the Windows Recovery Environment (WinRE) WIM file within a mounted offline image.

.DESCRIPTION
    The Update-WinReWim function updates the winre.wim file that is embedded within a mounted
    Windows offline image. This function is designed to apply updates to the recovery environment
    that is used for system repair and recovery operations.

    The intended workflow includes:
    - Creating a mount point in the staging directory
    - Copying winre.wim from the mounted offline image
    - Changing file attributes of winre.wim to Normal
    - Mounting the staged winre.wim
    - Applying updates to the WinRE environment
    - Dismounting the updated winre.wim
    - Copying the updated WIM back to the mounted offline image

.PARAMETER None
    This function does not accept parameters. It operates on the global $workdir variable.

.EXAMPLE
    Update-WinReWim
    Updates the Windows Recovery Environment within the mounted offline image.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Status: Placeholder function - implementation pending
    Requires: Mounted Windows offline image and $global:workdir
    The function is currently a stub with planned implementation noted in comments.

.OUTPUTS
    None. Will update winre.wim in the mounted offline image when implemented.
#>
Function Update-WinReWim {
    #create mount point in staging
    #copy winre from mounted offline image
    #change attribute of winre.wim
    #mount staged winre.wim
    #update, dismount
    #copy wim back to mounted offline image
}

#Function to retrieve windows version
<#
.SYNOPSIS
    Extracts the Windows marketing version number from a build string.

.DESCRIPTION
    Parses the Windows build number from the WIM version textbox and converts it to
    a marketing version identifier (22H2, 23H2, 24H2, 25H2). Uses regex pattern matching
    to identify Windows 10 and Windows 11 versions. Logs detailed information about
    version detection and warns about unsupported or unknown builds. Only Windows 10 22H2
    and newer Windows 11 versions are supported.

.EXAMPLE
    Get-WinVersionNumber
    Reads $WPFSourceWimVerTextBox and returns '23H2' for Windows 11 23H2.

.EXAMPLE
    Get-WinVersionNumber
    Returns '22H2' and logs info note for any Windows 10 build 10.0.1904*.*

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: $WPFSourceWimVerTextBox form variable to be populated
    Windows 10 Note: All builds 10.0.1904*.* are treated as 22H2 due to inconsistent
    Microsoft build numbering across 2004/20H2/21H1/21H2/22H2 releases.
    Supported Versions:
    - Windows 10 22H2 (19045)
    - Windows 11 23H2 (22631)
    - Windows 11 24H2 (26100)
    - Windows 11 25H2 (26200)

.OUTPUTS
    System.String
    Returns marketing version number:
    - '22H2', '23H2', '24H2', '25H2' for supported versions
    - 'Unsupported' for deprecated Windows 10 builds
    - 'Unknown Version' for unrecognized build numbers
#>
Function Get-WinVersionNumber {
    $buildnum = $null
    $wimBuild = $WPFSourceWimVerTextBox.text

    # Windows 10 and 11 version detection
    switch -Regex ($wimBuild) {
        # Windows 10 - Only 22H2 supported (all 1904*.* builds)
        '10\.0\.1904\d\.\d+' {
            $buildnum = '22H2'
            Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimBuild. Note: Only Windows 10 22H2 is supported. ISO build numbers from Microsoft are inconsistent across 2004/20H2/21H1/21H2/22H2 releases, so all 10.0.1904*.* builds will be treated as 22H2." -Class Information
        }

        # Windows 11 version checks
        '10\.0\.22631\.\d+' { $buildnum = '23H2' }
        '10\.0\.26100\.\d+' { $buildnum = '24H2' }
        '10\.0\.26200\.\d+' { $buildnum = '25H2' }

        # Unsupported Windows 10 builds
        '10\.0\.10\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported. Please use an older version of WIMWitch for legacy Windows 10 builds." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.14393\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimBuild. Only Windows 10 22H2 is supported." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.1[5-8]\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported." -Class Error
            $buildnum = 'Unsupported'
        }

        Default {
            Update-Log -Data "Unknown Windows version: $wimBuild" -Class Warning
            $buildnum = 'Unknown Version'
        }
    }

    return $buildnum
}

<#
.SYNOPSIS
    Prompts user to select a directory for saving ISO files.

.DESCRIPTION
    Opens a folder browser dialog to allow the user to select a destination directory
    where ISO files will be created and saved. Updates the form textbox with the selected path.

.EXAMPLE
    Select-ISODirectory
    Opens folder dialog and updates ISO output directory field.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Updates: $WPFMISTBFilePath
    The selected directory must have sufficient free space for ISO file creation.

.OUTPUTS
    None. Updates form variable.
#>
Function Select-ISODirectory {

    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the folder to save the ISO'
    $null = $browser.ShowDialog()
    $MountDir = $browser.SelectedPath
    $WPFMISTBFilePath.text = $MountDir
    #Test-MountPath -path $WPFMISMountTextBox.text
    Update-Log -Data 'ISO directory selected' -Class Information
}

<#
.SYNOPSIS
    Determines the Windows OS type from the WIM image description.

.DESCRIPTION
    Analyzes the WIM image description field to identify whether the image contains
    Windows 10, Windows 11, or Windows Server. Uses simple text pattern matching
    on the image description to categorize the operating system type. This information
    is used throughout the application for version-specific operations and resource selection.

.EXAMPLE
    Get-WindowsType
    Returns 'Windows 11' if description contains 'Windows 11'

.EXAMPLE
    $osType = Get-WindowsType
    Returns 'Windows Server' if description contains 'Windows Server'

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Requires: $WPFSourceWIMImgDesTextBox form variable to be populated
    The function checks for OS identifiers in this order:
    1. Windows 10
    2. Windows Server
    3. Windows 11

.OUTPUTS
    System.String
    Returns one of: 'Windows 10', 'Windows 11', or 'Windows Server'
    Returns $null if no match is found.
#>
Function Get-WindowsType {
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows 10*') { $type = 'Windows 10' }
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows Server*') { $type = 'Windows Server' }
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows 11*') { $type = 'Windows 11' }

    Return $type
}

#Function to check if ISO binaries exist
<#
.SYNOPSIS
    Verifies that ISO media binaries exist and installs ConfigManager console extensions.

.DESCRIPTION
    Checks for the existence of required ISO media binaries for the current Windows OS type and version.
    If binaries are found, installs ConfigManager console extensions (UpdateWWImage, EditWWImage, and
    NewWWImage) into the SMS admin console. Logs appropriate warnings if required binaries are missing
    and returns False to indicate unavailable media.

.PARAMETER
    This function uses global variables:
    - $global:workdir: Base working directory for imports
    - $env:SMS_ADMIN_UI_PATH: ConfigManager console installation path

.EXAMPLE
    Test-IsoBinariesExist
    Checks for ISO binaries and installs console extensions if binaries are present.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Checks path: $global:workdir\imports\iso\[OSType]\[BuildNumber]\
    Returns $false if binaries are not found
    Installs XML extension files to ConfigManager console if binaries exist
    Creates required console extension directories if needed
    Requires ConfigManager console to be installed for extension installation

.OUTPUTS
    Boolean. Returns $false if ISO binaries are not found.
    Returns $null (implicit $true) if binaries exist and extensions are installed successfully.
#>
Function Test-IsoBinariesExist {
    $buildnum = Get-WinVersionNumber
    $OSType = get-Windowstype


    $ISOFiles = $global:workdir + '\imports\iso\' + $OSType + '\' + $buildnum + '\'

    Test-Path -Path $ISOFiles\*
    if ((Test-Path -Path $ISOFiles\*) -eq $false) {
        $text = 'ISO Binaries are not present for ' + $OSType + ' ' + $buildnum
        Update-Log -Data $text -Class Warning
        Update-Log -data 'Import ISO Binaries from an ISO or disable ISO/Upgrade Package creation' -Class Warning
        return $false
    }

    Update-Log -Data 'Installing ConfigMgr console extension...' -Class Information

    $ConsoleFolderImage = '828a154e-4c7d-4d7f-ba6c-268443cdb4e8' #folder for update and edit

    $ConsoleFolderRoot = 'ac16f420-2d72-4056-a8f6-aef90e66a10c' #folder for new

    $path = ($env:SMS_ADMIN_UI_PATH -replace 'bin\\i386', '') + 'XmlStorage\Extensions\Actions'

    Update-Log -Data 'Creating folders if needed...' -Class Information

    if ((Test-Path -Path (Join-Path -Path $path -ChildPath $ConsoleFolderImage)) -eq $false) { New-Item -Path $path -Name $ConsoleFolderImage -ItemType 'directory' | Out-Null }

    Update-Log -data 'Creating extension files...' -Class Information

    $UpdateWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderImage) + '\UpdateWWImage.xml') -Force
    $EditWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderImage) + '\EditWWImage.xml') -Force

    Update-Log -Data 'Creating folders if needed...' -Class Information

    if ((Test-Path -Path (Join-Path -Path $path -ChildPath $ConsoleFolderRoot)) -eq $false) { New-Item -Path $path -Name $ConsoleFolderRoot -ItemType 'directory' | Out-Null }
    Update-Log -data 'Creating extension files...' -Class Information

    $NewWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderRoot) + '\NewWWImage.xml') -Force

    Update-Log -Data 'Console extension installation complete!' -Class Information
}

#Function to handle 32-Bit PowerSehell
<#
.SYNOPSIS
    Validates and corrects PowerShell architecture compatibility with the operating system.

.DESCRIPTION
    Detects if PowerShell is running in 32-bit mode on a 64-bit operating system.
    If a mismatch is detected, automatically relaunches the script in the correct 64-bit
    PowerShell session, preserving any command-line arguments and execution context.
    This ensures WIM Witch runs with full access to 64-bit system resources and APIs.

.EXAMPLE
    Invoke-ArchitectureCheck
    Checks and corrects PowerShell architecture if needed.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function respects command-line parameters:
    - Auto mode: Preserved with -auto -autofile parameters
    - Configuration Manager mode: Preserved with -CM parameter values (Edit/New)
    Should be invoked at script initialization before other operations.
    Relaunch path: $env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe

.OUTPUTS
    None. Exits script during relaunch if 32-bit mismatch detected.
#>
Function Invoke-ArchitectureCheck {
    if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem) {

        Update-Log -Data 'This is 32-bit PowerShell session. Will relaunch as 64-bit...' -Class Warning

        #The following If statment was pilfered from Michael Niehaus
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {

            if (($auto -eq $false) -and ($CM -eq 'None')) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" }
            if (($auto -eq $true) -and ($null -ne $autofile)) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -auto -autofile $autofile }
            if (($CM -eq 'Edit') -and ($null -ne $autofile)) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -CM Edit -autofile $autofile }
            if ($CM -eq 'New') { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -CM New }

            Exit $lastexitcode
        }
    } else {
        Update-Log -Data 'This is a 64 bit PowerShell session' -Class Information


    }
}

#Function to download and extract the SSU required for 2004/20H2 June '21 LCU
Function Invoke-2XXXPreReq {
    $KB_URI = 'http://download.windowsupdate.com/c/msdownload/update/software/secu/2021/05/windows10.0-kb5003173-x64_375062f9d88a5d9d11c5b99673792fdce8079e09.cab'
    $executable = "$env:windir\system32\expand.exe"
    $mountdir = $WPFMISMountTextBox.Text

    Update-Log -data 'Mounting offline registry and validating UBR / Patch level...' -class Information
    reg LOAD HKLM\OFFLINE $mountdir\Windows\System32\Config\SOFTWARE | Out-Null
    $regvalues = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\OFFLINE\Microsoft\Windows NT\CurrentVersion\' )


    Update-Log -data 'The UBR (Patch Level) is:' -class Information
    Update-Log -data $regvalues.ubr -class information
    reg UNLOAD HKLM\OFFLINE | Out-Null

    if ($null -eq $regvalues.ubr) {
        Update-Log -data "Registry key wasn't copied. Can't continue." -class Error
        return 1
    }

    if ($regvalues.UBR -lt '985') {

        Update-Log -data 'The image requires an additional required SSU.' -class Information
        Update-Log -data 'Checking to see if the required SSU exists...' -class Information
        if ((Test-Path "$global:workdir\updates\Windows 10\2XXX_prereq\SSU-19041.985-x64.cab") -eq $false) {
            Update-Log -data 'The required SSU does not exist. Downloading it now...' -class Information

            try {
                Invoke-WebRequest -Uri $KB_URI -OutFile "$global:workdir\staging\extract_me.cab" -ErrorAction stop
            } catch {
                Update-Log -data 'Failed to download the update' -class Error
                Update-Log -data $_.Exception.Message -Class Error
                return 1
            }

            if ((Test-Path "$global:workdir\updates\Windows 10\2XXX_prereq") -eq $false) {


                try {
                    Update-Log -data 'The folder for the required SSU does not exist. Creating it now...' -class Information
                    New-Item -Path "$global:workdir\updates\Windows 10" -Name '2XXX_prereq' -ItemType Directory -ErrorAction stop | Out-Null
                    Update-Log -data 'The folder has been created' -class information
                } catch {
                    Update-Log -data 'Could not create the required folder.' -class error
                    Update-Log -data $_.Exception.Message -Class Error
                    return 1
                }
            }

            try {
                Update-Log -data 'Extracting the SSU from the May 2021 LCU...' -class Information
                Start-Process $executable -args @("`"$global:workdir\staging\extract_me.cab`"", '/f:*SSU*.CAB', "`"$global:workdir\updates\Windows 10\2XXX_prereq`"") -Wait -ErrorAction Stop
                Update-Log 'Extraction of SSU was success' -class information
            } catch {
                Update-Log -data "Couldn't extract the SSU from the LCU" -class error
                Update-Log -data $_.Exception.Message -Class Error
                return 1

            }


            try {
                Update-Log -data 'Deleting the staged LCU file...' -class Information
                Remove-Item -Path $global:workdir\staging\extract_me.cab -Force -ErrorAction stop | Out-Null
                Update-Log -data 'The source file for the SSU has been Baleeted!' -Class Information
            } catch {
                Update-Log -data 'Could not delete the source package' -Class Error
                Update-Log -data $_.Exception.Message -Class Error
                return 1
            }
        } else {
            Update-Log -data 'The required SSU exists. No need to download' -Class Information
        }

        try {
            Update-Log -data 'Applying the SSU...' -class Information
            Add-WindowsPackage -PackagePath "$global:workdir\updates\Windows 10\2XXX_prereq" -Path $WPFMISMountTextBox.Text -ErrorAction Stop | Out-Null
            Update-Log -data 'SSU applied successfully' -class Information

        } catch {
            Update-Log -data "Couldn't apply the SSU update" -class error
            Update-Log -data $_.Exception.Message -Class Error
            return 1
        }
    } else {
        Update-Log -Data "Image doesn't require the prereq SSU" -Class Information
    }

    Update-Log -data 'SSU remdiation complete' -Class Information
    return 0
}

#Function to display text notification to end user
<#
.SYNOPSIS
    Logs a visual separator in the application log for improved readability.

.DESCRIPTION
    Creates a visual break in the log output by writing two lines of asterisks.
    This provides visual separation between different operational sections or phases,
    making logs easier to read and navigate. Often used to mark the beginning or end
    of significant operations or to draw attention to important log sections.

.EXAMPLE
    Invoke-TextNotification
    Writes two comment lines of asterisks to the log.

.EXAMPLE
    Update-Log -Data 'Starting new operation' -Class Information
    Invoke-TextNotification
    Marks the start of a new operation with visual separation.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    Uses Update-Log function with 'Comment' class for formatting.
    Each line contains 33 asterisk characters.

.OUTPUTS
    None. Writes formatted separator lines to the application log.
#>
Function Invoke-TextNotification {
    Update-Log -data '*********************************' -class Comment
    Update-Log -data '*********************************' -class Comment
}

# Invoke-19041Select function removed - Windows 10 22H2 is auto-detected from build 1904*.*
# Legacy Windows 10 versions are no longer supported

#Function for the Make it So button
<#
.SYNOPSIS
    Orchestrates the complete Windows image customization and build process.

.DESCRIPTION
    This is the primary orchestration function that coordinates all aspects of WIM image creation
    and customization in WIMWitch-tNG. It performs comprehensive validation, executes the multi-stage
    build workflow, and handles all image modifications including mounting, patching, driver injection,
    application removal, and exporting. The function processes GUI selections or configuration file
    settings to create a fully customized Windows deployment image.

    The workflow includes:
    - Preflight validation (mount path, file names, free space, dependencies)
    - Source WIM copying and index selection
    - WIM mounting and verification
    - Language packs, Features on Demand, and Local Experience Packs injection
    - .NET Framework binary injection
    - Autopilot JSON provisioning
    - Driver injection from multiple sources
    - Default application associations and Start Menu layout customization
    - Registry file application
    - Windows Update integration (SSU, LCU, Optional, Dynamic)
    - OneDrive installer updates
    - AppX package removal
    - Custom PowerShell script execution at configurable stages
    - User-interactive pause points (optional)
    - WIM dismount and export
    - ConfigMgr integration (package creation/update)
    - Boot.WIM updates
    - ISO creation
    - Upgrade package preparation

.PARAMETER appx
    An array containing the list of AppX packages to remove from the image.
    This parameter is typically populated from the selected items in the AppX removal
    interface or from the configuration file's SelectedAppx property.

.EXAMPLE
    Invoke-MakeItSo -appx @('Microsoft.BingWeather', 'Microsoft.ZuneMusic')
    Starts the complete image customization process, removing the specified AppX packages.

.EXAMPLE
    Invoke-MakeItSo -appx $global:SelectedAppx
    Executes the image build using the globally stored AppX removal list.

.NOTES
    Author: Eden Nelson
    Version: 1.0
    This function is the core of WIMWitch-tNG and coordinates all image modification operations.
    It relies on numerous WPF form controls for settings (WPFMISWimNameTextBox, WPFMISMountTextBox, etc.)
    and calls many helper functions for specific tasks.
    Execution can take considerable time depending on selected options (updates, drivers, etc.).
    All operations are logged via Update-Log for troubleshooting and audit purposes.
    On error, the function returns early with appropriate logging; successful completion results in
    a customized WIM file in the target location and optionally in ConfigMgr or as an ISO.

.OUTPUTS
    None. All output is via Update-Log function. Creates customized WIM file, optional ISO,
    and optional ConfigMgr package. Returns early on validation failures or user cancellation.
#>
Function Invoke-MakeItSo ($appx) {
    #Check if new file name is valid, also append file extension if neccessary

    ###Starting MIS Preflight###
    Test-MountPath -path $WPFMISMountTextBox.Text -clean True

    if (($WPFMISWimNameTextBox.Text -eq '') -or ($WPFMISWimNameTextBox.Text -eq 'Enter Target WIM Name')) {
        Update-Log -Data 'Enter a valid file name and then try again' -Class Error
        return
    }


    if (($auto -eq $false) -and ($WPFCMCBImageType.SelectedItem -ne 'Update Existing Image' )) {

        $checkresult = (Test-Name)
        if ($checkresult -eq 'stop') { return }
    }


    #check for working directory, make if does not exist, delete files if they exist
    Update-Log -Data 'Checking to see if the staging path exists...' -Class Information

    try {
        if (!(Test-Path "$global:workdir\Staging" -PathType 'Any')) {
            New-Item -ItemType Directory -Force -Path $global:workdir\Staging -ErrorAction Stop
            Update-Log -Data 'Path did not exist, but it does now' -Class Information -ErrorAction Stop
        } else {
            Remove-Item -Path $global:workdir\Staging\* -Recurse -ErrorAction Stop
            Update-Log -Data 'The path existed, and it has been purged.' -Class Information -ErrorAction Stop
        }
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "Something is wrong with folder $global:workdir\Staging. Try deleting manually if it exists" -Class Error
        return
    }

    if ($WPFJSONEnableCheckBox.IsChecked -eq $true) {
        Update-Log -Data 'Validating existance of JSON file...' -Class Information
        $APJSONExists = (Test-Path $WPFJSONTextBox.Text)
        if ($APJSONExists -eq $true) { Update-Log -Data 'JSON exists. Continuing...' -Class Information }
        else {
            Update-Log -Data 'The Autopilot file could not be verified. Check it and try again.' -Class Error
            return
        }

    }

    if ($WPFMISDotNetCheckBox.IsChecked -eq $true) {
        if ((Test-DotNetExists) -eq $False) { return }
    }


    #Check for free space
    if ($SkipFreeSpaceCheck -eq $false) {
        if (Test-FreeSpace -eq 1) {
            Update-Log -Data 'Insufficient free space. Delete some files and try again' -Class Error
            return
        } else {
            Update-Log -Data 'There is sufficient free space.' -Class Information
        }
    }
    #####End of MIS Preflight###################################################################

    #Copy source WIM
    Update-Log -Data 'Copying source WIM to the staging folder' -Class Information

    try {
        Copy-Item $WPFSourceWIMSelectWIMTextBox.Text -Destination "$global:workdir\Staging" -ErrorAction Stop
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -Data "The file couldn't be copied. No idea what happened" -class Error
        return
    }

    Update-Log -Data 'Source WIM has been copied to the source folder' -Class Information

    #Rename copied source WiM

    try {
        $wimname = Get-Item -Path $global:workdir\Staging\*.wim -ErrorAction Stop
        Rename-Item -Path $wimname -NewName $WPFMISWimNameTextBox.Text -ErrorAction Stop
        Update-Log -Data 'Copied source WIM has been renamed' -Class Information
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "The copied source file couldn't be renamed. This shouldn't have happened." -Class Error
        Update-Log -data "Go delete the WIM from $global:workdir\Staging\, then try again" -Class Error
        return
    }

    #Remove the unwanted indexes
    Remove-OSIndex

    #Mount the WIM File
    $wimname = Get-Item -Path $global:workdir\Staging\*.wim
    Update-Log -Data "Mounting source WIM $wimname" -Class Information
    Update-Log -Data 'to mount point:' -Class Information
    Update-Log -data $WPFMISMountTextBox.Text -Class Information

    try {
        Mount-WindowsImage -Path $WPFMISMountTextBox.Text -ImagePath $wimname -Index 1 -ErrorAction Stop | Out-Null
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "The WIM couldn't be mounted. Make sure the mount directory is empty" -Class Error
        Update-Log -Data "and that it isn't an active mount point" -Class Error
        return
    }

    #checks to see if the iso binaries exist. Cancel and discard WIM if they are not present.
    If (($WPFMISCBISO.IsChecked -eq $true) -or ($WPFMISCBUpgradePackage.IsChecked -eq $true)) {

        if ((Test-IsoBinariesExist) -eq $False) {
            Update-Log -Data 'Discarding WIM and not making it so' -Class Error
            Dismount-WindowsImage -Path $WPFMISMountTextBox.Text -Discard -ErrorAction Stop | Out-Null
            return
        }
    }

    #Get Mounted WIM version and save it to a variable for useage later in the Function
    $MISWinVer = (Get-WinVersionNumber)


    #Pause after mounting
    If ($WPFMISCBPauseMount.IsChecked -eq $True) {
        Update-Log -Data 'Pausing image building. Waiting on user to continue...' -Class Warning
        $Pause = Suspend-MakeItSo
        if ($Pause -eq 'Yes') { Update-Log -data 'Continuing on with making it so...' -Class Information }
        if ($Pause -eq 'No') {
            Update-Log -data 'Discarding build...' -Class Error
            Update-Log -Data 'Discarding mounted WIM' -Class Warning
            Dismount-WindowsImage -Path $WPFMISMountTextBox.Text -Discard -ErrorAction Stop | Out-Null
            Update-Log -Data 'WIM has been discarded. Better luck next time.' -Class Warning
            return
        }
    }

    #Run Script after mounting
    if (($WPFCustomCBRunScript.IsChecked -eq $True) -and ($WPFCustomCBScriptTiming.SelectedItem -eq 'After image mount')) {
        Update-Log -data 'Running PowerShell script...' -Class Information
        Start-Script -file $WPFCustomTBFile.text -parameter $WPFCustomTBParameters.text
        Update-Log -data 'Script completed.' -Class Information
    }

    #Language Packs and FOD
    if ($WPFCustomCBLangPacks.IsChecked -eq $true) {
        Install-LanguagePacks
    } else {
        Update-Log -Data 'Language Packs Injection not selected. Skipping...'
    }

    if ($WPFCustomCBLEP.IsChecked -eq $true) {
        Install-LocalExperiencePack
    } else {
        Update-Log -Data 'Local Experience Packs not selected. Skipping...'
    }

    if ($WPFCustomCBFOD.IsChecked -eq $true) {
        Install-FeaturesOnDemand
    } else {
        Update-Log -Data 'Features On Demand not selected. Skipping...'
    }

    #Inject .Net Binaries
    if ($WPFMISDotNetCheckBox.IsChecked -eq $true) { Add-DotNet }

    #Inject Autopilot JSON file
    if ($WPFJSONEnableCheckBox.IsChecked -eq $true) {
        Update-Log -Data 'Injecting JSON file' -Class Information
        try {
            $autopilotdir = $WPFMISMountTextBox.Text + '\windows\Provisioning\Autopilot'
            Copy-Item $WPFJSONTextBox.Text -Destination $autopilotdir -ErrorAction Stop
        } catch {
            Update-Log -data $_.Exception.Message -class Error
            Update-Log -data "JSON file couldn't be copied. Check to see if the correct SKU" -Class Error
            Update-Log -Data 'of Windows has been selected' -Class Error
            Update-log -Data "The WIM is still mounted. You'll need to clean that up manually until" -Class Error
            Update-Log -data 'I get around to handling that error more betterer' -Class Error
            return
        }
    } else {
        Update-Log -Data 'JSON not selected. Skipping JSON Injection' -Class Information
    }

    #Inject Drivers
    If ($WPFDriverCheckBox.IsChecked -eq $true) {
        Start-DriverInjection -Folder $WPFDriverDir1TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir2TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir3TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir4TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir5TextBox.text
    } Else {
        Update-Log -Data 'Drivers were not selected for injection. Skipping.' -Class Information
    }

    #Inject default application association XML
    if ($WPFCustomCBEnableApp.IsChecked -eq $true) {
        Install-DefaultApplicationAssociations
    } else {
        Update-Log -Data 'Default Application Association not selected. Skipping...' -Class Information
    }

    #Inject start menu layout
    if ($WPFCustomCBEnableStart.IsChecked -eq $true) {
        Install-StartLayout
    } else {
        Update-Log -Data 'Start Menu Layout injection not selected. Skipping...' -Class Information
    }

    #apply registry files
    if ($WPFCustomCBEnableRegistry.IsChecked -eq $true) {
        Install-RegistryFiles
    } else {
        Update-Log -Data 'Registry file injection not selected. Skipping...' -Class Information
    }

    #Check for updates when ConfigMgr source is selected
    if ($WPFMISCBCheckForUpdates.IsChecked -eq $true) {
        Invoke-MISUpdates
        if (($WPFSourceWIMImgDesTextBox.text -like '*Windows 10*') -or ($WPFSourceWIMImgDesTextBox.text -like '*Windows 11*')) { Get-OneDrive }
    }

    #Apply Updates
    If ($WPFUpdatesEnableCheckBox.IsChecked -eq $true) {
        Deploy-Updates -class 'SSU'
        Deploy-Updates -class 'LCU'
        Deploy-Updates -class 'AdobeSU'
        Deploy-Updates -class 'DotNet'
        Deploy-Updates -class 'DotNetCU'
        #if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True){Deploy-Updates -class "Dynamic"}
        if ($WPFUpdatesOptionalEnableCheckBox.IsChecked -eq $True) {
            Deploy-Updates -class 'Optional'
        }
    } else {
        Update-Log -Data 'Updates not enabled' -Class Information
    }

    #Copy the current OneDrive installer
    if ($WPFMISOneDriveCheckBox.IsChecked -eq $true) {
        $os = Get-WindowsType
        $build = Get-WinVersionNumber

        if (($os -eq 'Windows 11') -and ($build -eq '22H2') -or ($build -eq '23H2')) {
            Copy-OneDrivex64
        } else {
            Copy-OneDrive
        }
    } else {
        Update-Log -data 'OneDrive agent update skipped as it was not selected' -Class Information
    }

    #Remove AppX Packages
    if ($WPFAppxCheckBox.IsChecked -eq $true) {
        Remove-Appx -array $appx
    } Else {
        Update-Log -Data 'App removal not enabled' -Class Information
    }

    #Run Script before dismount
    if (($WPFCustomCBRunScript.IsChecked -eq $True) -and ($WPFCustomCBScriptTiming.SelectedItem -eq 'Before image dismount')) {
        Start-Script -file $WPFCustomTBFile.text -parameter $WPFCustomTBParameters.text
    }

    #Pause before dismounting
    If ($WPFMISCBPauseDismount.IsChecked -eq $True) {
        Update-Log -Data 'Pausing image building. Waiting on user to continue...' -Class Warning
        $Pause = Suspend-MakeItSo
        if ($Pause -eq 'Yes') { Update-Log -data 'Continuing on with making it so...' -Class Information }
        if ($Pause -eq 'No') {
            Update-Log -data 'Discarding build...' -Class Error
            Update-Log -Data 'Discarding mounted WIM' -Class Warning
            Dismount-WindowsImage -Path $WPFMISMountTextBox.Text -Discard -ErrorAction Stop | Out-Null
            Update-Log -Data 'WIM has been discarded. Better luck next time.' -Class Warning
            return
        }
    }

    #Copy log to mounted WIM
    try {
        Update-Log -Data 'Attempting to copy log to mounted image' -Class Information
        $mountlogdir = $WPFMISMountTextBox.Text + '\windows\'
        Copy-Item $global:workdir\logging\WIMWitch-tNG.log -Destination $mountlogdir -ErrorAction Stop
        $CopyLogExist = Test-Path $mountlogdir\WIMWitch-tNG.log -PathType Leaf
        if ($CopyLogExist -eq $true) { Update-Log -Data 'Log filed copied successfully' -Class Information }
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "Coudn't copy the log file to the mounted image." -class Error
    }

    #Dismount, commit, and move WIM
    Update-Log -Data 'Dismounting WIM file, committing changes' -Class Information
    try {
        Dismount-WindowsImage -Path $WPFMISMountTextBox.Text -Save -ErrorAction Stop | Out-Null
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "The WIM couldn't save. You will have to manually discard the" -Class Error
        Update-Log -data 'mounted image manually' -Class Error
        return
    }
    Update-Log -Data 'WIM dismounted' -Class Information

    #Display new version number
    $WimInfo = (Get-WindowsImage -ImagePath $wimname -Index 1)
    $text = 'New image version number is ' + $WimInfo.Version
    Update-Log -data $text -Class Information

    if (($auto -eq $true) -or ($WPFCMCBImageType.SelectedItem -eq 'Update Existing Image')) {
        Update-Log -Data 'Backing up old WIM file...' -Class Information
        $checkresult = (Test-Name -conflict append)
        if ($checkresult -eq 'stop') { return }
    }

    #stage media if check boxes are selected
    if (($WPFMISCBUpgradePackage.IsChecked -eq $true) -or ($WPFMISCBISO.IsChecked -eq $true)) {
        Copy-StageIsoMedia
        Update-Log -Data 'Exporting install.wim to media staging folder...' -Class Information
        Export-WindowsImage -SourceImagePath $wimname -SourceIndex 1 -DestinationImagePath ($global:workdir + '\staging\media\sources\install.wim') -DestinationName ('WW - ' + $WPFSourceWIMImgDesTextBox.text) | Out-Null
    }

    #Export the wim file to various locations
    if ($WPFMISCBNoWIM.IsChecked -ne $true) {
        try {
            Update-Log -Data 'Exporting WIM file' -Class Information
            Export-WindowsImage -SourceImagePath $wimname -SourceIndex 1 -DestinationImagePath ($WPFMISWimFolderTextBox.Text + '\' + $WPFMISWimNameTextBox.Text) -DestinationName ('WW - ' + $WPFSourceWIMImgDesTextBox.text) | Out-Null
        } catch {
            Update-Log -data $_.Exception.Message -class Error
            Update-Log -data "The WIM couldn't be exported. You can still retrieve it from staging path." -Class Error
            Update-Log -data 'The file will be deleted when the tool is rerun.' -Class Error
            return
        }
        Update-Log -Data 'WIM successfully exported to target folder' -Class Information
    }

    #ConfigMgr Integration
    if ($WPFCMCBImageType.SelectedItem -ne 'Disabled') {
        #  "New Image","Update Existing Image"
        if ($WPFCMCBImageType.SelectedItem -eq 'New Image') {
            Update-Log -data 'Creating a new image in ConfigMgr...' -class Information
            New-CMImagePackage
        }

        if ($WPFCMCBImageType.SelectedItem -eq 'Update Existing Image') {
            Update-Log -data 'Updating the existing image in ConfigMgr...' -class Information
            Update-CMImage
        }
    }

    #Apply Dynamic Update to media
    if ($WPFMISCBDynamicUpdates.IsChecked -eq $true) {
        Deploy-Updates -class 'Dynamic'
    } else {
        Update-Log -data 'Dynamic Updates skipped or not applicable' -Class Information
    }

    #Apply updates to the boot.wim file
    if ($WPFMISCBBootWIM.IsChecked -eq $true) {
        Update-BootWIM
    } else {
        Update-Log -data 'Updating Boot.WIM skipped or not applicable' -Class Information
    }

    #Copy upgrade package binaries if selected
    if ($WPFMISCBUpgradePackage.IsChecked -eq $true) {
        Copy-UpgradePackage
    } else {
        Update-Log -Data 'Upgrade Package skipped or not applicable' -Class Information
    }

    #Create ISO if selected
    if ($WPFMISCBISO.IsChecked -eq $true) {
        New-WindowsISO
    } else {
        Update-Log -Data 'ISO Creation skipped or not applicable' -Class Information
    }

    #Run Script when build complete
    if (($WPFCustomCBRunScript.IsChecked -eq $True) -and ($WPFCustomCBScriptTiming.SelectedItem -eq 'On build completion')) {
        Start-Script -file $WPFCustomTBFile.text -parameter $WPFCustomTBParameters.text
    }

    #Clear out staging folder
    try {
        Update-Log -Data 'Clearing staging folder...' -Class Information
        Remove-Item $global:workdir\staging\* -Force -Recurse -ErrorAction Stop
    } catch {
        Update-Log -Data 'Could not clear staging folder' -Class Warning
        Update-Log -data $_.Exception.Message -class Error
    }

    #Copy log here
    try {
        Update-Log -Data 'Copying build log to target folder' -Class Information
        Copy-Item -Path $global:workdir\logging\WIMWitch-tNG.log -Destination $WPFMISWimFolderTextBox.Text -ErrorAction Stop
        $logold = $WPFMISWimFolderTextBox.Text + '\WIMWitch-tNG.log'
        $lognew = $WPFMISWimFolderTextBox.Text + '\' + $WPFMISWimNameTextBox.Text + '.log'
        #Put log detection code here
        if ((Test-Path -Path $lognew) -eq $true) {
            Update-Log -Data 'A preexisting log file contains the same name. Renaming old log...' -Class Warning
            Rename-Name -file $lognew -extension '.log'
        }

        #Put log detection code here
        Rename-Item $logold -NewName $lognew -Force -ErrorAction Stop
        Update-Log -Data 'Log copied successfully' -Class Information
    } catch {
        Update-Log -data $_.Exception.Message -class Error
        Update-Log -data "The log file couldn't be copied and renamed. You can still snag it from the source." -Class Error
        Update-Log -Data "Job's done." -Class Information
        return
    }
    Update-Log -Data "Job's done." -Class Information
}

