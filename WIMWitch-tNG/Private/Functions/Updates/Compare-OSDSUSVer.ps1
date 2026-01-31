Function Compare-OSDSUSVer {
    Update-Log -data 'Comparing OSDSUS module versions' -Class Information
    if ($WPFUpdatesOSDSUSVersion.Text -eq 'Not Installed') {
        Return
    }
    If ($WPFUpdatesOSDSUSVersion.Text -eq $WPFUpdatesOSDSUSCurrentVerTextBox.Text) {
        Update-Log -Data 'OSDSUS is up to date' -class Information
        Return
    }
    Update-Log -Data 'OSDSUS appears to be out of date. Please click the Install / Update button to update it.' -class Warning
    Update-Log -Data 'OSDSUS appears to be out of date. Run the upgrade Function from within WIM Witch to resolve' -class Warning

    Return
}
