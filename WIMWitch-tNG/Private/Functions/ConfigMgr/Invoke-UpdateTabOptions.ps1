Function Invoke-UpdateTabOptions {

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'None' ) {

        $WPFUpdateOSDBUpdateButton.IsEnabled = $false
        $WPFUpdatesDownloadNewButton.IsEnabled = $false
        $WPFUpdatesW10Main.IsEnabled = $false

        $WPFMISCBCheckForUpdates.IsEnabled = $false
        $WPFMISCBCheckForUpdates.IsChecked = $false

    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'OSDSUS') {
        $WPFUpdateOSDBUpdateButton.IsEnabled = $true
        $WPFUpdatesDownloadNewButton.IsEnabled = $true
        $WPFUpdatesW10Main.IsEnabled = $true

        $WPFMISCBCheckForUpdates.IsEnabled = $false
        $WPFMISCBCheckForUpdates.IsChecked = $false
        Update-Log -data 'OSDSUS selected as update catalog' -class Information
        Invoke-OSDCheck

    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'ConfigMgr') {
        $WPFUpdateOSDBUpdateButton.IsEnabled = $false
        $WPFUpdatesDownloadNewButton.IsEnabled = $true
        $WPFUpdatesW10Main.IsEnabled = $true
        $WPFMISCBCheckForUpdates.IsEnabled = $true
        #        $MEMCMsiteinfo = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification"

        #   $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
        #   $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'
        Update-Log -data 'ConfigMgr is selected as the update catalog' -Class Information

    }

}
