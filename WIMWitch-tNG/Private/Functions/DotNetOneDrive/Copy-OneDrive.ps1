Function Copy-OneDrive {
    Update-Log -data 'Updating OneDrive x86 client' -class information
    $mountpath = $WPFMISMountTextBox.text

    # Check if SysWOW64 exists (only present on x64 systems, not on Windows 11 or ARM64)
    if (-not (Test-Path "$mountpath\Windows\SysWOW64\OneDriveSetup.exe")) {
        Update-Log -Data 'Skipping x86 OneDrive—SysWOW64 not present (likely Windows 11 or ARM64 system)' -Class Information
        return
    }

    # Check if x86 installer was downloaded
    if (-not (Test-Path "$global:workdir\updates\OneDrive\x86\OneDriveSetup.exe")) {
        Update-Log -Data 'x86 OneDrive installer not found in updates folder. Skipping x86 update.' -Class Warning
        return
    }

    try {
        Update-Log -Data 'Setting ACL on the original OneDriveSetup.exe file' -Class Information

        $AclBAK = Get-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe"
        $user = $env:USERDOMAIN + '\' + $env:USERNAME
        $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $user
        $item = Get-Item "$mountpath\Windows\SysWOW64\OneDriveSetup.exe"

        $Acl = $null # Reset the $Acl variable to $null
        $Acl = Get-Acl -Path $Item.FullName # Get the ACL from the item
        $Acl.SetOwner($Account) # Update the in-memory ACL
        Set-Acl -Path $Item.FullName -AclObject $Acl -ErrorAction Stop  # Set the updated ACL on the target item
        Update-Log -Data 'Ownership of OneDriveSetup.exe siezed' -Class Information

        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'FullControl', 'Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe" $Acl -ErrorAction Stop | Out-Null

        Update-Log -Data 'ACL successfully updated. Continuing...'
    } catch {
        Update-Log -data "Couldn't set the ACL on the original file" -Class Error
        return
    }

    try {
        Update-Log -data 'Copying updated OneDrive agent installer...' -Class Information
        Copy-Item "$global:workdir\updates\OneDrive\x86\OneDriveSetup.exe" -Destination "$mountpath\Windows\SysWOW64" -Force -ErrorAction Stop
        Update-Log -Data 'OneDrive x86 installer successfully copied.' -Class Information
    } catch {
        Update-Log -data "Couldn't copy the OneDrive installer file." -class Error
        Update-Log -data $_.Exception.Message -Class Error
        return
    }

    try {
        Update-Log -data 'Restoring original ACL to OneDrive installer.' -Class Information
        Set-Acl "$mountpath\Windows\SysWOW64\OneDriveSetup.exe" $AclBAK -ErrorAction Stop | Out-Null
        Update-Log -data 'Restoration complete' -Class Information
    } catch {
        Update-Log "Couldn't restore original ACLs. Continuing." -Class Error
    }
}
