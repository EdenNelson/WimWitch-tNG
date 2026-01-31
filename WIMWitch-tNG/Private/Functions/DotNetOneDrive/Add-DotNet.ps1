Function Add-DotNet {

    $buildnum = Get-WinVersionNumber
    $OSType = Get-WindowsType

    #fix the build number 21h

    if ($OSType -eq 'Windows 10') { $DotNetFiles = "$global:workdir\imports\DotNet\$buildnum" }
    if (($OSType -eq 'Windows 11') -or ($OSType -eq 'Windows Server')) { $DotNetFiles = "$global:workdir\imports\DotNet\$OSType\$buildnum" }


    try {
        $text = 'Injecting .Net 3.5 binaries from ' + $DotNetFiles
        Update-Log -Data $text -Class Information
        Add-WindowsPackage -PackagePath $DotNetFiles -Path $WPFMISMountTextBox.Text -ErrorAction Continue | Out-Null
    } catch {
        Update-Log -Data "Couldn't inject .Net Binaries" -Class Warning
        Update-Log -data $_.Exception.Message -Class Error
        return
    }
    Update-Log -Data '.Net 3.5 injection complete' -Class Information
}
