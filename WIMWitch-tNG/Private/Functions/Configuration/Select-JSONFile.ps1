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
