Function Remove-Appx($array) {
    $exappxs = $array
    Update-Log -data 'Starting AppX removal' -class Information
    foreach ($exappx in $exappxs) {
        try {
            Remove-AppxProvisionedPackage -Path $WPFMISMountTextBox.Text -PackageName $exappx -ErrorAction Stop | Out-Null
            Update-Log -data "Removing $exappx" -Class Information
        } catch {
            Update-Log -Data "Failed to remove $exappx" -Class Error
            Update-Log -Data $_.Exception.Message -Class Error
        }
    }
    return
}
