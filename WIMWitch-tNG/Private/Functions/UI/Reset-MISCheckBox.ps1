Function Reset-MISCheckBox {
    Update-Log -data 'Refreshing MIS Values...' -class Information

    If ($WPFJSONEnableCheckBox.IsChecked -eq $true) {
        $WPFJSONButton.IsEnabled = $True
        $WPFMISJSONTextBox.Text = 'True'
    }
    If ($WPFDriverCheckBox.IsChecked -eq $true) {
        $WPFDriverDir1Button.IsEnabled = $True
        $WPFDriverDir2Button.IsEnabled = $True
        $WPFDriverDir3Button.IsEnabled = $True
        $WPFDriverDir4Button.IsEnabled = $True
        $WPFDriverDir5Button.IsEnabled = $True
        $WPFMISDriverTextBox.Text = 'True'
    }
    If ($WPFUpdatesEnableCheckBox.IsChecked -eq $true) {
        $WPFMISUpdatesTextBox.Text = 'True'
    }
    If ($WPFAppxCheckBox.IsChecked -eq $true) {
        $WPFAppxButton.IsEnabled = $True
        $WPFMISAppxTextBox.Text = 'True'
    }
    If ($WPFCustomCBEnableApp.IsChecked -eq $true) { $WPFCustomBDefaultApp.IsEnabled = $True }
    If ($WPFCustomCBEnableStart.IsChecked -eq $true) { $WPFCustomBStartMenu.IsEnabled = $True }
    If ($WPFCustomCBEnableRegistry.IsChecked -eq $true) {
        $WPFCustomBRegistryAdd.IsEnabled = $True
        $WPFCustomBRegistryRemove.IsEnabled = $True
    }

}
