Function Get-OSDBCurrentVer {
    Update-Log -Data 'Checking for the most current OSDUpdate version available' -Class Information
    try {
        $OSDBCurrentVer = Find-Module -Name OSDUpdate -ErrorAction Stop
        $WPFUpdatesOSDBCurrentVerTextBox.Text = $OSDBCurrentVer.version
        $text = $OSDBCurrentVer.version
        Update-Log -data "$text is the most current version" -class Information
        Return
    } catch {
        $WPFUpdatesOSDBCurrentVerTextBox.Text = 'Network Error'
        Return
    }
}
