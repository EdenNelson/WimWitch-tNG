Function Find-ConfigManager() {

    If ((Test-Path -Path HKLM:\SOFTWARE\Microsoft\SMS\Identification) -eq $true) {
        Update-Log -Data 'Site Information found in Registry' -Class Information
        try {

            $MEMCMsiteinfo = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\Identification' -ErrorAction Stop

            $WPFCMTBSiteServer.text = $MEMCMsiteinfo.'Site Server'
            $WPFCMTBSitecode.text = $MEMCMsiteinfo.'Site Code'

            #$WPFCMTBSiteServer.text = "nt-tpmemcm.notorious.local"
            #$WPFCMTBSitecode.text = "NTP"

            $global:SiteCode = $WPFCMTBSitecode.text
            $global:SiteServer = $WPFCMTBSiteServer.Text
            $global:CMDrive = $WPFCMTBSitecode.text + ':'

            Update-Log -Data 'ConfigMgr detected and properties set' -Class Information
            Update-Log -Data 'ConfigMgr feature enabled' -Class Information
            $sitecodetext = 'Site Code - ' + $WPFCMTBSitecode.text
            Update-Log -Data $sitecodetext -Class Information
            $siteservertext = 'Site Server - ' + $WPFCMTBSiteServer.text
            Update-Log -Data $siteservertext -Class Information
            if ($CM -eq 'New') {
                $WPFCMCBImageType.SelectedIndex = 1
                Enable-ConfigMgrOptions
            }

            return 0
        } catch {
            Update-Log -Data 'ConfigMgr not detected' -Class Information
            $WPFCMTBSiteServer.text = 'Not Detected'
            $WPFCMTBSitecode.text = 'Not Detected'
            return 1
        }
    }

    if ((Test-Path -Path $global:workdir\ConfigMgr\SiteInfo.XML) -eq $true) {
        Update-Log -data 'ConfigMgr Site info XML found' -class Information

        $settings = Import-Clixml -Path $global:workdir\ConfigMgr\SiteInfo.xml -ErrorAction Stop

        $WPFCMTBSitecode.text = $settings.SiteCode
        $WPFCMTBSiteServer.text = $settings.SiteServer

        Update-Log -Data 'ConfigMgr detected and properties set' -Class Information
        Update-Log -Data 'ConfigMgr feature enabled' -Class Information
        $sitecodetext = 'Site Code - ' + $WPFCMTBSitecode.text
        Update-Log -Data $sitecodetext -Class Information
        $siteservertext = 'Site Server - ' + $WPFCMTBSiteServer.text
        Update-Log -Data $siteservertext -Class Information

        $global:SiteCode = $WPFCMTBSitecode.text
        $global:SiteServer = $WPFCMTBSiteServer.Text
        $global:CMDrive = $WPFCMTBSitecode.text + ':'

        return 0
    }

    Update-Log -Data 'ConfigMgr not detected' -Class Information
    $WPFCMTBSiteServer.text = 'Not Detected'
    $WPFCMTBSitecode.text = 'Not Detected'
    Return 1

}
