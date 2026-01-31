Function Suspend-MakeItSo {
    $MISPause = ([System.Windows.MessageBox]::Show('Click Yes to continue the image build. Click No to cancel and discard the wim file.', 'WIM Witch Paused', 'YesNo', 'Warning'))
    if ($MISPause -eq 'Yes') { return 'Yes' }

    if ($MISPause -eq 'No') { return 'No' }
}
