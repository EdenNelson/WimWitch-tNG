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
