Function Test-DotNetExists {

    $OSType = Get-WindowsType
    #$buildnum = Get-WinVersionNumber
    $buildnum = $WPFSourceWimTBVersionNum.text

    if ($OSType -eq 'Windows 10') {
        if ($buildnum -eq '20H2') { $Buildnum = '2009' }
        $DotNetFiles = "$global:workdir\imports\DotNet\$buildnum"
    }
    if (($OSType -eq 'Windows 11') -or ($OSType -eq 'Windows Server')) { $DotNetFiles = "$global:workdir\imports\DotNet\$OSType\$buildnum" }


    Test-Path -Path $DotNetFiles\*
    if ((Test-Path -Path $DotNetFiles\*) -eq $false) {
        $text = '.Net 3.5 Binaries are not present for ' + $buildnum
        Update-Log -Data $text -Class Warning
        Update-Log -data 'Import .Net from an ISO or disable injection to continue' -Class Warning
        return $false
    }
}
