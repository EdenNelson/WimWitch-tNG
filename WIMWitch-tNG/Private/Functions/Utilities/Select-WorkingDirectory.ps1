Function Select-WorkingDirectory {
    $selectWorkingDirectory = New-Object System.Windows.Forms.FolderBrowserDialog
    $selectWorkingDirectory.Description = 'Select the working directory.'
    $null = $selectWorkingDirectory.ShowDialog()

    if ($selectWorkingDirectory.SelectedPath -eq '') {
        Write-Output 'User Cancelled or invalid entry'
        exit 0
    }

    return $selectWorkingDirectory.SelectedPath
}
