Function Get-OSDSUSInstallation {
    Update-Log -Data 'Getting OSDSUS Installation information' -Class 'Information'
    try {
        Import-Module -Name OSDSUS -ErrorAction Stop
    } catch {
        $WPFUpdatesOSDSUSVersion.Text = 'Not Installed'

        Update-Log -Data 'OSDSUS is not installed.' -Class Warning
        Return
    }
    try {
        $OSDSUSVersion = Get-Module -Name OSDSUS -ErrorAction Stop
        $WPFUpdatesOSDSUSVersion.Text = $OSDSUSVersion.Version
        $text = $osdsusversion.version
        Update-Log -data "Installed version of OSDSUS is $text." -Class Information
        Return
    } catch {
        Update-Log -Data 'Unable to fetch OSDSUS version.' -Class Error
        Return
    }
}
