Function Import-ISO {
    $newname = $WPFImportNewNameTextBox.Text
    $file = $WPFImportISOTextBox.Text

    #Check to see if destination WIM already exists

    if ($WPFImportWIMCheckBox.IsChecked -eq $true) {
        Update-Log -data 'Checking to see if the destination WIM file exists...' -Class Information
        #check to see if the new name for the imported WIM is valid
        if (($WPFImportNewNameTextBox.Text -eq '') -or ($WPFImportNewNameTextBox.Text -eq 'Name for the imported WIM')) {
            Update-Log -Data 'Enter a valid file name for the imported WIM and then try again' -Class Error
            return
        }

        If ($newname -notlike '*.wim') {
            $newname = $newname + '.wim'
            Update-Log -Data 'Appending new file name with an extension' -Class Information
        }

        if ((Test-Path -Path $global:workdir\Imports\WIM\$newname) -eq $true) {
            Update-Log -Data 'Destination WIM name already exists. Provide a new name and try again.' -Class Error
            return
        } else {
            Update-Log -Data 'Name appears to be good. Continuing...' -Class Information
        }
    }

    #Mount ISO
    Update-Log -Data 'Mounting ISO...' -Class Information
    try {
        $isomount = Mount-DiskImage -ImagePath $file -PassThru -NoDriveLetter -ErrorAction Stop
        $iso = $isomount.devicepath

    } catch {
        Update-Log -Data 'Could not mount the ISO! Stopping actions...' -Class Error
        return
    }
    if (-not(Test-Path -Path (Join-Path $iso '\sources\'))) {
        Update-Log -Data 'Could not access the mounted ISO! Stopping actions...' -Class Error
        try {
            Invoke-RemoveISOMount -inputObject $isomount
        } catch {
            Update-Log -Data 'Attempted to dismount iso - might have failed...' -Class Warning
        }
        return
    }
    Update-Log -Data "$isomount" -Class Information
    #Testing for ESD or WIM format
    if (Test-Path -Path (Join-Path $iso '\sources\install.wim')) {
        $installWimFound = $true
    } elseif (Test-Path -Path (Join-Path $iso '\sources\install.esd')) {
        $installEsdFound = $true
        Update-Log -data 'Found ESD type installer - attempting to convert to WIM.' -Class Information
    } else {
        Update-Log -data 'Error accessing install.wim or install.esd! Breaking' -Class Warning
        try {
            Invoke-RemoveISOMount -inputObject $isomount
        } catch {
            Update-Log -Data 'Attempted to dismount iso - might have failed...' -Class Warning
        }
        return
    }

    try {
        if ($installWimFound) {
            $windowsver = Get-WindowsImage -ImagePath (Join-Path $iso '\sources\install.wim') -Index 1 -ErrorAction Stop
        } elseif ($installEsdFound) {
            $windowsver = Get-WindowsImage -ImagePath (Join-Path $iso '\sources\install.esd') -Index 1 -ErrorAction Stop
        }


        #####################
        $version = Set-Version -wimversion $windowsver.Version

        # Abort if unsupported Windows version detected
        if ($version -eq 'Unsupported') {
            Update-Log -Data "Cannot import unsupported Windows 10 build. Only Windows 10 22H2 is supported." -Class Error
            Write-Output 'Import cancelled - unsupported Windows version'
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

    } catch {
        Update-Log -data 'install.wim could not be found or accessed! Skipping...' -Class Warning
        $installWimFound = $false
    }


    #Copy out WIM file
    #if (($type -eq "all") -or ($type -eq "wim")) {
    if (($WPFImportWIMCheckBox.IsChecked -eq $true) -and (($installWimFound) -or ($installEsdFound))) {

        #Copy out the WIM file from the selected ISO
        try {
            Update-Log -data 'Purging staging folder...' -Class Information
            Remove-Item -Path $global:workdir\staging\*.* -Force
            Update-Log -data 'Purge complete.' -Class Information
            if ($installWimFound) {
                Update-Log -Data 'Copying WIM file to the staging folder...' -Class Information
                Copy-Item -Path $iso\sources\install.wim -Destination $global:workdir\staging -Force -ErrorAction Stop -PassThru
            }
        } catch {
            Update-Log -data "Couldn't copy from the source" -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

        #convert the ESD file to WIM
        if ($installEsdFound) {
            $sourceEsdFile = (Join-Path $iso '\sources\install.esd')
            Update-Log -Data 'Assessing install.esd file...' -Class Information
            $indexesFound = Get-WindowsImage -ImagePath $sourceEsdFile
            Update-Log -Data "$($indexesFound.Count) indexes found for conversion..." -Class Information
            foreach ($index in $indexesFound) {
                try {
                    Update-Log -Data "Converting index $($index.ImageIndex) - $($index.ImageName)" -Class Information
                    Export-WindowsImage -SourceImagePath $sourceEsdFile -SourceIndex $($index.ImageIndex) -DestinationImagePath (Join-Path $global:workdir '\staging\install.wim') -CompressionType fast -ErrorAction Stop
                } catch {
                    Update-Log -Data "Converting index $($index.ImageIndex) failed - skipping..." -Class Error
                    continue
                }
            }
        }

        #Change file attribute to normal
        Update-Log -Data 'Setting file attribute of install.wim to Normal' -Class Information
        $attrib = Get-Item $global:workdir\staging\install.wim
        $attrib.Attributes = 'Normal'

        #Rename install.wim to the new name
        try {
            $text = 'Renaming install.wim to ' + $newname
            Update-Log -Data $text -Class Information
            Rename-Item -Path $global:workdir\Staging\install.wim -NewName $newname -ErrorAction Stop
        } catch {
            Update-Log -data "Couldn't rename the copied file. Most likely a weird permissions issues." -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }

        #Move the imported WIM to the imports folder

        try {
            Update-Log -data "Moving $newname to imports folder..." -Class Information
            Move-Item -Path $global:workdir\Staging\$newname -Destination $global:workdir\Imports\WIM -ErrorAction Stop
        } catch {
            Update-Log -Data "Couldn't move the new WIM to the staging folder." -Class Error
            Invoke-RemoveISOMount -inputObject $isomount
            return
        }
        Update-Log -data 'WIM importation complete' -Class Information
    }

    #Copy DotNet binaries

    if ($WPFImportDotNetCheckBox.IsChecked -eq $true) {


        If (($windowsver.imagename -like '*Windows 10*') -or (($windowsver.imagename -like '*server') -and ($windowsver.version -lt 10.0.20248.0))) { $Path = "$global:workdir\Imports\DotNet\$version" }
        If (($windowsver.Imagename -like '*server*') -and ($windowsver.version -gt 10.0.20348.0)) { $Path = "$global:workdir\Imports\Dotnet\Windows Server\$version" }
        If ($windowsver.imagename -like '*Windows 11*') { $Path = "$global:workdir\Imports\Dotnet\Windows 11\$version" }


        if ((Test-Path -Path $Path) -eq $false) {

            try {
                Update-Log -Data 'Creating folders...' -Class Warning

                New-Item -Path (Split-Path -Path $path -Parent) -Name $version -ItemType Directory -ErrorAction stop | Out-Null

            } catch {
                Update-Log -Data "Couldn't creating new folder in DotNet imports folder" -Class Error
                return
            }
        }


        try {
            Update-Log -Data 'Copying .Net binaries...' -Class Information
            Copy-Item -Path $iso\sources\sxs\*netfx3* -Destination $path -Force -ErrorAction Stop

        } catch {
            Update-Log -Data "Couldn't copy the .Net binaries" -Class Error
            return
        }
    }

    #Copy out ISO files
    if ($WPFImportISOCheckBox.IsChecked -eq $true) {
        #Determine if is Windows 10 or Windows Server
        Update-Log -Data 'Importing ISO/Upgrade Package files...' -Class Information

        if ($windowsver.ImageName -like 'Windows 10*') { $OS = 'Windows 10' }

        if ($windowsver.ImageName -like 'Windows 11*') { $OS = 'Windows 11' }

        if ($windowsver.ImageName -like '*Server*') { $OS = 'Windows Server' }
        Update-Log -Data "$OS detected" -Class Information
        if ((Test-Path -Path $global:workdir\imports\iso\$OS\$Version) -eq $false) {
            Update-Log -Data 'Path does not exist. Creating...' -Class Information
            New-Item -Path $global:workdir\imports\iso\$OS\ -Name $version -ItemType Directory
        }

        Update-Log -Data 'Copying boot folder...' -Class Information
        Copy-Item -Path $iso\boot\ -Destination $global:workdir\imports\iso\$OS\$Version\boot -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying efi folder...' -Class Information
        Copy-Item -Path $iso\efi\ -Destination $global:workdir\imports\iso\$OS\$Version\efi -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying sources folder...' -Class Information
        Copy-Item -Path $iso\sources\ -Destination $global:workdir\imports\iso\$OS\$Version\sources -Recurse -Force -Exclude install.wim

        Update-Log -Data 'Copying support folder...' -Class Information
        Copy-Item -Path $iso\support\ -Destination $global:workdir\imports\iso\$OS\$Version\support -Recurse -Force #-Exclude install.wim

        Update-Log -Data 'Copying files in root folder...' -Class Information
        Copy-Item $iso\autorun.inf -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\bootmgr -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\bootmgr.efi -Destination $global:workdir\imports\iso\$OS\$Version\ -Force
        Copy-Item $iso\setup.exe -Destination $global:workdir\imports\iso\$OS\$Version\ -Force

    }

    #Dismount and finish
    try {
        Update-Log -Data 'Dismount!' -Class Information
        Invoke-RemoveISOMount -inputObject $isomount
    } catch {
        Update-Log -Data "Couldn't dismount the ISO. WIM Witch uses a file mount option that does not" -Class Error
        Update-Log -Data 'provision a drive letter. Use the Dismount-DiskImage command to manaully dismount.' -Class Error
    }
    Update-Log -data 'Importing complete' -class Information
}
# SIG # Begin signature block
# MIIfCAYJKoZIhvcNAQcCoIIe+TCCHvUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBFjpvDSnapJopWN1hEAUO5AN
# bHugghk5MIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG9w0B
# AQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4w
# LAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MB4X
# DTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMg
# VGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGK
# AoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yavjA6Bg+OiIjPm/N/t3nC7
# wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6WzeJDB9qkQVa46xiYEpc8
# 1KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9djnjkTdAA83abEOHQ4ujO
# GIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw5+4v1nssWeN1y4+RlaOy
# wwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM8ZpHadmVjbi3Pl8hJiTW
# w9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCulVq8ZpysiSYNi79tw5RHW
# ZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtOcgw+vHJcJ8HnJCrcUWhd
# Fczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWmbiAVPbgkqykSkzyYVr15
# OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3at0//QET/xahbIICL9AK
# PRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIymzAOBgNVHQ8BAf8EBAMC
# AYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNV
# HSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7aHR0cDovL2NybC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nUm9vdFI0Ni5jcmwwfAYI
# KwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8vY3J0LnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LnA3YzAjBggrBgEFBQcw
# AYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIBABLX
# eyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdltoX4hDskBMZx5NY5L6SCcw
# DMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAXyIIaUf5JVKjccev3w16m
# NIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp8MbOocI9Zn78xvm9XKGB
# p6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjEnBnxuUB1fm6bPAV+Tsr/
# Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf6vATJP4DfPtKzSBPkKlO
# tyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm6N2s2ZHCHVhlUgHaC4AC
# MRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjVZFpO4ZIVR33LwXyPDbYF
# kLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbntinmpOqh/QPAnhDgexKG9
# GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM6noD2XQPrFwpm3GcuqJM
# f0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygcto78XCSPfFWveUOSZ5SqK
# 95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIGMTCCBRmgAwIBAgITXQAA
# AkSPdub9u4IuqwADAAACRDANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB
# GRYDb3JnMRswGQYKCZImiZPyLGQBGRYLY2FzY2FkZXRlY2gxFTATBgoJkiaJk/Is
# ZAEZFgVpbnRyYTEPMA0GA1UEAxMGQ1RBLUNBMB4XDTE3MDMyNzE4NDEwMFoXDTI3
# MDMyNTE4NDEwMFowbjETMBEGCgmSJomT8ixkARkWA29yZzEbMBkGCgmSJomT8ixk
# ARkWC2Nhc2NhZGV0ZWNoMRUwEwYKCZImiZPyLGQBGRYFaW50cmExDTALBgNVBAsT
# BE1FU0QxFDASBgNVBAMTC0VkZW4gTmVsc29uMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEA6t55EHD8rTEtKnmrfoxUKjVUM9Eu6/4lcnLFJFaXAAGFp6HK
# kZoQFNgVvd4pfMYXvYV1mq/Z1PxYeACmjOjVxLwtUCx3N2GX439aFtvxRX+Kc1SJ
# 223NfPPq86dgzVupascWtmFB6srs79ifLXH6yqEYPiQlnfXDf2Bkomx0HcPLcqKp
# plsRToyLWOCGDkvovii2E+cGlaSPHE6Rekyz7NioJHeqw/n7DgFxR+zHK0ekIr5I
# t9WST6vo1eOvVSIxEA4IsVFt0KNuMt4QhwvP0msZevIklGx9AE8Ptomk9EfPUtGH
# 0C23BuGzN5XsqaJoLclNjle4MXlMrrkZMCvkPwIDAQABo4IC2jCCAtYwPAYJKwYB
# BAGCNxUHBC8wLQYlKwYBBAGCNxUIgdubPYHF4BGB8Y8AhveZM9LraYEKuqx8h6nA
# fQIBZAIBAjATBgNVHSUEDDAKBggrBgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwGwYJ
# KwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU1/EpGs3xdVYJkUuj
# LTWDc1kWxcYwHwYDVR0jBBgwFoAURbUVcNI0zRtVrM0lx4fqlrvCJZ8wggERBgNV
# HR8EggEIMIIBBDCCAQCggf2ggfqGgb9sZGFwOi8vL0NOPUNUQS1DQSgyKSxDTj1D
# VEEtREMtMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNl
# cnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9aW50cmEsREM9Y2FzY2FkZXRlY2gs
# REM9b3JnP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFz
# cz1jUkxEaXN0cmlidXRpb25Qb2ludIY2aHR0cDovL2N0YWNybC5jYXNjYWRldGVj
# aC5vcmcvQ2VydEVucm9sbC9DVEEtQ0EoMikuY3JsMIHFBggrBgEFBQcBAQSBuDCB
# tTCBsgYIKwYBBQUHMAKGgaVsZGFwOi8vL0NOPUNUQS1DQSxDTj1BSUEsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1pbnRyYSxEQz1jYXNjYWRldGVjaCxEQz1vcmc/Y0FDZXJ0aWZpY2F0ZT9i
# YXNlP29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwNwYDVR0RBDAw
# LqAsBgorBgEEAYI3FAIDoB4MHG5lbHNvbkBpbnRyYS5jYXNjYWRldGVjaC5vcmcw
# DQYJKoZIhvcNAQELBQADggEBADqKPu55+4xpvtgMmdeU1pdFYz83yntNhvlf2ikI
# +ASsqvoVi1XDXeKcZak6lxdO7NTZ1R7IKMyQWsM3/JUGTCpgaeSJwTfa7C/uDCvL
# XKLvsbURoQWG2bPMzno30Oy4yUKASg6Y46ibMgsIrQHnNjMhphF0gIhjKqI+XS44
# avQjH+78SAoI+ET0JB2qdojlg76VUpfBrfhcuSVzRuRFUFwX8taI2bHRTAa6XXsF
# XTJsHua5gvmtF9zSvr5A+h+JJmWXNhpg579bpytyrIztoDJ2JzhkrhJl0QPZ7klj
# 2yRcSFLGc59qfhX1kDYM8/cJxRaXRyBByr5Gl7Zg87N3+uQwggZiMIIEyqADAgEC
# AhEApCk7bh7d16c0CIetek63JDANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJH
# QjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1
# YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBaFw0zNjAz
# MjEyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlvcmtzaGly
# ZTEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1
# YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDThJX0bqRTePI9EEt4Egc83JSBU2dhrJ+wY7JgReuff5KQ
# NhMuzVytzD+iXazATVPMHZpH/kkiMo1/vlAGFrYN2P7g0Q8oPEcR3h0SftFNYxxM
# h+bj3ZNbbYjwt8f4DsSHPT+xp9zoFuw0HOMdO3sWeA1+F8mhg6uS6BJpPwXQjNSH
# pVTCgd1gOmKWf12HSfSbnjl3kDm0kP3aIUAhsodBYZsJA1imWqkAVqwcGfvs6pbf
# s/0GE4BJ2aOnciKNiIV1wDRZAh7rS/O+uTQcb6JVzBVmPP63k5xcZNzGo4DOTV+s
# M1nVrDycWEYS8bSS0lCSeclkTcPjQah9Xs7xbOBoCdmahSfg8Km8ffq8PhdoAXYK
# OI+wlaJj+PbEuwm6rHcm24jhqQfQyYbOUFTKWFe901VdyMC4gRwRAq04FH2VTjBd
# CkhKts5Py7H73obMGrxN1uGgVyZho4FkqXA8/uk6nkzPH9QyHIED3c9CGIJ098hU
# 4Ig2xRjhTbengoncXUeo/cfpKXDeUcAKcuKUYRNdGDlf8WnwbyqUblj4zj1kQZSn
# Zud5EtmjIdPLKce8UhKl5+EEJXQp1Fkc9y5Ivk4AZacGMCVG0e+wwGsjcAADRO7W
# ga89r/jJ56IDK773LdIsL3yANVvJKdeeS6OOEiH6hpq2yT+jJ/lHa9zEdqFqMwID
# AQABo4IBjjCCAYowHwYDVR0jBBgwFoAUX1jtTDF6omFCjVKAurNhlxmiMpswHQYD
# VR0OBBYEFIhhjKEqN2SBKGChmzHQjP0sAs5PMA4GA1UdDwEB/wQEAwIGwDAMBgNV
# HRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEwNQYM
# KwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20v
# Q1BTMAgGBmeBDAEEAjBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3JsLnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcmwwegYIKwYB
# BQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28uY29tL1Nl
# Y3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0
# dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQACgT6khnJR
# IfllqS49Uorh5ZvMSxNEk4SNsi7qvu+bNdcuknHgXIaZyqcVmhrV3PHcmtQKt0bl
# v/8t8DE4bL0+H0m2tgKElpUeu6wOH02BjCIYM6HLInbNHLf6R2qHC1SUsJ02MWNq
# RNIT6GQL0Xm3LW7E6hDZmR8jlYzhZcDdkdw0cHhXjbOLsmTeS0SeRJ1WJXEzqt25
# dbSOaaK7vVmkEVkOHsp16ez49Bc+Ayq/Oh2BAkSTFog43ldEKgHEDBbCIyba2E8O
# 5lPNan+BQXOLuLMKYS3ikTcp/Qw63dxyDCfgqXYUhxBpXnmeSO/WA4NwdwP35lWN
# hmjIpNVZvhWoxDL+PxDdpph3+M5DroWGTc1ZuDa1iXmOFAK4iwTnlWDg3QNRsRa9
# cnG3FBBpVHnHOEQj4GMkrOHdNDTbonEeGvZ+4nSZXrwCW4Wv2qyGDBLlKk3kUW1p
# IScDCpm/chL6aUbnSsrtbepdtbCLiGanKVR/KC1gsR0tC6Q0RfWOI4owggaCMIIE
# aqADAgECAhA2wrC9fBs656Oz3TbLyXVoMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENp
# dHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNF
# UlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0yMTAzMjIwMDAw
# MDBaFw0zODAxMTgyMzU5NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0
# aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBp
# bmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCIndi5
# RWedHd3ouSaBmlRUwHxJBZvMWhUP2ZQQRLRBQIF3FJmp1OR2LMgIU14g0JIlL6VX
# WKmdbmKGRDILRxEtZdQnOh2qmcxGzjqemIk8et8sE6J+N+Gl1cnZocew8eCAawKL
# u4TRrCoqCAT8uRjDeypoGJrruH/drCio28aqIVEn45NZiZQI7YYBex48eL78lQ0B
# rHeSmqy1uXe9xN04aG0pKG9ki+PC6VEfzutu6Q3IcZZfm00r9YAEp/4aeiLhyaKx
# LuhKKaAdQjRaf/h6U13jQEV1JnUTCm511n5avv4N+jSVwd+Wb8UMOs4netapq5Q/
# yGyiQOgjsP/JRUj0MAT9YrcmXcLgsrAimfWY3MzKm1HCxcquinTqbs1Q0d2VMMQy
# i9cAgMYC9jKc+3mW62/yVl4jnDcw6ULJsBkOkrcPLUwqj7poS0T2+2JMzPP+jZ1h
# 90/QpZnBkhdtixMiWDVgh60KmLmzXiqJc6lGwqoUqpq/1HVHm+Pc2B6+wCy/GwCc
# jw5rmzajLbmqGygEgaj/OLoanEWP6Y52Hflef3XLvYnhEY4kSirMQhtberRvaI+5
# YsD3XVxHGBjlIli5u+NrLedIxsE88WzKXqZjj9Zi5ybJL2WjeXuOTbswB7XjkZbE
# rg7ebeAQUQiS/uRGZ58NHs57ZPUfECcgJC+v2wIDAQABo4IBFjCCARIwHwYDVR0j
# BBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFPZ3at0//QET/xah
# bIICL9AKPRQlMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWg
# Q6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlm
# aWNhdGlvbkF1dGhvcml0eS5jcmwwNQYIKwYBBQUHAQEEKTAnMCUGCCsGAQUFBzAB
# hhlodHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAO
# vmVB7WhEuOWhxdQRh+S3OyWM637ayBeR7djxQ8SihTnLf2sABFoB0DFR6JfWS0sn
# f6WDG2gtCGflwVvcYXZJJlFfym1Doi+4PfDP8s0cqlDmdfyGOwMtGGzJ4iImyaz3
# IBae91g50QyrVbrUoT0mUGQHbRcF57olpfHhQEStz5i6hJvVLFV/ueQ21SM99zG4
# W2tB1ExGL98idX8ChsTwbD/zIExAopoe3l6JrzJtPxj8V9rocAnLP2C8Q5wXVVZc
# bw4x4ztXLsGzqZIiRh5i111TW7HV1AtsQa6vXy633vCAbAOIaKcLAo/IU7sClyZU
# k62XD0VUnHD+YvVNvIGezjM6CRpcWed/ODiptK+evDKPU2K6synimYBaNH49v9Ih
# 24+eYXNtI38byt5kIvh+8aW88WThRpv8lUJKaPn37+YHYafob9Rg7LyTrSYpyZoB
# mwRWSE4W6iPjB7wJjJpH29308ZkpKKdpkiS9WNsf/eeUtvRrtIEiSJHN899L1P4l
# 6zKVsdrUu1FX1T/ubSrsxrYJD+3f3aKg6yxdbugot06YwGXXiy5UUGZvOu3lXlxA
# +fC13dQ5OlL2gIb5lmF6Ii8+CQOYDwXM+yd9dbmocQsHjcRPsccUd5E9FiswEqOR
# vz8g3s+jR3SFCgXhN4wz7NgAnOgpCdUo4uDyllU9PzGCBTkwggU1AgEBMHEwWjET
# MBEGCgmSJomT8ixkARkWA29yZzEbMBkGCgmSJomT8ixkARkWC2Nhc2NhZGV0ZWNo
# MRUwEwYKCZImiZPyLGQBGRYFaW50cmExDzANBgNVBAMTBkNUQS1DQQITXQAAAkSP
# dub9u4IuqwADAAACRDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQyiiZHKcAkwMPwZ1ZGPMcLzT
# uRgwDQYJKoZIhvcNAQEBBQAEggEAe+jiFmvvhw7P1F4B/ND3CvBCKRvtdFJrRlgG
# qWlGScJjbupH5GUVOBWXlbpcYJ62rXkKFFGR1P1mOltQ9YxL9/tS266c6gOZTJHn
# 8CwPX6Nztk5A5H9t7AKKNg8Fs2cE84P14LQDFdBPhy17pqDk+GjKh+76zdYtPhI8
# vTBa5EHq5V3f2uTYS0nOv/BTHMwm+PORwOLvQvZvVjat/bTjQmhNky5we5D6SV/Z
# Uk+kEg6n+JTzDaKHMu/NFTRjUleUBBxh+W1qBmWLiSKkeulPs605ZruTbStzdpIX
# +f1KdO4jynn8yoIsiPITJ0k6RTIFGQwBEx6MYMZd7Uyr/IyKsKGCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDAxNTAzMVowPwYJKoZIhvcNAQkEMTIEMIFBet3uiCsOjEulIWR9fmYuv6tCzaGh
# 6MFLtGG+M21CboK3aGFw3b4xR0Fdmg4StjANBgkqhkiG9w0BAQEFAASCAgBCCFiy
# SvtJcB5/iFFki78mxsCh0VO+aKff2eORGjFKPl1yY/vBoWJxqK1Ap49JyjS83CLP
# c1AoTw6S8mAP/xnRB/dqqmiBvCyWpUO6wbuLVUwRCqOP/nS9zcoVcx3HQr0Bq3kP
# 8w5rbHSKKW6MMV0k5llW3ryk3zSpBx4djq2DrQ04GFdGKS8bO+9h4Nz33Gy+tQve
# Jd6ERsAQflWg/NIdfa6Y7oodgmg4pMV5jeR0HSwrx0nh18/IMYovEoAmOQyu5YIf
# VtHq1p2J+EKNEj3Cgbnfg9vHK6BoJ0yvdqtqsZPHrOfDT94cW9EZZkC+ZANB38Rj
# YRySpNldGWMaF1yCwkorAtNyApqZGePZDIDftWDl7DCWQjx/hchPX9WViX6fTByn
# nvQcDzR5KcLXMS8uoBxmWo/F6S6f6oXa0gQJJfRhkBvvie6pMZ86UY7YqKMjAVnz
# AkQkeK09QnFahhhDFuvi4M4ggBibsEsRxseU1tOniM2pd2h0Vc5oqtPjQtkuIHzJ
# lvdolcg+b0iFyAazDQcQUNY6O4+pg41JQCVEVMqzeqB/zvDqsAtXUq6MKkCI33ki
# aKE2JWucTLrHIMWXJlN1Yqib1RNNYbmA549DebULU0hGl8U3eQrQMHBvxZh+dVGT
# bsHM/O5dGEl9zRvf7LVfsGmsOOwh5y0S7E1R0A==
# SIG # End signature block
