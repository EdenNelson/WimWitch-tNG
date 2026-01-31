Function Set-Logging {
    #logging folder
    if (!(Test-Path -Path "$global:workdir\logging\WIMWitch.Log" -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path "$global:workdir\Logging" | Out-Null
        New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
    } Else {
        Remove-Item -Path "$global:workdir\logging\WIMWitch-tNG.log"
        New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
    }


    #updates folder
    $FileExist = Test-Path -Path "$global:workdir\updates" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Updates folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\updates" | Out-Null
        Update-Log -Data 'Updates folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Updates folder exists' -Class Information }

    #staging folder
    $FileExist = Test-Path -Path "$global:workdir\Staging" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Staging folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Staging" | Out-Null
        Update-Log -Data 'Staging folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Staging folder exists' -Class Information }

    #Mount folder
    $FileExist = Test-Path -Path "$global:workdir\Mount" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Mount folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Mount" | Out-Null
        Update-Log -Data 'Mount folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Mount folder exists' -Class Information }

    #Completed WIMs folder
    $FileExist = Test-Path -Path "$global:workdir\CompletedWIMs" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'CompletedWIMs folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\CompletedWIMs" | Out-Null
        Update-Log -Data 'CompletedWIMs folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'CompletedWIMs folder exists' -Class Information }

    #Configurations XML folder
    $FileExist = Test-Path -Path "$global:workdir\Configs" #-PathType Leaf
    if ($FileExist -eq $False) {
        Update-Log -Data 'Configs folder does not exist. Creating...' -Class Warning
        New-Item -ItemType Directory -Force -Path "$global:workdir\Configs" | Out-Null
        Update-Log -Data 'Configs folder created' -Class Information
    }

    if ($FileExist -eq $True) { Update-Log -Data 'Configs folder exists' -Class Information }

}
