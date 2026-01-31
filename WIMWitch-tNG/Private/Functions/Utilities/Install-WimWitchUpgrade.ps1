Function Install-WimWitchUpgrade {
    Write-Output 'Would you like to upgrade WIM Witch?'
    $yesno = Read-Host -Prompt '(Y/N)'
    Write-Output $yesno
    if (($yesno -ne 'Y') -and ($yesno -ne 'N')) {
        Write-Output 'Invalid entry, try again.'
        Install-WimWitchUpgrade
    }

    if ($yesno -eq 'y') {
        Backup-WIMWitch

        try {
            Save-Script -Name 'WIMWitch' -Path $global:workdir -Force -ErrorAction Stop
            Write-Output 'New version has been applied. WIM Witch will now exit.'
            Write-Output 'Please restart WIM Witch'
            exit
        } catch {
            Write-Output "Couldn't upgrade. Try again when teh tubes are clear"
            return
        }

    }


    if ($yesno -eq 'n') {
        Write-Output "You'll want to upgrade at some point."
        Update-Log -Data 'Upgrade to new version was declined' -Class Warning
        Update-Log -Data 'Continuing to start WIM Witch...' -Class Warning
    }

}
