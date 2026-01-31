Function Copy-OneDrivex64 {
    Update-Log -data 'Updating OneDrive x64/ARM64 client' -class information
    $mountpath = $WPFMISMountTextBox.text

    # Detect WIM architecture
    $wimArch = $WPFSourceWimArchTextBox.text

    # Determine which installer to use
    $installerPath = ""
    $archType = ""

    if ($wimArch -eq 'ARM64') {
        $installerPath = "$global:workdir\updates\OneDrive\arm64\OneDriveSetup.exe"
        $archType = 'ARM64'
    } else {
        $installerPath = "$global:workdir\updates\OneDrive\x64\OneDriveSetup.exe"
        $archType = 'x64'
    }

    # Check if installer exists
    if (-not (Test-Path $installerPath)) {
        Update-Log -Data "$archType OneDrive installer not found at $installerPath. Skipping update." -Class Warning
        return
    }

    # Check if target file exists in mount
    if (-not (Test-Path "$mountpath\Windows\System32\OneDriveSetup.exe")) {
        Update-Log -Data 'OneDriveSetup.exe not found in System32. Skipping update.' -Class Warning
        return
    }

    try {
        Update-Log -Data "Setting ACL on the original OneDriveSetup.exe file ($archType)" -Class Information

        $AclBAK = Get-Acl "$mountpath\Windows\System32\OneDriveSetup.exe"
        $user = $env:USERDOMAIN + '\' + $env:USERNAME
        $Account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $user
        $item = Get-Item "$mountpath\Windows\System32\OneDriveSetup.exe"

        $Acl = $null # Reset the $Acl variable to $null
        $Acl = Get-Acl -Path $Item.FullName # Get the ACL from the item
        $Acl.SetOwner($Account) # Update the in-memory ACL
        Set-Acl -Path $Item.FullName -AclObject $Acl -ErrorAction Stop  # Set the updated ACL on the target item
        Update-Log -Data 'Ownership of OneDriveSetup.exe siezed' -Class Information

        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'FullControl', 'Allow')
        $Acl.SetAccessRule($Ar)
        Set-Acl "$mountpath\Windows\System32\OneDriveSetup.exe" $Acl -ErrorAction Stop | Out-Null

        Update-Log -Data 'ACL successfully updated. Continuing...'
    } catch {
        Update-Log -data "Couldn't set the ACL on the original file" -Class Error
        return
    }

    try {
        Update-Log -data "Copying updated OneDrive $archType agent installer..." -Class Information
        Copy-Item $installerPath -Destination "$mountpath\Windows\System32" -Force -ErrorAction Stop
        Update-Log -Data "OneDrive $archType installer successfully copied." -Class Information
    } catch {
        Update-Log -data "Couldn't copy the OneDrive installer file." -class Error
        Update-Log -data $_.Exception.Message -Class Error
        return
    }

    try {
        Update-Log -data 'Restoring original ACL to OneDrive installer.' -Class Information
        Set-Acl "$mountpath\Windows\System32\OneDriveSetup.exe" $AclBAK -ErrorAction Stop | Out-Null
        Update-Log -data 'Restoration complete' -Class Information
    } catch {
        Update-Log "Couldn't restore original ACLs. Continuing." -Class Error
    }
}
