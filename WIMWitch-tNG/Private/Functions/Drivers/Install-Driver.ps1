Function Install-Driver($drivertoapply) {
    try {
        Add-WindowsDriver -Path $WPFMISMountTextBox.Text -Driver $drivertoapply -ErrorAction Stop | Out-Null
        Update-Log -Data "Applied $drivertoapply" -Class Information
    } catch {
        Update-Log -Data "Couldn't apply $drivertoapply" -Class Warning
    }

}
