Function Import-CMModule() {
    try {
        $path = (($env:SMS_ADMIN_UI_PATH -replace 'i386', '') + 'ConfigurationManager.psd1')

        #           $path = "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1"
        Import-Module $path -ErrorAction Stop
        Update-Log -Data 'ConfigMgr PowerShell module imported' -Class Information
        return 0
    }

    catch {
        Update-Log -Data 'Could not import CM PowerShell module.' -Class Warning
        return 1
    }
}
