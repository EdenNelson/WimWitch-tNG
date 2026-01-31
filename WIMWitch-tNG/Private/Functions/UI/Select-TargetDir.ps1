Function Select-TargetDir {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the target folder'
    $null = $browser.ShowDialog()
    $TargetDir = $browser.SelectedPath
    $WPFMISWimFolderTextBox.text = $TargetDir #I SCREWED UP THIS VARIABLE
    Update-Log -Data 'Target directory selected' -Class Information
}
