Function Start-Script($file, $parameter) {
    $string = "$file $parameter"
    try {
        Update-Log -Data 'Running script' -Class Information
        Invoke-Expression -Command $string -ErrorAction Stop
        Update-Log -data 'Script complete' -Class Information
    } catch {
        Update-Log -Data 'Script failed' -Class Error
    }
}
