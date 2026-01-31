Function Get-WindowsPatches($build, $OS) {
    Update-Log -Data "Downloading SSU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'SSU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\SSU
    } catch {
        Update-Log -data 'Failed to download SSU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading AdobeSU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'AdobeSU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\AdobeSU
    } catch {
        Update-Log -data 'Failed to download AdobeSU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading LCU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'LCU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\LCU
    } catch {
        Update-Log -data 'Failed to download LCU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }
    Update-Log -Data "Downloading .Net updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'DotNet' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\DotNet
    } catch {
        Update-Log -data 'Failed to download .Net update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    Update-Log -Data "Downloading .Net CU updates for $OS $build" -Class Information
    try {
        Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'DotNetCU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\DotNetCU
    } catch {
        Update-Log -data 'Failed to download .Net CU update' -Class Error
        Update-Log -data $_.Exception.Message -class Error
    }

    if ($WPFUpdatesCBEnableOptional.IsChecked -eq $True) {
        try {
            Update-Log -Data "Downloading optional updates for $OS $build" -Class Information
            Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'Optional' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\Optional
        } catch {
            Update-Log -data 'Failed to download optional update' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }
    }

    if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) {
        try {
            Update-Log -Data "Downloading dynamic updates for $OS $build" -Class Information
            Get-OSDUpdate -ErrorAction Stop | Where-Object { $_.UpdateOS -eq $OS -and $_.UpdateArch -eq 'x64' -and $_.UpdateBuild -eq $build -and $_.UpdateGroup -eq 'SetupDU' } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\Dynamic
        } catch {
            Update-Log -data 'Failed to download dynamic update' -Class Error
            Update-Log -data $_.Exception.Message -class Error
        }
    }


    Update-Log -Data "Downloading completed for $OS $build" -Class Information


}
