Function Invoke-MISUpdates {

    $OS = get-Windowstype
    $ver = Get-WinVersionNumber

    if ($ver -eq '2009') { $ver = '20H2' }

    Invoke-MEMCMUpdateSupersedence -prod $OS -Ver $ver
    Invoke-MEMCMUpdatecatalog -prod $OS -ver $ver

    #fucking 2009 to 20h2

}
