Function Save-Configuration {
    Param(
        [parameter(mandatory = $false, HelpMessage = 'config file')]
        [string]$filename,

        [parameter(mandatory = $false, HelpMessage = 'enable CM files')]
        [switch]$CM
    )

    $CurrentConfig = @{
        SourcePath       = $WPFSourceWIMSelectWIMTextBox.text
        SourceIndex      = $WPFSourceWimIndexTextBox.text
        SourceEdition    = $WPFSourceWIMImgDesTextBox.text
        UpdatesEnabled   = $WPFUpdatesEnableCheckBox.IsChecked
        AutopilotEnabled = $WPFJSONEnableCheckBox.IsChecked
        AutopilotPath    = $WPFJSONTextBox.text
        DriversEnabled   = $WPFDriverCheckBox.IsChecked
        UseDismRecurse   = $WPFDriverDismRecurseCheckBox.IsChecked
        DriverPath1      = $WPFDriverDir1TextBox.text
        DriverPath2      = $WPFDriverDir2TextBox.text
        DriverPath3      = $WPFDriverDir3TextBox.text
        DriverPath4      = $WPFDriverDir4TextBox.text
        DriverPath5      = $WPFDriverDir5TextBox.text
        AppxIsEnabled    = $WPFAppxCheckBox.IsChecked
        AppxSelected     = $WPFAppxTextBox.Text
        WIMName          = $WPFMISWimNameTextBox.text
        WIMPath          = $WPFMISWimFolderTextBox.text
        MountPath        = $WPFMISMountTextBox.text
        DotNetEnabled    = $WPFMISDotNetCheckBox.IsChecked
        OneDriveEnabled  = $WPFMISOneDriveCheckBox.IsChecked
        LPsEnabled       = $WPFCustomCBLangPacks.IsChecked
        LXPsEnabled      = $WPFCustomCBLEP.IsChecked
        FODsEnabled      = $WPFCustomCBFOD.IsChecked
        LPListBox        = $WPFCustomLBLangPacks.items
        LXPListBox       = $WPFCustomLBLEP.Items
        FODListBox       = $WPFCustomLBFOD.Items
        PauseAfterMount  = $WPFMISCBPauseMount.IsChecked
        PauseBeforeDM    = $WPFMISCBPauseDismount.IsChecked
        RunScript        = $WPFCustomCBRunScript.IsChecked
        ScriptTiming     = $WPFCustomCBScriptTiming.SelectedItem
        ScriptFile       = $WPFCustomTBFile.Text
        ScriptParams     = $WPFCustomTBParameters.Text
        CMImageType      = $WPFCMCBImageType.SelectedItem
        CMPackageID      = $WPFCMTBPackageID.Text
        CMImageName      = $WPFCMTBImageName.Text
        CMVersion        = $WPFCMTBImageVer.Text
        CMDescription    = $WPFCMTBDescription.Text
        CMBinDifRep      = $WPFCMCBBinDirRep.IsChecked
        CMSiteCode       = $WPFCMTBSitecode.Text
        CMSiteServer     = $WPFCMTBSiteServer.Text
        CMDPGroup        = $WPFCMCBDPDPG.SelectedItem
        CMDPList         = $WPFCMLBDPs.Items
        UpdateSource     = $WPFUSCBSelectCatalogSource.SelectedItem
        UpdateMIS        = $WPFMISCBCheckForUpdates.IsChecked
        AutoFillVersion  = $WPFCMCBImageVerAuto.IsChecked
        AutoFillDesc     = $WPFCMCBDescriptionAuto.IsChecked
        DefaultAppCB     = $WPFCustomCBEnableApp.IsChecked
        DefaultAppPath   = $WPFCustomTBDefaultApp.Text
        StartMenuCB      = $WPFCustomCBEnableStart.IsChecked
        StartMenuPath    = $WPFCustomTBStartMenu.Text
        RegFilesCB       = $WPFCustomCBEnableRegistry.IsChecked
        RegFilesLB       = $WPFCustomLBRegistry.Items
        SUOptional       = $WPFUpdatesCBEnableOptional.IsChecked
        SUDynamic        = $WPFUpdatesCBEnableDynamic.IsChecked

        ApplyDynamicCB   = $WPFMISCBDynamicUpdates.IsChecked
        UpdateBootCB     = $WPFMISCBBootWIM.IsChecked
        DoNotCreateWIMCB = $WPFMISCBNoWIM.IsChecked
        CreateISO        = $WPFMISCBISO.IsChecked
        ISOFileName      = $WPFMISTBISOFileName.Text
        ISOFilePath      = $WPFMISTBFilePath.Text
        UpgradePackageCB = $WPFMISCBUpgradePackage.IsChecked
        UpgradePackPath  = $WPFMISTBUpgradePackage.Text
        IncludeOptionCB  = $WPFUpdatesOptionalEnableCheckBox.IsChecked

        SourceVersion    = $WPFSourceWimTBVersionNum.text
    }

    if ($CM -eq $False) {

        Update-Log -data "Saving configuration file $filename" -Class Information

        # Ensure filename has .psd1 extension
        if ($filename -notmatch '\.psd1$') {
            $filename = [System.IO.Path]::ChangeExtension($filename, '.psd1')
        }

        try {
            # Save as PSD1 format (PowerShell Data File)
            $PSD1Lines = @('@{')
            foreach ($key in $CurrentConfig.Keys | Sort-Object) {
                $value = $CurrentConfig[$key]
                $formattedValue = if ($null -eq $value) {
                    '$null'
                } elseif ($value -is [bool]) {
                    if ($value) { '$true' } else { '$false' }
                } elseif ($value -is [int]) {
                    $value
                } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                    $items = @($value | ForEach-Object {
                        if ($_ -is [string]) {
                            "'$($_ -replace "'", "''")'"
                        } else {
                            "'$($_.ToString() -replace "'", "''")'"
                        }
                    })
                    if ($items.Count -eq 0) { '@()' } else { "@($($items -join ', '))" }
                } else {
                    "'$($value.ToString() -replace "'", "''")'"
                }
                $PSD1Lines += "    $key = $formattedValue"
            }
            $PSD1Lines += '}'
            $PSD1Content = $PSD1Lines -join "`r`n"
            Set-Content -Path "$global:workdir\Configs\$filename" -Value $PSD1Content -ErrorAction Stop
            Update-Log -data "Configuration saved as PSD1: $filename" -Class Information
        } catch {
            Update-Log -data "Couldn't save file: $($_.Exception.Message)" -Class Error
        }
    } else {
        Update-Log -data "Saving ConfigMgr Image info for Package $filename" -Class Information

        $CurrentConfig.CMPackageID = $filename
        $CurrentConfig.CMImageType = 'Update Existing Image'

        $CurrentConfig.CMImageType

        if ((Test-Path -Path $global:workdir\ConfigMgr\PackageInfo) -eq $False) {
            Update-Log -Data 'Creating ConfigMgr Package Info folder...' -Class Information

            try {
                New-Item -ItemType Directory -Path $global:workdir\ConfigMgr\PackageInfo -ErrorAction Stop
            } catch {
                Update-Log -Data "Couldn't create the folder. Likely a permission issue" -Class Error
            }
        }
        try {
            $CurrentConfig | Export-Clixml -Path $global:workdir\ConfigMgr\PackageInfo\$filename -Force -ErrorAction Stop
            Update-Log -data 'file saved' -Class Information
        } catch {
            Update-Log -data "Couldn't save file" -Class Error
        }
    }
}
