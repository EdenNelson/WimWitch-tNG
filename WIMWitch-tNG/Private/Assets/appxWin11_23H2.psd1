<#
.SYNOPSIS
    Windows 11 23H2 removable AppX package list for WIMWitch-tNG.

.DESCRIPTION
    This PowerShell data file contains a comprehensive list of AppX (Modern/UWP) packages
    that can be safely removed from Windows 11 23H2 installation images during customization.

    The list includes consumer-oriented applications and features that are not essential for
    enterprise or managed environments:
    - Consumer entertainment apps (games, music, video)
    - Microsoft Store promotional content
    - Consumer-focused utilities and helper apps
    - Bloatware and pre-installed promotional software

    EXCLUDED from this list (intentionally NOT removable):
    - Core Windows components and system dependencies
    - Security and authentication components
    - Windows Update and servicing components
    - Essential runtime libraries (VCLibs, .NET Native, UI.Xaml)
    - Microsoft Edge browser and WebView2

.NOTES
    File: appxWin11_23H2.psd1
    Version: 1.0
    Author: Eden Nelson
    Target OS: Windows 11 23H2 (October 2023 Update)
    Last Updated: See file modification date

    Package Naming Convention:
        PackageFamilyName_Version_Architecture_~_PublisherID
        Example: Microsoft.WindowsCalculator_2020.2103.8.0_neutral_~_8wekyb3d8bbwe

    Architectures:
        - x64: 64-bit Intel/AMD processors
        - arm64: 64-bit ARM processors
        - neutral: Platform-independent packages

    Publisher IDs:
        - 8wekyb3d8bbwe: Microsoft Corporation
        - yxz26nhyzhsrt: Third-party publishers (e.g., Clipchamp)

.MAINTENANCE
    To update this list:
    1. Deploy a clean Windows 11 23H2 image
    2. Run: Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
    3. Identify new consumer packages safe for removal
    4. Add full PackageName to the Packages array
    5. Test removal on reference systems before production use
    6. Update version number and Last Updated date

    Testing Checklist:
    - Verify Windows Update functionality
    - Confirm Microsoft Store operation (if retained)
    - Test core Windows features (Settings, Search, Notifications)
    - Validate Widgets and Snap Layouts functionality
    - Check Event Viewer for system errors

.COMPATIBILITY
    This list is specific to Windows 11 23H2. Do not use for:
    - Windows 11 22H2 or earlier (package versions differ)
    - Windows 11 24H2 or later (use appropriate version-specific file)
    - Windows 10 (different package set - use appxWin10_*.psd1 files)
    - Windows Server editions (minimal AppX packages)

.LINK
    https://github.com/alaurie/WimWitchFK
#>

@{
    Packages = @(
        'Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt',
        'Microsoft.549981C3F5F10_3.2204.14815.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.BingNews_4.2.27001.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.BingWeather_4.53.33420.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.DesktopAppInstaller_2022.310.2333.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.GamingApp_2021.427.138.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.GetHelp_10.2201.421.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Getstarted_2021.2204.1.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.HEIFImageExtension_1.0.43012.0_x64__8wekyb3d8bbwe',
        'Microsoft.HEVCVideoExtension_1.0.50361.0_x64__8wekyb3d8bbwe',
        'Microsoft.MicrosoftOfficeHub_18.2204.1141.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MicrosoftSolitaireCollection_4.12.3171.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MicrosoftStickyNotes_4.2.2.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Paint_11.2201.22.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.People_2020.901.1724.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.PowerAutomateDesktop_10.0.3735.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.RawImageExtension_2.1.30391.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.ScreenSketch_2022.2201.12.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.SecHealthUI_1000.22621.1.0_x64__8wekyb3d8bbwe',
        'Microsoft.StorePurchaseApp_12008.1001.113.0_neutral_~_8wekyb3d8bbwe'
    )
}

# SIG # Begin signature block
# MIIfCAYJKoZIhvcNAQcCoIIe+TCCHvUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqnKht4gcyme4nCCVJD6YXU7S
# jIigghk5MIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUXY4Od3oxzdOk03rEU+Tm1ehM
# pnMwDQYJKoZIhvcNAQEBBQAEggEAT52bj7/DRjeI+NtM12QLtgbOBrIPhIpD8y+b
# mJv4QffQmfexUuMSr2xhRrtjdepdLf82pJKM9KuoTB/dwZWaOQ+Few8AEklM5Ik6
# jklqg/JweWX3X98a8/raa2w9cuo/hfLd0VILjMZK5vCPaP/XJTOruIbWxpnle3FL
# qdeyF0ltUrwqIa/LY9qJznm0D4J2WX3rxWrOC19ZLnT+tnda3wRgmaDUVHzFallv
# +zADcr8UGqEqQScnKwb1dDi/0rDkZ3djkFXP85JdqTveEwZRIiznmYfxqBXqA8FI
# JclxvpgQv3fsG8fWmJT6XJq4/l8JvC8+w8dOKiJfFvVFo2w/YaGCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDAxNTQ0M1owPwYJKoZIhvcNAQkEMTIEMHymZCut8sSZG5B5kKL3cOMcEPpoV7pF
# lXqj2B+pe2QksEkavMMCVaDT7xh7NcI8EzANBgkqhkiG9w0BAQEFAASCAgBqlt7k
# G0Fb+xTqNi1uJ5bPB6CGFaRYwjFtLsHeyGaT3PXHBlA5jUjmeDFNiJLU3Pqbz86U
# K/Z6uIrvT/2v1Ab0H3OzSwIx9/XGv0NhPRRjmWDaRdSQoztBZhteO09PKEY3+tcX
# 9DtR/Jo5hirRKK9QiH5LATtmofKxIAjuDQQE/nhpO976iJD75Ing4WCrJunq2Xrp
# L/ScTmgfrftROdHZ0K+HTbFczuaycFRn8hTXgAz6SioZLBCQBHjvJlf393FemIte
# dgG+7ODkgDYqHazPpQDqaioBch/LGjy0hfAoxVBv6SqdOeeu2NavRoPqQvss/Kis
# eiNeEGN33rNfwF4mkTI1sYuNJcMwhGQboSfxn6lKNlOdUgE7gEpz2iwMj+GOUOk3
# MBjb34/a8d1smCnkUcJUK5+YkoNrcZGnXzT5pcVla/lNJRADR3nCf/tnae8Yjp7S
# /XXwAgJnNTcBZFyhnS5GkR0bp58VhIhYaie7dtd8EpNyebg256dhpAhrCtYYSJKM
# cn9htGtcxB8txOaen3UEGXA+TL978vNYCVNnEcvjHuO6ZEL93qlq5fxTH0t+hVkk
# BKKKkOYqfztpTYannq7Eg8HvzGtHHvbXlRJJB859i0ADEuieJH9o7qyXoRkbhJuk
# NeTOmp6r+z4AWAJKIzVPy81IEb4qgr6M/8sDfg==
# SIG # End signature block
