Function Rename-Name($file, $extension) {
    $text = 'Renaming existing ' + $extension + ' file...'
    Update-Log -Data $text -Class Warning
    $filename = (Split-Path -Leaf $file)
    $dateinfo = (Get-Item -Path $file).LastWriteTime -replace (' ', '_') -replace ('/', '_') -replace (':', '_')
    $filename = $filename -replace ($extension, '')
    $filename = $filename + $dateinfo + $extension
    try {
        Rename-Item -Path $file -NewName $filename -ErrorAction Stop
        $text = $file + ' has been renamed to ' + $filename
        Update-Log -Data $text -Class Warning
    } catch {
        Update-Log -data "Couldn't rename file. Stopping..." -force -Class Error
        return 'stop'
    }
}
