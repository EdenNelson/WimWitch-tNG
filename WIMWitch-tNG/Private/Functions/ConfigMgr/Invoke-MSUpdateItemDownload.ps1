Function Invoke-MSUpdateItemDownload {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true, HelpMessage = 'Specify the path to where the update item will be downloaded.')]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        $UpdateName
    )
    #write-host $updatename
    #write-host $filepath

    $OptionalUpdateCheck = 0

    #Adding in optional updates


    if ($UpdateName -like '*Adobe*') {
        $UpdateClass = 'AdobeSU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Microsoft .NET Framework*') {
        $UpdateClass = 'DotNet'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Cumulative Update for .NET Framework*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'DotNetCU'
    }
    if ($UpdateName -like '*Cumulative Update for Windows*') {
        $UpdateClass = 'LCU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Cumulative Update for Microsoft*') {
        $UpdateClass = 'LCU'
        $OptionalUpdateCheck = 1
    }
    if ($UpdateName -like '*Servicing Stack Update*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'SSU'
    }
    if ($UpdateName -like '*Dynamic*') {
        $OptionalUpdateCheck = 1
        $UpdateClass = 'Dynamic'
    }

    if ($OptionalUpdateCheck -eq '0') {

        #Update-Log -data "This update appears to be optional. Skipping..." -Class Warning
        #return
        if ($WPFUpdatesCBEnableOptional.IsChecked -eq $True) { Update-Log -data 'This update appears to be optional. Downloading...' -Class Information }
        else {
            Update-Log -data 'This update appears to be optional, but are not enabled for download. Skipping...' -Class Information
            return
        }
        #Update-Log -data "This update appears to be optional. Downloading..." -Class Information

        $UpdateClass = 'Optional'

    }

    if ($UpdateName -like '*Windows 10*') {
        #here
        #if (($UpdateName -like "* 1903 *") -or ($UpdateName -like "* 1909 *") -or ($UpdateName -like "* 2004 *") -or ($UpdateName -like "* 20H2 *") -or ($UpdateName -like "* 21H1 *") -or ($UpdateName -like "* 21H2 *") -or ($UpdateName -like "* 22H2 *")){$WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'"}

        if (($UpdateName -like '* 1903 *') -or ($UpdateName -like '* 1909 *') -or ($UpdateName -like '* 2004 *') -or ($UpdateName -like '* 20H2 *') -or ($UpdateName -like '* 21H1 *') -or ($UpdateName -like '* 21H2 *') -or ($UpdateName -like '* 22H2 *')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10, version 1903 and later'" }
        else { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10'" }
        if ($updateName -like '*Dynamic*') {
            if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 10 Dynamic Update'" }
        }
        #else{
        #Update-Log -data "Dynamic updates have not been selected for downloading. Skipping..." -Class Information
        #return
        #}
    }

    if ($UpdateName -like '*Windows 11*') {
        { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11'" }

        if ($updateName -like '*Dynamic*') {
            if ($WPFUpdatesCBEnableDynamic.IsChecked -eq $True) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows 11 Dynamic Update'" }
        }

    }



    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '1607')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2016'" }
    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '1809')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Windows Server 2019'" }
    if (($UpdateName -like '*Windows Server*') -and ($ver -eq '21H2')) { $WMIQueryFilter = "LocalizedCategoryInstanceNames = 'Microsoft Server operating system-21H2'" }


    $UpdateItem = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_SoftwareUpdate -ComputerName $global:SiteServer -Filter $WMIQueryFilter -ErrorAction Stop | Where-Object { ($_.LocalizedDisplayName -eq $UpdateName) }

    if ($null -ne $UpdateItem) {

        # Determine the ContentID instances associated with the update instance
        $UpdateItemContentIDs = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_CIToContent -ComputerName $global:SiteServer -Filter "CI_ID = $($UpdateItem.CI_ID)" -ErrorAction Stop
        if ($null -ne $UpdateItemContentIDs) {

            # Account for multiple content ID items
            foreach ($UpdateItemContentID in $UpdateItemContentIDs) {
                # Get the content files associated with current Content ID
                $UpdateItemContent = Get-WmiObject -Namespace "root\SMS\Site_$($global:SiteCode)" -Class SMS_CIContentFiles -ComputerName $global:SiteServer -Filter "ContentID = $($UpdateItemContentID.ContentID)" -ErrorAction Stop
                if ($null -ne $UpdateItemContent) {
                    # Handle both single object and array of objects
                    $UpdateItemContentArray = @($UpdateItemContent)

                    foreach ($ContentItem in $UpdateItemContentArray) {
                        # Filter: Only download .cab and .msu files
                        $fileExtension = [System.IO.Path]::GetExtension($ContentItem.filename).ToLower()
                        if ($fileExtension -ne '.cab' -and $fileExtension -ne '.msu') {
                            Update-Log -Data "Skipping non-CAB/MSU file: $($ContentItem.filename)" -Class Information
                            continue
                        }

                        # Filter: Skip incompatible CAB patterns (offline servicing not supported)
                        if ($ContentItem.filename -like '*FodMetadataServicing*') {
                            Update-Log -Data "Skipping FodMetadataServicing package (not compatible with offline servicing): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        if ($ContentItem.filename -like '*-express.cab') {
                            Update-Log -Data "Skipping express CAB (requires online servicing): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        if ($ContentItem.filename -like '*-baseless.cab') {
                            Update-Log -Data "Skipping baseless CAB (requires baseline already installed): $($ContentItem.filename)" -Class Information
                            continue
                        }

                        # Create new custom object for the update content
                        #write-host $ContentItem.filename
                        $PSObject = [PSCustomObject]@{
                            'DisplayName' = $UpdateItem.LocalizedDisplayName
                            'ArticleID'   = $UpdateItem.ArticleID
                            'FileName'    = $ContentItem.filename
                            'SourceURL'   = $ContentItem.SourceURL
                            'DateRevised' = [System.Management.ManagementDateTimeConverter]::ToDateTime($UpdateItem.DateRevised)
                        }

                        $variable = $FilePath + $UpdateClass + '\' + $UpdateName

                        if ((Test-Path -Path $variable) -eq $false) {
                            Update-Log -Data "Creating folder $variable" -Class Information
                            New-Item -Path $variable -ItemType Directory | Out-Null
                            Update-Log -data 'Created folder' -Class Information
                        }

                        $testpath = $variable + '\' + $PSObject.FileName

                        if ((Test-Path -Path $testpath) -eq $true) {
                            Update-Log -Data "Update item already exists. Skipping download of: $($PSObject.FileName)" -Class Information
                            continue
                        }

                        try {
                            Update-Log -Data "Downloading update item content from: $($PSObject.SourceURL)" -Class Information

                            $DNLDPath = $variable + '\' + $PSObject.FileName

                            $WebClient = New-Object -TypeName System.Net.WebClient
                            $WebClient.DownloadFile($PSObject.SourceURL, $DNLDPath)

                            Update-Log -Data "Download completed successfully, file: $($PSObject.FileName)" -Class Information

                            # Validate .cab files contain update.mum metadata
                            if ($PSObject.FileName -like '*.cab') {
                                Update-Log -Data "Validating CAB file contains update.mum metadata..." -Class Information
                                $validationPassed = $false
                                $validationAttempted = $false

                                try {
                                    # Method 1: Try PowerShell/COM approach using Shell.Application
                                    $shell = New-Object -ComObject Shell.Application
                                    $cabFolder = $shell.NameSpace($DNLDPath)

                                    if ($null -ne $cabFolder) {
                                        $updateMumFound = $false
                                        foreach ($item in $cabFolder.Items()) {
                                            if ($item.Name -match 'update\.mum') {
                                                $updateMumFound = $true
                                                break
                                            }
                                        }
                                        $validationAttempted = $true

                                        if (-not $updateMumFound) {
                                            Update-Log -Data "CAB file is invalid - does not contain update.mum metadata. Deleting: $($PSObject.FileName)" -Class Error
                                            Remove-Item -Path $DNLDPath -Force -ErrorAction Stop
                                            $ReturnValue = 1
                                        } else {
                                            Update-Log -Data "CAB file validation passed - update.mum metadata found (via COM)" -Class Information
                                            $validationPassed = $true
                                            $ReturnValue = 0
                                        }
                                    }
                                } catch {
                                    Update-Log -Data "COM validation method failed: $($_.Exception.Message)" -Class Warning
                                    $validationAttempted = $false
                                }

                                # Method 2: Fallback to expand.exe if COM method failed
                                if (-not $validationAttempted) {
                                    try {
                                        Update-Log -Data "Attempting validation with expand.exe..." -Class Information
                                        $expandExe = "$env:windir\system32\expand.exe"
                                        # List contents of CAB without extracting
                                        $cabContents = & $expandExe -D $DNLDPath 2>&1 | Out-String

                                        if ($cabContents -notmatch 'update\.mum') {
                                            Update-Log -Data "CAB file is invalid - does not contain update.mum metadata. Deleting: $($PSObject.FileName)" -Class Error
                                            Remove-Item -Path $DNLDPath -Force -ErrorAction Stop
                                            $ReturnValue = 1
                                        } else {
                                            Update-Log -Data "CAB file validation passed - update.mum metadata found (via expand.exe)" -Class Information
                                            $validationPassed = $true
                                            $ReturnValue = 0
                                        }
                                    } catch {
                                        Update-Log -Data "Failed to validate CAB file with expand.exe: $($_.Exception.Message)" -Class Warning
                                        $ReturnValue = 0  # Continue even if validation fails
                                    }
                                }

                                if (-not $validationPassed -and $ReturnValue -eq 0) {
                                    Update-Log -Data "CAB validation could not be completed - keeping file as fallback" -Class Warning
                                }
                            } else {
                                $ReturnValue = 0
                            }
                        } catch [System.Exception] {
                            Update-Log -data "Unable to download update item content. Error message: $($_.Exception.Message)" -Class Error
                            $ReturnValue = 1
                        }
                    }
                } else {
                    Update-Log -data "Unable to determine update content instance for CI_ID: $($UpdateItemContentID.ContentID)" -Class Error
                    $ReturnValue = 1
                }
            }
        } else {
            Update-Log -Data "Unable to determine ContentID instance for CI_ID: $($UpdateItem.CI_ID)" -Class Error
            $ReturnValue = 1
        }
    } else {
        Update-Log -data "Unable to locate update item from SMS Provider for update type: $($UpdateType)" -Class Error
        $ReturnValue = 2
    }


    # Handle return value from Function
    return $ReturnValue | Out-Null
}
