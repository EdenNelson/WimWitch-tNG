Function Select-DriverSource($DriverTextBoxNumber) {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the Driver Source folder'
    $null = $browser.ShowDialog()
    $DriverDir = $browser.SelectedPath
    $DriverTextBoxNumber.Text = $DriverDir
    Update-Log -Data "Driver path selected: $DriverDir" -Class Information
}
