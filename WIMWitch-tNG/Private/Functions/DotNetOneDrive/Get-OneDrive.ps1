Function Get-OneDrive {
    #https://go.microsoft.com/fwlink/p/?LinkID=844652 -Possible new link location.
    #https://go.microsoft.com/fwlink/?linkid=2181064 - x64 installer
    #https://go.microsoft.com/fwlink/?linkid=2282608 - ARM64 installer

    # Detect Windows version and architecture being serviced
    $os = Get-WindowsType
    $arch = $WPFSourceWimArchTextBox.text

    # Windows 10 x64: Download x86 + x64
    # Windows 11 x64: Download x64 only
    # Windows 11 ARM64: Download ARM64 only

    if ($os -eq 'Windows 10') {
        Update-Log -Data 'Downloading latest 32-bit OneDrive agent installer for Windows 10...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/p/?LinkId=248256'
        $DownloadPath = "$global:workdir\updates\OneDrive\x86"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive x86 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive x86 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping x86 OneDrive download for Windows 11' -Class Information
    }

    # Only download x64 for Windows 10 or Windows 11 x64 (skip for ARM64)
    if (($os -eq 'Windows 10') -or (($os -eq 'Windows 11') -and ($arch -eq 'x64'))) {
        Update-Log -Data 'Downloading latest 64-bit OneDrive agent installer...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/?linkid=2181064'
        $DownloadPath = "$global:workdir\updates\OneDrive\x64"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive x64 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive x64 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping x64 OneDrive download for Windows 11 ARM64' -Class Information
    }

    if (($os -eq 'Windows 11') -and ($arch -eq 'ARM64')) {
        Update-Log -Data 'Downloading latest ARM64 OneDrive agent installer for Windows 11...' -class Information
        $DownloadUrl = 'https://go.microsoft.com/fwlink/?linkid=2282608'
        $DownloadPath = "$global:workdir\updates\OneDrive\arm64"
        $DownloadFile = 'OneDriveSetup.exe'

        if (!(Test-Path "$DownloadPath")) { New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null }
        Invoke-WebRequest -Uri $DownloadUrl -OutFile "$DownloadPath\$DownloadFile"
        if (Test-Path "$DownloadPath\$DownloadFile") {
            Update-Log -Data 'OneDrive ARM64 Download Complete' -Class Information
        } else {
            Update-log -Data 'OneDrive ARM64 could not be downloaded' -Class Error
        }
    } else {
        Update-Log -Data 'Skipping ARM64 OneDrive download (not Windows 11 ARM64)' -Class Information
    }

}
