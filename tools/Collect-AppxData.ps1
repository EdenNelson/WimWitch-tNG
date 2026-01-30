<#
.SYNOPSIS
    Collects AppX package data from a live Windows installation.

.DESCRIPTION
    This script runs on a live Windows installation to gather comprehensive AppX package data.
    It detects the Windows version, build number, and architecture, then extracts all
    provisioned AppX packages. The raw data is saved as a PSD1 file for later processing
    by an AI agent in VSCode.

.PARAMETER OutputPath
    Directory where the raw data PSD1 file will be saved.
    Default: ./appxData/

.PARAMETER Verbose
    Shows detailed progress during package detection.

.EXAMPLE
    .\Collect-AppxData.ps1 -Verbose
    Collects AppX data with verbose output, saves to ./appxData/

.EXAMPLE
    .\Collect-AppxData.ps1 -OutputPath "C:\AppxBackup\"
    Collects AppX data and saves to specified directory

.NOTES
    Author: Eden Nelson [edennelson]
    Version: 1.0
    Date: 2026-01-19

    This script performs NO filtering or categorization.
    It simply collects raw data for AI processing in VSCode.

    Code Origin:
    Portions of this script were generated with assistance from GitHub Copilot AI.
    The author has reviewed and tested all code.
    This is disclosed in the interest of transparency.
    The author does not make claims regarding potential infringement or plagiarism.

    Requirements:
    - Must run on live Windows installation
    - Requires administrative privileges
    - Windows 10 22H2 or Windows 11 supported

.LINK
    https://github.com/edennelson/WimWitch-tNG
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\appxData\"
)

#Requires -RunAsAdministrator

# Script metadata
$scriptVersion = "1.0"
$scriptName = "Collect-AppxData.ps1"

Write-Output "=================================================="
Write-Output "  WimWitch-tNG: AppX Data Collection"
Write-Output "  Version: $scriptVersion"
Write-Output "=================================================="
Write-Output ""

# Step 1: Detect Windows environment
Write-Verbose -Message "Step 1: Detecting Windows environment..."
try {
    $osInfo = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop

    $buildNumber = $osInfo.CurrentBuild
    $ubr = $osInfo.UBR
    $displayVersion = $osInfo.DisplayVersion
    $productName = $osInfo.ProductName
    $editionID = $osInfo.EditionID
    $architecture = $env:PROCESSOR_ARCHITECTURE

    # Determine Windows version label
    $windowsVersion = if ($productName -match "Windows 10") {
        "Win10-$displayVersion"
    } elseif ($productName -match "Windows 11") {
        "Win11-$displayVersion"
    } else {
        "Windows-Unknown"
    }

    Write-Output "[OK] Windows Version Detected"
    Write-Output "    Product: $productName"
    Write-Output "    Version: $displayVersion (Build $buildNumber.$ubr)"
    Write-Output "    Edition: $editionID"
    Write-Output "    Architecture: $architecture"
    Write-Output ""

} catch {
    Write-Error -Message "Failed to detect Windows version: $_"
    exit 1
}

# Step 2: Extract ALL AppX packages
Write-Verbose -Message "Step 2: Extracting AppX packages from system..."
Write-Output "Querying provisioned packages (this may take 30-60 seconds)..."

