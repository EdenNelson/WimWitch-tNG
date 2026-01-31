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
