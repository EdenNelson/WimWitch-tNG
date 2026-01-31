Function Get-OSDSUSCurrentVer {
    Update-Log -Data 'Checking for the most current OSDSUS version available' -Class Information
    try {
        $OSDSUSCurrentVer = Find-Module -Name OSDSUS -ErrorAction Stop
        $WPFUpdatesOSDSUSCurrentVerTextBox.Text = $OSDSUSCurrentVer.version
        $text = $OSDSUSCurrentVer.version
        Update-Log -data "$text is the most current version" -class Information
        Return
    } catch {
        $WPFUpdatesOSDSUSCurrentVerTextBox.Text = 'Network Error'
        Return
    }
}
