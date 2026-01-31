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
