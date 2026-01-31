Function Select-Appx {

    $AssetsPath = Join-Path -Path $PSScriptRoot -ChildPath 'Assets'

    $OS = Get-WindowsType
    $buildnum = $WPFSourceWimTBVersionNum.text

    if ($OS -eq 'Windows 10') {
        $OS = 'Win10'
    }
    if ($OS -eq 'Windows 11') {
        $OS = 'Win11'
    }

    $appxListFile = Join-Path -Path $AssetsPath -ChildPath $("appx$OS" + '_' + "$buildnum.psd1")
    Update-Log -Data "Looking for Appx list file $appxListFile" -Class Information

    if (Test-Path $appxListFile) {
        $appxData = Import-PowerShellDataFile $appxListFile
        $appxPackages = $appxData.Packages
        $exappxs = $appxPackages | Out-GridView -Title 'Select apps to remove' -PassThru
    } else {
        Write-Warning "No matching Appx list file found for build $buildnum."
        return
    }

    if ($null -eq $exappxs) {
        Update-Log -Data 'No apps were selected' -Class Warning
    } elseif ($null -ne $exappxs) {
        Update-Log -data 'The following apps were selected for removal:' -Class Information
        Foreach ($exappx in $exappxs) {
            Update-Log -Data $exappx -Class Information
        }

        $WPFAppxTextBox.Text = $exappxs -join "`r`n"
        return $exappxs
    }
}
