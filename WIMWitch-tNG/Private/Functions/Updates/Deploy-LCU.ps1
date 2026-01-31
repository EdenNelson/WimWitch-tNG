Function Deploy-LCU($packagepath) {

    $osver = Get-WindowsType

    if ($osver -eq 'Windows 10') {
        $executable = "$env:windir\system32\expand.exe"
        $filename = (Get-ChildItem $packagepath).name
        Update-Log -Data 'Extracting LCU Package content to staging folder...' -Class Information
        Start-Process $executable -args @("`"$packagepath\$filename`"", '/f:*.CAB', "`"$global:workdir\staging`"") -Wait -ErrorAction Stop
        $cabs = (Get-Item $global:workdir\staging\*.cab)

        #MMSMOA2022
        Update-Log -data 'Applying SSU...' -class information
        foreach ($cab in $cabs) {

            if ($cab -like '*SSU*') {
                Update-Log -data $cab -class Information

                if ($demomode -eq $false) { Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $cab -ErrorAction stop | Out-Null }
                else {
                    $string = 'Demo mode active - Not applying ' + $cab
                    Update-Log -data $string -Class Warning
                }
            }

        }

        Update-Log -data 'Applying LCU...' -class information
        foreach ($cab in $cabs) {
            if ($cab -notlike '*SSU*') {
                Update-Log -data $cab -class information
                if ($demomode -eq $false) { Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $cab -ErrorAction stop | Out-Null }
                else {
                    $string = 'Demo mode active - Not applying ' + $cab
                    Update-Log -data $string -Class Warning
                }
            }
        }
    }
    if ($osver -eq 'Windows 11') {
        # Copy files to staging and apply
        Update-Log -data 'Copying LCU file(s) to staging folder...' -class information
        $filenames = @(Get-ChildItem -Path $packagepath -Name)

        foreach ($filename in $filenames) {
            Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force
            $stagingPath = Join-Path -Path $global:workdir -ChildPath "staging\$filename"
            $fileExtension = [System.IO.Path]::GetExtension($filename)
            $servicingPath = $stagingPath
            $msuRenamed = $false

            # Default first pass: rename CAB files to MSU (original behavior, works 99% of time)
            if ($fileExtension -eq '.cab') {
                $basename = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $newname = "$basename.msu"
                $servicingPath = Join-Path -Path $global:workdir -ChildPath "staging\$newname"
                Rename-Item -Path $stagingPath -NewName $newname
                $msuRenamed = $true
                Update-Log -data "Renamed CAB to MSU: $newname" -class information
            }

            $updatename = (Get-Item -Path $packagepath\$filename).name
            Update-Log -data 'Applying LCU...' -class information
            Update-Log -data $servicingPath -class information
            Update-Log -data $updatename -Class Information

            try {
                if ($demomode -eq $false) {
                    Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $servicingPath -ErrorAction Stop | Out-Null
                } else {
                    $string = 'Demo mode active - Not applying ' + $updatename
                    Update-Log -data $string -Class Warning
                }
            } catch {
                # Fallback: if CAB file failed after rename to MSU, try applying as original CAB
                if ($msuRenamed -eq $true) {
                    Update-Log -data "MSU format failed, attempting fallback with original CAB format: $filename" -class Warning

                    try {
                        # Rename back to CAB
                        Rename-Item -Path $servicingPath -NewName $filename -ErrorAction Stop
                        Update-Log -data "Renamed back to CAB format: $filename" -class information

                        if ($demomode -eq $false) {
                            Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $stagingPath -ErrorAction Stop | Out-Null
                            Update-Log -data "Successfully applied CAB after format fallback" -class information
                        } else {
                            Update-Log -data "Demo mode active - Not applying $updatename" -Class Warning
                        }
                    }
                    catch {
                        Update-Log -data 'Failed to apply update (both MSU and CAB formats attempted)' -class Warning
                        Update-Log -data $_.Exception.Message -class Warning
                    }
                }
                else {
                    # Not a CAB file, can't fallback
                    Update-Log -data 'Failed to apply update' -class Warning
                    Update-Log -data $_.Exception.Message -class Warning
                }
            }
        }
    }

}
