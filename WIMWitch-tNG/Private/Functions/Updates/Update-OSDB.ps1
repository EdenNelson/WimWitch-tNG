Function Update-OSDB {
    if ($WPFUpdatesOSDBVersion.Text -eq 'Not Installed') {
        Update-Log -Data 'Attempting to install and import OSD Update' -Class Information
        try {
            Install-Module OSDUpdate -Force -ErrorAction Stop
            #Write-Host "Installed module"
            Update-Log -data 'OSD Update module has been installed' -Class Information
            Import-Module -Name OSDUpdate -Force -ErrorAction Stop
            #Write-Host "Imported module"
            Update-Log -Data 'OSD Update module has been imported' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')
            Return
        } catch {
            $WPFUpdatesOSDBVersion.Text = 'Inst Fail'
            Update-Log -Data "Couldn't install OSD Update" -Class Error
            Update-Log -data $_.Exception.Message -class Error
            Return
        }
    }

    If ($WPFUpdatesOSDBVersion.Text -gt '1.0.0') {
        Update-Log -data 'Attempting to update OSD Update' -class Information
        try {
            Update-ModuleOSDUpdate -ErrorAction Stop
            Update-Log -Data 'Updated OSD Update' -Class Information
            Update-Log -Data '****************************************************************************' -Class Warning
            Update-Log -Data 'Please close WIM Witch and all PowerShell windows, then rerun to continue...' -Class Warning
            Update-Log -Data '****************************************************************************' -Class Warning
            #$WPFUpdatesOSDBClosePowerShellTextBlock.visibility = "Visible"
            $WPFUpdatesOSDListBox.items.add('Please close all PowerShell windows, including WIM Witch, then relaunch app to continue')

            get-OSDBInstallation
            return
        } catch {
            $WPFUpdatesOSDBCurrentVerTextBox.Text = 'OSDB Err'
            Return
        }
    }
}
