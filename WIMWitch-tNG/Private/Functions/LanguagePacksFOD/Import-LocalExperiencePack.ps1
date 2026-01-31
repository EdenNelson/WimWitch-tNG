Function Import-LocalExperiencePack($Winver, $LPSourceFolder, $WinOS) {

    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    Update-Log -Data 'Importing Local Experience Packs...' -Class Information

    if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$winver\localexperiencepack) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\localexperiencepack'
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\Lang\$WinOS\$winver -Name localexperiencepack -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }

    $items = $WPFImportOtherLBList.items
    foreach ($item in $items) {
        $name = $item
        $source = $LPSourceFolder + $name
        $text = 'Creating destination folder for ' + $item
        Update-Log -Data $text -Class Information

        if ((Test-Path -Path $global:workdir\imports\lang\$WinOS\$winver\localexperiencepack\$name) -eq $False) { New-Item -Path $global:workdir\imports\lang\$WinOS\$winver\localexperiencepack -Name $name -ItemType Directory }
        else {
            $text = 'The folder for ' + $item + ' already exists. Skipping creation...'
            Update-Log -Data $text -Class Warning
        }

        Update-Log -Data 'Copying source to destination folders...' -Class Information
        Get-ChildItem -Path $source | Copy-Item -Destination $global:workdir\imports\Lang\$WinOS\$Winver\LocalExperiencePack\$name -Force
    }
    Update-log -Data 'Importation complete' -Class Information
}
