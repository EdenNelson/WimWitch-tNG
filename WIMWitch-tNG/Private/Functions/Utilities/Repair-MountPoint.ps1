Function Repair-MountPoint {
    param(
        [bool]$AutoFix = $false
    )

    $MountPath = Join-Path -Path $global:workdir -ChildPath 'Mount'

    Update-Log -Data "Checking mount point: $MountPath" -Class Information

    # Check if mount path exists
    if (-not (Test-Path $MountPath)) {
        Update-Log -Data "Mount path does not exist. Creating directory." -Class Information
        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
        return
    }

    # Check if anything is mounted
    $MountedImages = Get-WindowsImage -Mounted 2>$null | Where-Object { $_.ImagePath -like "*$MountPath*" }

    if ($MountedImages) {
        Update-Log -Data "Found mounted images at $MountPath" -Class Warning

        if ($AutoFix) {
            Update-Log -Data "AutoFix enabled - dismounting images..." -Class Information
            foreach ($image in $MountedImages) {
                try {
                    Dismount-WindowsImage -Path $image.Path -Discard | Out-Null
                    Update-Log -Data "Dismounted: $($image.Path)" -Class Information
                } catch {
                    Update-Log -Data "Failed to dismount $($image.Path): $($_.Exception.Message)" -Class Error
                }
            }
        } else {
            Write-Host "Mounted images found in $MountPath" -ForegroundColor Yellow
            Write-Host "Options:"
            Write-Host "  1) Dismount all images"
            Write-Host "  2) Purge mount directory (force)"
            Write-Host "  3) Continue anyway"

            $choice = Read-Host "Select option (1-3)"

            switch ($choice) {
                '1' {
                    foreach ($image in $MountedImages) {
                        try {
                            Dismount-WindowsImage -Path $image.Path -Discard | Out-Null
                            Update-Log -Data "Dismounted: $($image.Path)" -Class Information
                        } catch {
                            Update-Log -Data "Failed to dismount: $($_.Exception.Message)" -Class Error
                        }
                    }
                }
                '2' {
                    try {
                        Remove-Item -Path $MountPath -Recurse -Force
                        New-Item -ItemType Directory -Path $MountPath -Force | Out-Null
                        Update-Log -Data "Mount directory purged and recreated" -Class Information
                    } catch {
                        Update-Log -Data "Failed to purge mount directory: $($_.Exception.Message)" -Class Error
                    }
                }
                '3' {
                    Update-Log -Data "User chose to continue with mounted images" -Class Warning
                }
            }
        }
    }

    # Check for orphaned content
    $MountContent = Get-ChildItem -Path $MountPath -ErrorAction SilentlyContinue | Measure-Object

    if ($MountContent.Count -gt 0) {
        Update-Log -Data "Mount directory contains $($MountContent.Count) items" -Class Warning

        if ($AutoFix) {
            Update-Log -Data "AutoFix enabled - purging mount directory..." -Class Information
            try {
                Remove-Item -Path $MountPath\* -Recurse -Force -ErrorAction Stop
                Update-Log -Data "Mount directory purged" -Class Information
            } catch {
                Update-Log -Data "Failed to purge mount directory: $($_.Exception.Message)" -Class Error
            }
        } else {
            Write-Host "Mount directory contains orphaned content" -ForegroundColor Yellow
            $purge = Read-Host "Purge mount directory? (Y/N)"

            if ($purge -eq 'Y' -or $purge -eq 'y') {
                try {
                    Remove-Item -Path $MountPath\* -Recurse -Force -ErrorAction Stop
                    Update-Log -Data "Mount directory purged" -Class Information
                } catch {
                    Update-Log -Data "Failed to purge: $($_.Exception.Message)" -Class Error
                }
            }
        }
    }

    Update-Log -Data "Mount point check complete" -Class Information
}
