Function Select-Config {
    $SourceXML = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = "$global:workdir\Configs"
        Filter           = 'XML (*.XML)|'
    }
    $null = $SourceXML.ShowDialog()
    $WPFSLLoadTextBox.text = $SourceXML.FileName
    Get-Configuration -filename $WPFSLLoadTextBox.text
}
