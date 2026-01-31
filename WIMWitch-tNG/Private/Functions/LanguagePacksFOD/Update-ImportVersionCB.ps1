Function Update-ImportVersionCB {
    $WPFImportOtherCBWinVer.Items.Clear()
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows Server') { Foreach ($WinSrvVer in $WinSrvVer) { $WPFImportOtherCBWinVer.Items.Add($WinSrvVer) } }
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 10') { Foreach ($Win10Ver in $Win10ver) { $WPFImportOtherCBWinVer.Items.Add($Win10Ver) } }
    if ($WPFImportOtherCBWinOS.SelectedItem -eq 'Windows 11') { Foreach ($Win11Ver in $Win11ver) { $WPFImportOtherCBWinVer.Items.Add($Win11Ver) } }
}
