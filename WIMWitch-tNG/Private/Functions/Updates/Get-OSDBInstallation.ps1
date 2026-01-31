Function Get-OSDBInstallation {
    Update-Log -Data 'Getting OSD Installation information' -Class Information
    try {
        Import-Module -Name OSDUpdate -ErrorAction Stop
    } catch {
        $WPFUpdatesOSDBVersion.Text = 'Not Installed.'
        Update-Log -Data 'OSD Update is not installed.' -Class Warning
        Return
    }
    try {
        $OSDBVersion = Get-Module -Name OSDUpdate -ErrorAction Stop
        $WPFUpdatesOSDBVersion.Text = $OSDBVersion.Version
        $text = $osdbversion.version
        Update-Log -data "Installed version of OSD Update is $text." -Class Information
        Return
    } catch {
        Update-Log -Data 'Unable to fetch OSD Update version.' -Class Error
        Return
    }
}
