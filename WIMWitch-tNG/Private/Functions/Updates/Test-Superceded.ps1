Function Test-Superceded($action, $OS, $Build) {
    Update-Log -Data 'Checking WIM Witch Update store for superseded updates' -Class Information
    $path = $global:workdir + '\updates\' + $OS + '\' + $Build + '\' #sets base path

    if ((Test-Path -Path $path) -eq $false) {
        Update-Log -Data 'No updates found, likely not yet downloaded. Skipping supersedense check...' -Class Warning
        return
    }

    $Children = Get-ChildItem -Path $path  #query sub directories

    foreach ($Children in $Children) {
        $path1 = $path + $Children
        $sprout = Get-ChildItem -Path $path1


        foreach ($sprout in $sprout) {
            $path3 = $path1 + '\' + $sprout
            $fileinfo = Get-ChildItem -Path $path3
            foreach ($file in $fileinfo) {
                $StillCurrent = Get-OSDUpdate | Where-Object { $_.FileName -eq $file }
                If ($null -eq $StillCurrent) {
                    Update-Log -data "$file no longer current" -Class Warning
                    if ($action -eq 'delete') {
                        Update-Log -data "Deleting $path3" -class Warning
                        Remove-Item -Path $path3 -Recurse -Force
                    }
                    if ($action -eq 'audit') {
                        $WPFUpdatesOSDListBox.items.add('Superceded updates discovered. Please select the versions of Windows 10 you are supporting and click Update')
                        Return
                    }
                } else {
                    Update-Log -data "$file is still current" -Class Information
                }
            }
        }
    }
    Update-Log -data 'Supercedense check complete.' -Class Information
}
