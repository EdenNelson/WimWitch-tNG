Function Invoke-ArchitectureCheck {
    if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem) {

        Update-Log -Data 'This is 32-bit PowerShell session. Will relaunch as 64-bit...' -Class Warning

        #The following If statment was pilfered from Michael Niehaus
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {

            if (($auto -eq $false) -and ($CM -eq 'None')) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" }
            if (($auto -eq $true) -and ($null -ne $autofile)) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -auto -autofile $autofile }
            if (($CM -eq 'Edit') -and ($null -ne $autofile)) { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -CM Edit -autofile $autofile }
            if ($CM -eq 'New') { & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -CM New }

            Exit $lastexitcode
        }
    } else {
        Update-Log -Data 'This is a 64 bit PowerShell session' -Class Information


    }
}
