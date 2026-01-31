Function Update-Autopilot {
    Update-Log -Data 'Uninstalling old WindowsAutopilotIntune module...' -Class Warning
    Uninstall-Module -Name WindowsAutopilotIntune -AllVersions
    Update-Log -Data 'Installing new WindowsAutopilotIntune module...' -Class Warning
    Install-Module -Name WindowsAutopilotIntune -Force
    $AutopilotUpdate = ([System.Windows.MessageBox]::Show('WIM Witch needs to close and PowerShell needs to be restarted. Click OK to close WIM Witch.', 'Updating complete.', 'OK', 'warning'))
    if ($AutopilotUpdate -eq 'OK') {
        $form.Close()
        exit
    }
}
