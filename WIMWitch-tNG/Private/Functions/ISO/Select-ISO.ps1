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
