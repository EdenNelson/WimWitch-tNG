Function Select-LanguagePacks($winver, $WinOS) {

    $LPSourceFolder = $global:workdir + '\imports\lang\' + $WinOS + '\' + $winver + '\' + 'LanguagePacks' + '\'

    $items = (Get-ChildItem -Path $LPSourceFolder | Select-Object -Property Name | Out-GridView -Title 'Select Language Packs' -PassThru)
    foreach ($item in $items) { $WPFCustomLBLangPacks.Items.Add($item.name) }
}
