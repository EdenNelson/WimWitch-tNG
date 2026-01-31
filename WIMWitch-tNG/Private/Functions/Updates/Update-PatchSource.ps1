Function Update-PatchSource {

    Update-Log -Data 'attempting to start download Function' -Class Information
    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'OSDSUS') {
        if ($WPFUpdatesW10Main.IsChecked -eq $true) {
            if ($WPFUpdatesW10_22H2.IsChecked -eq $true) {
                Test-Superceded -action delete -build 22H2 -OS 'Windows 10'
                Get-WindowsPatches -build 22H2 -OS 'Windows 10'
            }
        }
        if ($WPFUpdatesS2019.IsChecked -eq $true) {
            Test-Superceded -action delete -build 1809 -OS 'Windows Server'
            Get-WindowsPatches -build 1809 -OS 'Windows Server'
        }
        if ($WPFUpdatesS2016.IsChecked -eq $true) {
            Test-Superceded -action delete -build 1607 -OS 'Windows Server'
            Get-WindowsPatches -build 1607 -OS 'Windows Server'
        }
        if ($WPFUpdatesS2022.IsChecked -eq $true) {
            Test-Superceded -action delete -build 21H2 -OS 'Windows Server'
            Get-WindowsPatches -build 21H2 -OS 'Windows Server'
        }

        if ($WPFUpdatesW11Main.IsChecked -eq $true) {
            if ($WPFUpdatesW11_23h2.IsChecked -eq $true) {
                Write-Host '23H2'
                Test-Superceded -action delete -build 23H2 -OS 'Windows 11'
                Get-WindowsPatches -build 23H2 -OS 'Windows 11'
            }
            if ($WPFUpdatesW11_24h2.IsChecked -eq $true) {
                Write-Host '24H2'
                Test-Superceded -action delete -build 24H2 -OS 'Windows 11'
                Get-WindowsPatches -build 24H2 -OS 'Windows 11'
            }
            if ($WPFUpdatesW11_25h2.IsChecked -eq $true) {
                Write-Host '25H2'
                Test-Superceded -action delete -build 25H2 -OS 'Windows 11'
                Get-WindowsPatches -build 25H2 -OS 'Windows 11'
            }

        }
        Get-OneDrive
    }

    if ($WPFUSCBSelectCatalogSource.SelectedItem -eq 'ConfigMgr') {
        if ($WPFUpdatesW10Main.IsChecked -eq $true) {
            if ($WPFUpdatesW10_22H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 10' -Ver '22H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 10' -ver '22H2'
            }
            #Get-OneDrive
        }
        if ($WPFUpdatesS2019.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '1809'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '1809'
        }
        if ($WPFUpdatesS2016.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '1607'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '1607'
        }
        if ($WPFUpdatesS2022.IsChecked -eq $true) {
            Invoke-MEMCMUpdateSupersedence -prod 'Windows Server' -Ver '21H2'
            Invoke-MEMCMUpdatecatalog -prod 'Windows Server' -Ver '21H2'
        }
        if ($WPFUpdatesW11Main.IsChecked -eq $true) {
            if ($WPFUpdatesW11_23H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '23H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '23H2'
            }
            if ($WPFUpdatesW11_24H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '24H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '24H2'
            }
            if ($WPFUpdatesW11_25H2.IsChecked -eq $true) {
                Invoke-MEMCMUpdateSupersedence -prod 'Windows 11' -Ver '25H2'
                Invoke-MEMCMUpdatecatalog -prod 'Windows 11' -ver '25H2'
            }
        }
        Get-OneDrive
    }
    Update-Log -data 'All downloads complete' -class Information
}
