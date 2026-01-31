Function Import-FeatureOnDemand($Winver, $LPSourceFolder, $WinOS) {

    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    $path = $WPFImportOtherTBPath.text
    $text = 'Starting importation of Feature On Demand binaries from ' + $path
    Update-Log -Data $text -Class Information

    $langpacks = Get-ChildItem -Path $LPSourceFolder

    if ((Test-Path -Path $global:workdir\imports\FODs\$WinOS\$Winver) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\FODs\' + $WinOS + '\' + $winver
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\fods\$WinOS -Name $winver -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }
    #If Windows 11

    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 11') {
        $items = $WPFImportOtherLBList.items
        foreach ($item in $items) {
            $source = $LPSourceFolder + $item
            $text = 'Importing ' + $item
            Update-Log -Data $text -Class Information
            Copy-Item $source -Destination $global:workdir\imports\FODs\$WinOS\$Winver\ -Force
        }

    }


    #If not Windows 11
    if ($WPFImportOtherCBWinOS.SelectedItem -ne 'Windows 11') {
        foreach ($langpack in $langpacks) {
            $source = $LPSourceFolder + $langpack.name

            Copy-Item $source -Destination $global:workdir\imports\FODs\$WinOS\$Winver\ -Force
            $name = $langpack.name
            $text = 'Copying ' + $name
            Update-Log -Data $text -Class Information

        }
    }

    Update-Log -Data 'Importing metadata subfolder...' -Class Information
    Get-ChildItem -Path ($LPSourceFolder + '\metadata\') | Copy-Item -Destination $global:workdir\imports\FODs\$WinOS\$Winver\metadata -Force
    Update-Log -data 'Feature On Demand imporation complete.'
}
