Function New-CMImagePackage {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $Path = $WPFMISWimFolderTextBox.text + '\' + $WPFMISWimNameTextBox.text

        try {
            New-CMOperatingSystemImage -Name $WPFCMTBImageName.text -Path $Path -ErrorAction Stop
            Update-Log -data 'Image was created. Check ConfigMgr console' -Class Information
        } catch {
            Update-Log -data 'Failed to create the image' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

        $PackageID = (Get-CMOperatingSystemImage -Name $WPFCMTBImageName.text).PackageID
        Update-Log -Data "The Package ID of the new image is $PackageID" -Class Information

        Set-ImageProperties -PackageID $PackageID

        Update-Log -Data 'Retriveing Distribution Point information...' -Class Information
        $DPs = $WPFCMLBDPs.Items

        foreach ($DP in $DPs) {
            # Hello! This line was written on 3/3/2020.
            $DP = $DP -replace '\\', ''

            Update-Log -Data 'Distributiong image package content...' -Class Information
            if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Points') {
                Start-CMContentDistribution -OperatingSystemImageId $PackageID -DistributionPointName $DP
            }
            if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Point Groups') {
                Start-CMContentDistribution -OperatingSystemImageId $PackageID -DistributionPointGroupName $DP
            }

            Update-Log -Data 'Content has been distributed.' -Class Information
        }

        Save-Configuration -CM $PackageID
    } finally {
        Pop-Location
    }
}
