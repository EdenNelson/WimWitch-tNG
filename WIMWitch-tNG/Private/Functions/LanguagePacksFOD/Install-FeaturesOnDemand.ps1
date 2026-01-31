Function Install-FeaturesOnDemand {
    Update-Log -data 'Applying Features On Demand...' -Class Information

    $mountdir = $WPFMISMountTextBox.text

    $WinOS = Get-WindowsType
    $Winver = Get-WinVersionNumber

    if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }


    $FODsource = $global:workdir + '\imports\FODs\' + $winOS + '\' + $Winver + '\'
    $items = $WPFCustomLBFOD.items

    foreach ($item in $items) {
        $text = 'Applying ' + $item
        Update-Log -Data $text -Class Information

        try {
            Add-WindowsCapability -Path $mountdir -Name $item -Source $FODsource -ErrorAction Stop | Out-Null
            Update-Log -Data 'Injection Successful' -Class Information
        } catch {
            Update-Log -data 'Failed to apply Feature On Demand' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }


    }
    Update-Log -Data 'Feature on Demand injections complete' -Class Information
}
