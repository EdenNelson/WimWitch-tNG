Function Select-LocalExperiencePack($winver, $WinOS) {

    $LPSourceFolder = $global:workdir + '\imports\lang\' + $WinOS + '\' + $winver + '\' + 'localexperiencepack' + '\'


    $items = (Get-ChildItem -Path $LPSourceFolder | Select-Object -Property Name | Out-GridView -Title 'Select Local Experience Packs' -PassThru)
    foreach ($item in $items) { $WPFCustomLBLEP.Items.Add($item.name) }
}
