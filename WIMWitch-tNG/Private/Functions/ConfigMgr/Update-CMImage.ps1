Function Update-CMImage {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $wmi = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_ImagePackage -ComputerName $global:SiteServer) | Where-Object { $_.PackageID -eq $WPFCMTBPackageID.text }



        Update-Log -Data 'Updating images on the Distribution Points...'
        $WMI.RefreshPkgSource() | Out-Null

        Update-Log -Data 'Refreshing image proprties from the WIM' -Class Information
        $WMI.ReloadImageProperties() | Out-Null

        Set-ImageProperties -PackageID $WPFCMTBPackageID.Text
        Save-Configuration -CM -filename $WPFCMTBPackageID.Text
    } finally {
        Pop-Location
    }
}
