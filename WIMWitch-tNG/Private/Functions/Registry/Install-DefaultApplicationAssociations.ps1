Function Install-DefaultApplicationAssociations {
    try {
        Update-Log -Data 'Applying Default Application Association XML...'
        "Dism.exe /image:$WPFMISMountTextBox.text /Import-DefaultAppAssociations:$WPFCustomTBDefaultApp.text"
        Update-log -data 'Default Application Association applied' -Class Information

    } catch {
        Update-Log -Data 'Could not apply Default Appklication Association XML...' -Class Error
        Update-Log -data $_.Exception.Message -Class Error
    }
}
