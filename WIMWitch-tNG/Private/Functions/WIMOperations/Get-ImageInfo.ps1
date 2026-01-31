Function Get-ImageInfo {
    Param(
        [parameter(mandatory = $true)]
        [string]$PackID

    )


    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $image = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_ImagePackage -ComputerName $global:SiteServer) | Where-Object { ($_.PackageID -eq $PackID) }

        $WPFCMTBImageName.text = $image.name
        $WPFCMTBWinBuildNum.text = $image.ImageOSversion
        $WPFCMTBPackageID.text = $image.PackageID
        $WPFCMTBImageVer.text = $image.version
        $WPFCMTBDescription.text = $image.Description

        $text = 'Image ' + $WPFCMTBImageName.text + ' selected'
        Update-Log -data $text -class Information

        $text = 'Package ID is ' + $image.PackageID
        Update-Log -data $text -class Information

        $text = 'Image build number is ' + $image.ImageOSversion
        Update-Log -data $text -class Information

        $packageID = (Get-CMOperatingSystemImage -Id $image.PackageID)
        # $packageID.PkgSourcePath

        $WPFMISWimFolderTextBox.text = (Split-Path -Path $packageID.PkgSourcePath)
        $WPFMISWimNameTextBox.text = (Split-Path -Path $packageID.PkgSourcePath -Leaf)

        $Package = $packageID.PackageID
        $DPs = Get-CMDistributionPoint
        $NALPaths = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -ComputerName $global:SiteServer -Query "SELECT * FROM SMS_DistributionPoint WHERE PackageID='$Package'")

        Update-Log -Data 'Retrieving Distrbution Point Information' -Class Information
        foreach ($NALPath in $NALPaths) {
            foreach ($dp in $dps) {
                $DPPath = $dp.NetworkOSPath
                if ($NALPath.ServerNALPath -like ("*$DPPath*")) {
                    Update-Log -data "Image has been previously distributed to $DPPath" -class Information
                    $WPFCMLBDPs.Items.Add($DPPath)

                }
            }
        }

        #Detect Binary Diff Replication
        Update-Log -data 'Checking Binary Differential Replication setting' -Class Information
        if ($image.PkgFlags -eq ($image.PkgFlags -bor 0x04000000)) {
            $WPFCMCBBinDirRep.IsChecked = $True
        } else {
            $WPFCMCBBinDirRep.IsChecked = $False
        }

        #Detect Package Share Enabled
        Update-Log -data 'Checking package share settings' -Class Information
        if ($image.PkgFlags -eq ($image.PkgFlags -bor 0x80)) {
            $WPFCMCBDeploymentShare.IsChecked = $true
        } else
        { $WPFCMCBDeploymentShare.IsChecked = $false }
    } finally {
        Pop-Location
    }
}
