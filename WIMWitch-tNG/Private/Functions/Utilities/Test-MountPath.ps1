Function Test-MountPath {
    param(
        [parameter(mandatory = $true, HelpMessage = 'mount path')]
        $path,

        [parameter(mandatory = $false, HelpMessage = 'clear out the crapola')]
        [ValidateSet($true)]
        $clean
    )


    $IsMountPoint = $null
    $HasFiles = $null
    $currentmounts = Get-WindowsImage -Mounted

    foreach ($currentmount in $currentmounts) {
        if ($currentmount.path -eq $path) { $IsMountPoint = $true }
    }

    if ($null -eq $IsMountPoint) {
        if ( (Get-ChildItem $path | Measure-Object).Count -gt 0) {
            $HasFiles = $true
        }
    }

    if ($HasFiles -eq $true) {
        Update-Log -Data 'Folder is not empty' -Class Warning
        if ($clean -eq $true) {
            try {
                Update-Log -Data 'Cleaning folder...' -Class Warning
                Remove-Item -Path $path\* -Recurse -Force -ErrorAction Stop
                Update-Log -Data "$path cleared" -Class Warning
            }

            catch {
                Update-Log -Data "Couldn't delete contents of $path" -Class Error
                Update-Log -Data 'Select a different folder to continue.' -Class Error
                return
            }
        }
    }

    if ($IsMountPoint -eq $true) {
        Update-Log -Data "$path is currently a mount point" -Class Warning
        if (($IsMountPoint -eq $true) -and ($clean -eq $true)) {

            try {
                Update-Log -Data 'Attempting to dismount image from mount point' -Class Warning
                Dismount-WindowsImage -Path $path -Discard | Out-Null -ErrorAction Stop
                $IsMountPoint = $null
                Update-Log -Data 'Dismounting was successful' -Class Warning
            }

            catch {
                Update-Log -Data "Couldn't completely dismount the folder. Ensure" -Class Error
                Update-Log -data 'all connections to the path are closed, then try again' -Class Error
                return
            }
        }
    }
    if (($null -eq $IsMountPoint) -and ($null -eq $HasFiles)) {
        Update-Log -Data "$path is suitable for mounting" -Class Information
    }
}
