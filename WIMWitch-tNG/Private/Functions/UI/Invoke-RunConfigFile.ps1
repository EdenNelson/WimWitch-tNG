Function Invoke-RunConfigFile($filename) {
    Update-Log -Data "Loading the config file: $filename" -Class Information
    Get-Configuration -filename $filename
    Update-Log -Data $WWScriptVer
    Invoke-MakeItSo -appx $global:SelectedAppx
    Write-Output ' '
    Write-Output '##########################################################'
    Write-Output ' '
}
