Function Invoke-MEMCMUpdatecatalog($prod, $ver) {

    #set-ConfigMgrConnection
    Push-Location $CMDrive
    try {
        $Arch = 'x64'

        if ($prod -eq 'Windows 10') {
            #        if (($ver -ge '1903') -or ($ver -eq "21H1")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}
            #        if (($ver -ge '1903') -or ($ver -eq "21H1") -or ($ver -eq "20H2") -or ($ver -eq "21H2") -or ($ver -eq "22H2")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}
            #here
            if (($ver -ge '1903') -or ($ver -like '2*')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'" }


            if ($ver -le '1809') { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10'" }

            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } )
        }


        if (($prod -like '*Windows Server*') -and ($ver -eq '1607')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2016'"
            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -notlike '* Next *') -and ($_.LocalizedDisplayName -notlike '*(1703)*') -and ($_.LocalizedDisplayName -notlike '*(1709)*') -and ($_.LocalizedDisplayName -notlike '*(1803)*') })
        }

        if (($prod -like '*Windows Server*') -and ($ver -eq '1809')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2019'"
            $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
        }

        if (($prod -like '*Windows Server*') -and ($ver -eq '21H2')) {
            $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Microsoft Server operating system-21H2'"
        $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
    }

    if ($prod -eq 'Windows 11') {
        $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11'"
        #$Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($Arch)*") } )
        if ($ver -eq '21H2') { $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*Windows 11 for $($Arch)*") } ) }
        else { $Updates = (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } ) }


    }

    if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) {

        if ($prod -eq 'Windows 10') { $Updates = $Updates + (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter "LocalizedCategoryInstanceNames = 'Windows 10 Dynamic Update'" -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$($ver)*$($Arch)*") } ) }
        if ($prod -eq 'Windows 11') { $Updates = $Updates + (Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter "LocalizedCategoryInstanceNames = 'Windows 11 Dynamic Update'" -ErrorAction Stop | Where-Object { ($_.IsSuperseded -eq $false) -and ($_.LocalizedDisplayName -like "*$prod*") -and ($_.LocalizedDisplayName -like "*$arch*") } ) }


    }


    if ($null -eq $updates) {
        Update-Log -data 'No updates found. Product is likely not synchronized. Continuing with build...' -class Warning
        return
    }


    foreach ($update in $updates) {
        if ((($update.localizeddisplayname -notlike 'Feature update*') -and ($update.localizeddisplayname -notlike 'Upgrade to Windows 11*' )) -and ($update.localizeddisplayname -notlike '*Language Pack*') -and ($update.localizeddisplayname -notlike '*editions),*')) {

            # Filter by severity/classification
            $severity = $update.SeverityName

            # Skip optional updates if checkbox is not enabled
            if (($severity -eq 'Optional') -and ($WPFUpdatesCBEnableOptional.IsChecked -ne $True)) {
                Update-Log -Data "Skipping optional update (checkbox disabled): $($update.LocalizedDisplayName)" -Class Information
                continue
            }

            # Skip definition updates (always)
            if ($severity -eq 'Definition Updates') {
                Update-Log -Data "Skipping definition update: $($update.LocalizedDisplayName)" -Class Information
                continue
            }

            Update-Log -Data "Checking update [$severity]: $($update.LocalizedDisplayName)" -Class Information
            #write-host "Display Name"
            #write-host $update.LocalizedDisplayName
            #            if ($ver -eq  "20H2"){$ver = "2009"} #Another 20H2 naming work around
            Invoke-MSUpdateItemDownload -FilePath "$global:workdir\updates\$Prod\$ver\" -UpdateName $update.LocalizedDisplayName
        }
    }
    } finally {
        Pop-Location
    }
}
