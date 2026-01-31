Function Start-DriverInjection($Folder) {
    #This filters out invalid paths, such as the default value
    $testpath = Test-Path $folder -PathType Container
    If ($testpath -eq $false) { return }

    If ($testpath -eq $true) {

        Update-Log -data "Applying drivers from $folder" -class Information

        Get-ChildItem $Folder -Recurse -Filter '*inf' | ForEach-Object { Install-Driver $_.FullName }
        Update-Log -Data "Completed driver injection from $folder" -Class Information
    }
}
