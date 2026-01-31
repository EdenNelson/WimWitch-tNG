Function Remove-OSIndex {
    Update-Log -Data 'Attempting to remove unwanted image indexes' -Class Information
    $wimname = Get-Item -Path $global:workdir\Staging\*.wim

    Update-Log -Data "Found Image $wimname" -Class Information
    $IndexesAll = Get-WindowsImage -ImagePath $wimname | ForEach-Object { $_.ImageName }
    $IndexSelected = $WPFSourceWIMImgDesTextBox.Text
    foreach ($Index in $IndexesAll) {
        Update-Log -data "$Index is being evaluated"
        If ($Index -eq $IndexSelected) {
            Update-Log -Data "$Index is the index we want to keep. Skipping." -Class Information | Out-Null
        } else {
            Update-Log -data "Deleting $Index from WIM" -Class Information
            Remove-WindowsImage -ImagePath $wimname -Name $Index -InformationAction SilentlyContinue | Out-Null

        }
    }
}
