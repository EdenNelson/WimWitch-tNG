Function Install-LanguagePacks {
    Update-Log -data 'Applying Language Packs...' -Class Information

    $WinOS = Get-WindowsType
    $Winver = Get-WinVersionNumber

    if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }

    $mountdir = $WPFMISMountTextBox.text

    $LPSourceFolder = $global:workdir + '\imports\Lang\' + $WinOS + '\' + $winver + '\LanguagePacks\'
    $items = $WPFCustomLBLangPacks.items

    foreach ($item in $items) {
        $source = $LPSourceFolder + $item

        $text = 'Applying ' + $item
        Update-Log -Data $text -Class Information

        try {

            if ($demomode -eq $true) {
                $string = 'Demo mode active - not applying ' + $source
                Update-Log -data $string -Class Warning
            } else {
                Add-WindowsPackage -PackagePath $source -Path $mountdir -ErrorAction Stop | Out-Null
                Update-Log -Data 'Injection Successful' -Class Information
            }

        } catch {
            Update-Log -Data 'Failed to inject Language Pack' -Class Error
            Update-Log -data $_.Exception.Message -Class Error
        }

    }
    Update-Log -Data 'Language Pack injections complete' -Class Information
}
