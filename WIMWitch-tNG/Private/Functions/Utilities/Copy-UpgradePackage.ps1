Function Copy-UpgradePackage {
    #copy staging folder to destination with force parameter
    try {
        Update-Log -data 'Copying updated media to Upgrade Package folder...' -Class Information
        Copy-Item -Path $global:workdir\staging\media\* -Destination $WPFMISTBUpgradePackage.text -Force -Recurse -ErrorAction Stop
        Update-Log -Data 'Updated media has been copied' -Class Information
    } catch {
        Update-Log -Data "Couldn't copy the updated media to the upgrade package folder" -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

}
