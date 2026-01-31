Function Test-Name {
    Param(
        [parameter(mandatory = $false, HelpMessage = 'what to do')]
        [ValidateSet('stop', 'append', 'backup', 'overwrite')]
        $conflict = 'stop'
    )

    If ($WPFMISWimNameTextBox.Text -like '*.wim') {
        #$WPFLogging.Focus()
        #Update-Log -Data "New WIM name is valid" -Class Information
    }

    If ($WPFMISWimNameTextBox.Text -notlike '*.wim') {

        $WPFMISWimNameTextBox.Text = $WPFMISWimNameTextBox.Text + '.wim'
        Update-Log -Data 'Appending new file name with an extension' -Class Information
    }

    $WIMpath = $WPFMISWimFolderTextBox.text + '\' + $WPFMISWimNameTextBox.Text
    $FileCheck = Test-Path -Path $WIMpath


    #append,overwrite,stop

    if ($FileCheck -eq $false) { Update-Log -data 'Target WIM file name not in use. Continuing...' -class Information }
    else {
        if ($conflict -eq 'append') {
            $renamestatus = (Rename-Name -file $WIMpath -extension '.wim')
            if ($renamestatus -eq 'stop') { return 'stop' }
        }
        if ($conflict -eq 'overwrite') {
            Write-Host 'overwrite action'
            return
        }
        if ($conflict -eq 'stop') {
            $string = $WPFMISWimNameTextBox.Text + ' already exists. Rename the target WIM and try again'
            Update-Log -Data $string -Class Warning
            return 'stop'
        }
    }
    Update-Log -Data 'New WIM name is valid' -Class Information
}
