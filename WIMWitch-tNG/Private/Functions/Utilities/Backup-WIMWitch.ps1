Function Backup-WIMWitch {
    Update-log -data 'Backing up existing WIM Witch script...' -Class Information

    $scriptname = Split-Path $MyInvocation.PSCommandPath -Leaf #Find local script name
    Update-Log -data 'The script to be backed up is: ' -Class Information
    Update-Log -data $MyInvocation.PSCommandPath -Class Information

    try {
        Update-Log -data 'Copy script to backup folder...' -Class Information
        Copy-Item -Path $scriptname -Destination $global:workdir\backup -ErrorAction Stop
        Update-Log -Data 'Successfully copied...' -Class Information
    } catch {
        Update-Log -data "Couldn't copy the WIM Witch script. My guess is a permissions issue" -Class Error
        Update-Log -Data 'Exiting out of an over abundance of caution' -Class Error
        exit
    }

    try {
        Update-Log -data 'Renaming archived script...' -Class Information
        Rename-Name -file $global:workdir\backup\$scriptname -extension '.ps1'
        Update-Log -data 'Backup successfully renamed for archiving' -class Information
    } catch {

        Update-Log -Data "Backed-up script couldn't be renamed. This isn't a critical error" -Class Warning
        Update-Log -Data "You may want to change it's name so it doesn't get overwritten." -Class Warning
        Update-Log -Data 'Continuing with WIM Witch upgrade...' -Class Warning
    }
}
