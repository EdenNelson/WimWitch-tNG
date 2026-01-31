Function Get-Configuration($filename) {
    Update-Log -data "Importing config from $filename" -Class Information
    try {
        # Determine if file is PSD1 or XML format based on extension
        if ($filename -match '\.psd1$') {
            $settings = Import-PowerShellDataFile -Path $filename -ErrorAction Stop
        }
        else {
            $settings = Import-Clixml -Path $filename -ErrorAction Stop
        }
        Update-Log -data 'Config file read...' -Class Information
        $WPFSourceWIMSelectWIMTextBox.text = $settings.SourcePath
        $WPFSourceWimIndexTextBox.text = $settings.SourceIndex
        $WPFSourceWIMImgDesTextBox.text = $settings.SourceEdition
        $WPFUpdatesEnableCheckBox.IsChecked = $settings.UpdatesEnabled
        $WPFJSONEnableCheckBox.IsChecked = $settings.AutopilotEnabled
        $WPFJSONTextBox.text = $settings.AutopilotPath
        $WPFDriverCheckBox.IsChecked = $settings.DriversEnabled
        # Load UseDismRecurse with null-safe default for backward compatibility
        if ($null -ne $settings.UseDismRecurse) {
            $WPFDriverDismRecurseCheckBox.IsChecked = $settings.UseDismRecurse
        } else {
            $WPFDriverDismRecurseCheckBox.IsChecked = $false
        }
        $WPFDriverDir1TextBox.text = $settings.DriverPath1
        $WPFDriverDir2TextBox.text = $settings.DriverPath2
        $WPFDriverDir3TextBox.text = $settings.DriverPath3
        $WPFDriverDir4TextBox.text = $settings.DriverPath4
        $WPFDriverDir5TextBox.text = $settings.DriverPath5
        $WPFAppxCheckBox.IsChecked = $settings.AppxIsEnabled
        $WPFAppxTextBox.text = $settings.AppxSelected -split ' '
        $WPFMISWimNameTextBox.text = $settings.WIMName
        $WPFMISWimFolderTextBox.text = $settings.WIMPath
        $WPFMISMountTextBox.text = $settings.MountPath
        $global:SelectedAppx = $settings.AppxSelected -split ' '
        $WPFMISDotNetCheckBox.IsChecked = $settings.DotNetEnabled
        $WPFMISOneDriveCheckBox.IsChecked = $settings.OneDriveEnabled
        $WPFCustomCBLangPacks.IsChecked = $settings.LPsEnabled
        $WPFCustomCBLEP.IsChecked = $settings.LXPsEnabled
        $WPFCustomCBFOD.IsChecked = $settings.FODsEnabled

        $WPFMISCBPauseMount.IsChecked = $settings.PauseAfterMount
        $WPFMISCBPauseDismount.IsChecked = $settings.PauseBeforeDM
        $WPFCustomCBRunScript.IsChecked = $settings.RunScript
        $WPFCustomCBScriptTiming.SelectedItem = $settings.ScriptTiming
        $WPFCustomTBFile.Text = $settings.ScriptFile
        $WPFCustomTBParameters.Text = $settings.ScriptParams
        $WPFCMCBImageType.SelectedItem = $settings.CMImageType
        $WPFCMTBPackageID.Text = $settings.CMPackageID
        $WPFCMTBImageName.Text = $settings.CMImageName
        $WPFCMTBImageVer.Text = $settings.CMVersion
        $WPFCMTBDescription.Text = $settings.CMDescription
        $WPFCMCBBinDirRep.IsChecked = $settings.CMBinDifRep
        $WPFCMTBSitecode.Text = $settings.CMSiteCode
        $WPFCMTBSiteServer.Text = $settings.CMSiteServer
        $WPFCMCBDPDPG.SelectedItem = $settings.CMDPGroup
        $WPFUSCBSelectCatalogSource.SelectedItem = $settings.UpdateSource
        $WPFMISCBCheckForUpdates.IsChecked = $settings.UpdateMIS

        $WPFCMCBImageVerAuto.IsChecked = $settings.AutoFillVersion
        $WPFCMCBDescriptionAuto.IsChecked = $settings.AutoFillDesc

        $WPFCustomCBEnableApp.IsChecked = $settings.DefaultAppCB
        $WPFCustomTBDefaultApp.Text = $settings.DefaultAppPath
        $WPFCustomCBEnableStart.IsChecked = $settings.StartMenuCB
        $WPFCustomTBStartMenu.Text = $settings.StartMenuPath
        $WPFCustomCBEnableRegistry.IsChecked = $settings.RegFilesCB
        # Legacy controls - skip if they don't exist
        if (Get-Variable -Name WPFUpdatesCBEnableOptional -ErrorAction SilentlyContinue) {
            $WPFUpdatesCBEnableOptional.IsChecked = $settings.SUOptional
        }
        if (Get-Variable -Name WPFUpdatesCBEnableDynamic -ErrorAction SilentlyContinue) {
            $WPFUpdatesCBEnableDynamic.IsChecked = $settings.SUDynamic
        }

        $WPFMISCBDynamicUpdates.IsChecked = $settings.ApplyDynamicCB
        $WPFMISCBBootWIM.IsChecked = $settings.UpdateBootCB
        $WPFMISCBNoWIM.IsChecked = $settings.DoNotCreateWIMCB
        $WPFMISCBISO.IsChecked = $settings.CreateISO
        $WPFMISTBISOFileName.Text = $settings.ISOFileName
        $WPFMISTBFilePath.Text = $settings.ISOFilePath
        $WPFMISCBUpgradePackage.IsChecked = $settings.UpgradePackageCB
        $WPFMISTBUpgradePackage.Text = $settings.UpgradePackPath
        $WPFUpdatesOptionalEnableCheckBox.IsChecked = $settings.IncludeOptionCB

        $WPFSourceWimTBVersionNum.text = $settings.SourceVersion

        $LEPs = $settings.LPListBox
        $LXPs = $settings.LXPListBox
        $FODs = $settings.FODListBox
        $DPs = $settings.CMDPList
        $REGs = $settings.RegFilesLB



        Update-Log -data 'Configration set' -class Information

        Update-Log -data 'Clearing list boxes...' -Class Information
        $WPFCustomLBLangPacks.Items.Clear()
        $WPFCustomLBLEP.Items.Clear()
        $WPFCustomLBFOD.Items.Clear()
        $WPFCMLBDPs.Items.Clear()
        $WPFCustomLBRegistry.Items.Clear()


        Update-Log -data 'Populating list boxes...' -class Information
        foreach ($LEP in $LEPs) { $WPFCustomLBLangPacks.Items.Add($LEP) | Out-Null }
        foreach ($LXP in $LXPs) { $WPFCustomLBLEP.Items.Add($LXP) | Out-Null }
        foreach ($FOD in $FODs) { $WPFCustomLBFOD.Items.Add($FOD) | Out-Null }
        foreach ($DP in $DPs) { $WPFCMLBDPs.Items.Add($DP) | Out-Null }
        foreach ($REG in $REGs) { $WPFCustomLBRegistry.Items.Add($REG) | Out-Null }


        Import-WimInfo -IndexNumber $WPFSourceWimIndexTextBox.text -SkipUserConfirmation

        if ($WPFJSONEnableCheckBox.IsChecked -eq $true) {

            Invoke-ParseJSON -file $WPFJSONTextBox.text
        }

        if ($WPFCMCBImageType.SelectedItem -eq 'Update Existing Image') {
            # Only attempt to get image info if SiteServer is set
            if ($global:SiteServer) {
                try {
                    Get-ImageInfo -PackID $settings.CMPackageID
                } catch {
                    Update-Log -data "Could not retrieve ConfigMgr image info: $($_.Exception.Message)" -Class Warning
                }
            }
        }

        Reset-MISCheckBox

    }

    catch {
        Update-Log -data "Could not import from $filename" -Class Error
        Update-Log -data "Error details: $($_.Exception.Message)" -Class Error
    }

    # Invoke-CheckboxCleanup removed - Windows 10 version checkboxes no longer exist
    Update-Log -data 'Config file loaded successfully' -Class Information
}
