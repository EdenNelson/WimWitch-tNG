Function Get-WindowsType {
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows 10*') { $type = 'Windows 10' }
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows Server*') { $type = 'Windows Server' }
    if ($WPFSourceWIMImgDesTextBox.text -like '*Windows 11*') { $type = 'Windows 11' }

    Return $type
}
