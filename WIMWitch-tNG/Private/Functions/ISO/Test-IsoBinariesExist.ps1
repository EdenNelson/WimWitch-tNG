Function Test-IsoBinariesExist {
    $buildnum = Get-WinVersionNumber
    $OSType = get-Windowstype


    $ISOFiles = $global:workdir + '\imports\iso\' + $OSType + '\' + $buildnum + '\'

    Test-Path -Path $ISOFiles\*
    if ((Test-Path -Path $ISOFiles\*) -eq $false) {
        $text = 'ISO Binaries are not present for ' + $OSType + ' ' + $buildnum
        Update-Log -Data $text -Class Warning
        Update-Log -data 'Import ISO Binaries from an ISO or disable ISO/Upgrade Package creation' -Class Warning
        return $false
    }

    Update-Log -Data 'Installing ConfigMgr console extension...' -Class Information

    $ConsoleFolderImage = '828a154e-4c7d-4d7f-ba6c-268443cdb4e8' #folder for update and edit

    $ConsoleFolderRoot = 'ac16f420-2d72-4056-a8f6-aef90e66a10c' #folder for new

    $path = ($env:SMS_ADMIN_UI_PATH -replace 'bin\\i386', '') + 'XmlStorage\Extensions\Actions'

    Update-Log -Data 'Creating folders if needed...' -Class Information

    if ((Test-Path -Path (Join-Path -Path $path -ChildPath $ConsoleFolderImage)) -eq $false) { New-Item -Path $path -Name $ConsoleFolderImage -ItemType 'directory' | Out-Null }

    Update-Log -data 'Creating extension files...' -Class Information

    $UpdateWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderImage) + '\UpdateWWImage.xml') -Force
    $EditWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderImage) + '\EditWWImage.xml') -Force

    Update-Log -Data 'Creating folders if needed...' -Class Information

    if ((Test-Path -Path (Join-Path -Path $path -ChildPath $ConsoleFolderRoot)) -eq $false) { New-Item -Path $path -Name $ConsoleFolderRoot -ItemType 'directory' | Out-Null }
    Update-Log -data 'Creating extension files...' -Class Information

    $NewWWXML | Out-File ((Join-Path -Path $path -ChildPath $ConsoleFolderRoot) + '\NewWWImage.xml') -Force

    Update-Log -Data 'Console extension installation complete!' -Class Information
}
