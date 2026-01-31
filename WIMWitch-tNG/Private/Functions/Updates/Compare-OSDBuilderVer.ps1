Function Compare-OSDBuilderVer {
    Update-Log -data 'Comparing OSD Update module versions' -Class Information
    if ($WPFUpdatesOSDBVersion.Text -eq 'Not Installed') {
        Return
    }
    If ($WPFUpdatesOSDBVersion.Text -eq $WPFUpdatesOSDBCurrentVerTextBox.Text) {
        Update-Log -Data 'OSD Update is up to date' -class Information
        Return
    }
    Update-Log -Data 'OSD Update appears to be out of date. Please click the Install / Update button to update it.' -class Warning
    Update-Log -Data 'OSD Update appears to be out of date. Run the upgrade Function from within WIM Witch to resolve' -class Warning

    Return
}
