Function Copy-StageIsoMedia {
    # if($WPFSourceWIMImgDesTextBox.Text -like '*Windows 10*'){$OS = 'Windows 10'}
    # if($WPFSourceWIMImgDesTextBox.Text -like '*Server*'){$OS = 'Windows Server'}

    $OS = Get-WindowsType


    #$Ver = (Get-WinVersionNumber)
    $Ver = $MISWinVer


    #create staging folder
    try {
        Update-Log -Data 'Creating staging folder for media' -Class Information
        New-Item -Path $global:workdir\staging -Name 'Media' -ItemType Directory -ErrorAction Stop | Out-Null
        Update-Log -Data 'Media staging folder has been created' -Class Information
    } catch {
        Update-Log -Data 'Could not create staging folder' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    #copy source to staging
    try {
        Update-Log -data 'Staging media binaries...' -Class Information
        Copy-Item -Path $global:workdir\imports\iso\$OS\$Ver\* -Destination $global:workdir\staging\media -Force -Recurse -ErrorAction Stop
        Update-Log -data 'Media files have been staged' -Class Information
    } catch {
        Update-Log -Data 'Failed to stage media binaries...' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

}
