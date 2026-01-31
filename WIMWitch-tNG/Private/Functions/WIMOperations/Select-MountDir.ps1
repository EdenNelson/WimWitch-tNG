Function Select-MountDir {
    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = 'Select the mount folder'
    $null = $browser.ShowDialog()
    $MountDir = $browser.SelectedPath

    if ($SourceWIM.FileName -notlike '*.wim') {
        Update-Log -Data 'A WIM file not selected. Please select a valid file to continue.' -Class Warning
        return
    }

    #Select the index
    $ImageFull = @(Get-WindowsImage -ImagePath $WPFSourceWIMSelectWIMTextBox.text)
    $a = $ImageFull | Out-GridView -Title 'Choose an Image Index' -PassThru
    $IndexNumber = $a.ImageIndex
    if ($null -eq $indexnumber) {
        Update-Log -Data 'Index not selected. Reselect the WIM file to select an index' -Class Warning
        return
    }

    Import-WimInfo -IndexNumber $IndexNumber
}