try {
    $packages = Get-AppxProvisionedPackage -Online -ErrorAction Stop | Select-Object -Property `
        DisplayName,
        PackageName,
        Version,
        Architecture,
        @{Name='PublisherId';Expression={$_.PublisherId}},
        @{Name='ResourceId';Expression={$_.ResourceId}}

    Write-Output "[OK] Package Extraction Complete"
    Write-Output "    Total packages found: $($packages.Count)"
    Write-Output ""

    if ($packages.Count -lt 100) {
        Write-Error -Message "Package count seems low ($($packages.Count)). Expected 300-450 packages."
        Write-Error -Message "This may indicate an incomplete Windows installation."
        $continue = Read-Host -Prompt "Continue anyway? (Y/N)"
        if ($continue -ne 'Y') {
            Write-Output "Aborted by user."
            exit 1
        }
    }

} catch {
    Write-Error -Message "Failed to extract AppX packages: $_"
    exit 1
}

# Step 3: Build metadata
Write-Verbose -Message "Step 3: Building metadata..."

$metadata = @{
    WindowsVersion = $displayVersion
    ProductName = $productName
    EditionID = $editionID
    BuildNumber = "$buildNumber.$ubr"
    Architecture = $architecture
    CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CollectionDateUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    TotalPackages = $packages.Count
    Collector = "$scriptName v$scriptVersion"
    ComputerName = $env:COMPUTERNAME
}

Write-Output "[OK] Metadata Created"

# Step 4: Prepare output directory
Write-Verbose -Message "Step 4: Preparing output directory..."

if (-not (Test-Path -Path $OutputPath)) {
    try {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Output "[OK] Created output directory: $OutputPath"
    } catch {
        Write-Error -Message "Failed to create output directory: $_"
        exit 1
    }
} else {
    Write-Output "[OK] Output directory exists: $OutputPath"
}

# Step 5: Save raw data (NO FILTERING)
Write-Verbose -Message "Step 5: Saving raw data..."

$outputFileName = "appxData-$windowsVersion-Build$buildNumber-raw.psd1"
$outputFilePath = Join-Path -Path $OutputPath -ChildPath $outputFileName

try {
    $dataObject = @{
        Metadata = $metadata
        Packages = $packages
    }

    # Export as CliXml for easy re-import in PowerShell/VSCode
    $dataObject | Export-Clixml -Path $outputFilePath -Force -ErrorAction Stop

    Write-Output ""
    Write-Output "=================================================="
    Write-Output "  Data Collection Complete!"
    Write-Output "=================================================="
    Write-Output ""
    Write-Output "Output File: $outputFilePath"
    Write-Output "Total Packages: $($packages.Count)"
    Write-Output "File Size: $([math]::Round((Get-Item -Path $outputFilePath).Length / 1KB, 2)) KB"
    Write-Output ""
    Write-Output "NEXT STEPS:"
    Write-Output "1. Copy this file to your development machine:"
    Write-Output "   ~/Documents/GitHub/WimWitch-tNG/tools/appxData/"
    Write-Output ""
    Write-Output "2. Open VSCode with WimWitch-tNG workspace"
    Write-Output ""
    Write-Output "3. Reference the AI prompt in GitHub Copilot Chat:"
    Write-Output "   '@workspace Use #file:.github/prompts/process-appxData.prompt.md"
    Write-Output "   to process tools/appxData/$outputFileName'"
    Write-Output ""

} catch {
    Write-Error -Message "Failed to save raw data: $_"
    exit 1
}

# Optional: Display package summary
if ($VerbosePreference -eq 'Continue') {
    Write-Output ""
    Write-Output "Package Summary (Top Publishers):"
    $packages | Group-Object -Property {($_.PackageName -split '_')[0]} |
        Sort-Object -Property Count -Descending |
        Select-Object -First 10 |
        ForEach-Object -Process {
            Write-Output "  $($_.Name): $($_.Count) packages"
        }
}

Write-Output ""
Write-Output "Data collection successful."

# SIG # Begin signature block
# MIIfCAYJKoZIhvcNAQcCoIIe+TCCHvUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7iCr3mG+lOLy3bZukHEPIJAo
# Fqegghk5MIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUX8mm80O5A9Gg0vl4MdoFIkaY
# JHQwDQYJKoZIhvcNAQEBBQAEggEAe/beLdYJ7Hh8da78pkTLzpy5968MTT5vV74r
# 0+3BX0dZaKXiKkE4Q67qlGRNtLQhFpo3hxSvkOnkT50AUyW1gAmNJPmkSyEdVuqx
# Xk2HGcXnMdrTlg6RY4utj0aulmJpKM2A4DAUz0z69Mt2of0qbXTGviC5vS7oD7+S
# 8eUjpAD5TveLrTzVzPzc4y80GeLIkpfq/ATjY08Zuk0KXd09tjzn0NeQgkJvuiWs
# xPM6dsRFTLU3wA5RE43oY91GqIm/QiHMRlnwbzQBfjb3PfIaZ+0H8Ep+yJLE8dAF
# NqNcKou82UEFCsZryqszkiGFqijgy3vJnCtE9saOKLLT9juct6GCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDAxNDkxOVowPwYJKoZIhvcNAQkEMTIEMEJzy59Ri0FGvf6Atvw7KaeKycOknCWl
# d41+5DsnL8+dB/kyD8NqR+n4tNEfBjkBiDANBgkqhkiG9w0BAQEFAASCAgBcV7+p
# BEO1VgqZkqrFTE8KehKofK0HuwFnxGwezctwzd68yLPrAWWczHbHQSTwq6W8mSMT
# jH+vXxKBugfgjTVQyeZfhNZc8uaVB7GD3KMBdnNwrQE5RKoIFvGlFerAUmRoLhCb
# uuxiWFRKx3OtK38RfxnnRjEg9ipkXbPuSj3r5uondvd+bqz8L7v6umnxzSEg/onf
# dwTVEA9e/bLbDIKX0qFTcr02p2aIVQ5wvQkUr/JqqMFv+XLq8RLSeenuprl1rC9A
# LCgybP8GtUVx6WI53EhjVGqTrPvH6rRHiW4AXFHLY9lcgf69tpSKCSbMvsB+BZGq
# ZzVh+xFj9lecmJySV+nHjla4h4wkg/Pb64/D3CJ9GdflPlRRGHxwuKVUHOdptRB+
# Ixio4NO4uEquNDpX19FA5aCzJoR893RmyalptbAxTEA5dkzGO9EXuwt+LE3zs6uk
# zRlrW7s8zgT7UPAJT0VqA4nmox8ixzS5Wx4Ixsca4fRzMcxGw/OJd/e95hhUFlg2
# k/wG4kOI/qqDBmdH7YiShw1mv60qIKsI3hEP0Y8aC9pZADhxGUTFqJtIjUr+6rH7
# 5tEYHXYaARIzXo+bVMhKoW/PFq+f4hKa05bPZ/8GZilujPsmYGmoqffBL3zSTtyM
# sFObQG/cuiJFmhiG+6jSejBCUELxFlCYIWkvqw==
# SIG # End signature block
