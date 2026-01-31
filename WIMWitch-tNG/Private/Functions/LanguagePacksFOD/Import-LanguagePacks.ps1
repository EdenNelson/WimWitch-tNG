Function Import-LanguagePacks($Winver, $LPSourceFolder, $WinOS) {
    Update-Log -Data 'Importing Language Packs...' -Class Information

    #Note To Donna - Make a step that checks if $winver -eq 1903, and if so, set $winver to 1909
    if ($winver -eq '1903') {
        Update-Log -Data 'Changing version variable because 1903 and 1909 use the same packages' -Class Information
        $winver = '1909'
    }

    if ((Test-Path -Path $global:workdir\imports\Lang\$WinOS\$winver\LanguagePacks) -eq $False) {
        Update-Log -Data 'Destination folder does not exist. Creating...' -Class Warning
        $path = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\LanguagePacks'
        $text = 'Creating folder ' + $path
        Update-Log -data $text -Class Information
        New-Item -Path $global:workdir\imports\Lang\$WinOS\$winver -Name LanguagePacks -ItemType Directory
        Update-Log -Data 'Folder created successfully' -Class Information
    }

    $items = $WPFImportOtherLBList.items
    foreach ($item in $items) {
        $source = $LPSourceFolder + $item
        $text = 'Importing ' + $item
        Update-Log -Data $text -Class Information
        Copy-Item $source -Destination $global:workdir\imports\Lang\$WinOS\$Winver\LanguagePacks -Force
    }
    Update-Log -Data 'Importation Complete' -Class Information
}
