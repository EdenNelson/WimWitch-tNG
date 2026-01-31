Function Select-ImportOtherPath {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Source folder'
    $null = $browser.ShowDialog()
    $ImportPath = $browser.SelectedPath + '\'
    $WPFImportOtherTBPath.text = $ImportPath

}
