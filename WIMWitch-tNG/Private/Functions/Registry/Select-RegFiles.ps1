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
