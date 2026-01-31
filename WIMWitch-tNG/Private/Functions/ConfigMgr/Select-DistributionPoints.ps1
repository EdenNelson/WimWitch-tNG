Function Select-DistributionPoints {
    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Points') {

            $SelectedDPs = (Get-CMDistributionPoint -SiteCode $global:sitecode).NetworkOSPath | Out-GridView -Title 'Select Distribution Points' -PassThru
            foreach ($SelectedDP in $SelectedDPs) { $WPFCMLBDPs.Items.Add($SelectedDP) }
        }
        if ($WPFCMCBDPDPG.SelectedItem -eq 'Distribution Point Groups') {
            $SelectedDPs = (Get-CMDistributionPointGroup).Name | Out-GridView -Title 'Select Distribution Point Groups' -PassThru
            foreach ($SelectedDP in $SelectedDPs) { $WPFCMLBDPs.Items.Add($SelectedDP) }
        }
    } finally {
        Pop-Location
    }
}
