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
