Function Install-StartLayout {
    try {
        $startpath = $WPFMISMountTextBox.Text + '\users\default\appdata\local\microsoft\windows\shell'
        Update-Log -Data 'Copying the start menu file...' -Class Information
        Copy-Item $WPFCustomTBStartMenu.Text -Destination $startpath -ErrorAction Stop
        $filename = (Split-Path -Path $WPFCustomTBStartMenu.Text -Leaf)

        $OS = $Windowstype

        if ($os -eq 'Windows 11') {
            if ($filename -ne 'LayoutModification.json') {
                $newpath = $startpath + '\' + $filename
                Update-Log -Data 'Renaming json file...' -Class Warning
                Rename-Item -Path $newpath -NewName 'LayoutModification.json'
                Update-Log -Data 'file renamed to LayoutModification.json' -Class Information
            }
        }

        if ($os -ne 'Windows 11') {
            if ($filename -ne 'LayoutModification.xml') {
                $newpath = $startpath + '\' + $filename
                Update-Log -Data 'Renaming xml file...' -Class Warning
                Rename-Item -Path $newpath -NewName 'LayoutModification.xml'
                Update-Log -Data 'file renamed to LayoutModification.xml' -Class Information
            }
        }



    } catch {
        Update-Log -Data "Couldn't apply the start menu XML" -Class Error
        Update-Log -data $_.Exception.Message -Class Error
    }
}
