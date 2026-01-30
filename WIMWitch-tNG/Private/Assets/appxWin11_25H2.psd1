<#
.SYNOPSIS
    Windows 11 25H2 removable AppX package list for WIMWitch-tNG.

.DESCRIPTION
    This PowerShell data file contains a comprehensive list of AppX (Modern/UWP) packages
    that can be safely removed from Windows 11 25H2 installation images during customization.

    The list includes consumer-oriented applications and features that are not essential for
    enterprise or managed environments:
    - Consumer entertainment apps (games, music, video)
    - Microsoft Store promotional content
    - Consumer-focused utilities and helper apps
    - Bloatware and pre-installed promotional software
    - New Windows 11 25H2 consumer features

    EXCLUDED from this list (intentionally NOT removable):
    - Core Windows components and system dependencies (WindowsAppRuntime)
    - Security and authentication components
    - Windows Update and servicing components
    - Essential runtime libraries (VCLibs, .NET Native, UI.Xaml)
    - Microsoft Edge browser and WebView2
    - AI and Copilot core components

    Package Selection Criteria:
    - Confirmed safe across Windows 10 22H2, Windows 11 23H2, and Windows 11 24H2
    - Non-essential consumer applications only
    - No system dependencies on these packages
    - Does NOT include security, authentication, or core UI components

.NOTES
    File: appxWin11_25H2.psd1
    Version: 1.0
    Author: Eden Nelson
    Target OS: Windows 11 25H2 (November 2024 Update and later)
    Last Updated: 2026-01-12

    Package Naming Convention:
        PackageFamilyName_Version_Architecture_~_PublisherID
        Example: Clipchamp.Clipchamp_4.4.10720.0_arm64__yxz26nhyzhsrt

    Architectures:
        - arm64: 64-bit ARM processors (primary architecture in this list)
        - x64: 64-bit Intel/AMD processors
        - neutral: Platform-independent packages

    Publisher IDs:
        - 8wekyb3d8bbwe: Microsoft Corporation
        - yxz26nhyzhsrt: Third-party publishers (e.g., Clipchamp)

    25H2-Specific Notes:
        - Enhanced ARM64 support with native packages
        - Updated AI and productivity features
        - Refined consumer application set

.MAINTENANCE
    To update this list:
    1. Deploy a clean Windows 11 25H2 image
    2. Run: Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
    3. Identify new consumer packages safe for removal
    4. Cross-reference with Windows 10 22H2, 11 23H2, and 11 24H2 lists for consistency
    5. Verify no system dependencies exist
    6. Add full PackageName to the Packages array
    7. Test removal on reference systems (both x64 and ARM64 if applicable)
    8. Update version number and Last Updated date

    Testing Checklist:
    - Verify Windows Update functionality
    - Confirm Microsoft Store operation (if retained)
    - Test core Windows features (Settings, Search, Notifications)
    - Validate Widgets, Snap Layouts, and AI features
    - Test Copilot functionality (if retained)
    - Verify ARM64-specific functionality on ARM devices
    - Check Event Viewer for system errors
    - Test on both ARM64 and x64 architectures

.COMPATIBILITY
    This list is specific to Windows 11 25H2. Do not use for:
    - Windows 11 24H2 or earlier (package versions differ)
    - Future Windows 11 versions (use appropriate version-specific file)
    - Windows 10 (different package set - use appxWin10_*.psd1 files)
    - Windows Server editions (minimal AppX packages)

    Architecture Notes:
    - This list primarily targets ARM64 packages
    - May include x64 equivalents for cross-platform consistency
    - Verify architecture compatibility before deployment

.LINK
    https://github.com/alaurie/WimWitchFK
#>

@{
    Packages = @(
        'Clipchamp.Clipchamp_4.4.10720.0_arm64__yxz26nhyzhsrt',
        'Microsoft.BingNews_4.55.62231.0_arm64__8wekyb3d8bbwe',
        'Microsoft.BingWeather_4.54.63029.0_arm64__8wekyb3d8bbwe',
        'Microsoft.BingSearch_1.1.40.0_arm64__8wekyb3d8bbwe',
        'Microsoft.DesktopAppInstaller_1.27.349.0_arm64__8wekyb3d8bbwe',
        'Microsoft.GetHelp_10.2409.33293.0_arm64__8wekyb3d8bbwe',
        'Microsoft.HEIFImageExtension_1.2.28.0_arm64__8wekyb3d8bbwe',
        'Microsoft.HEVCVideoExtension_2.4.39.0_arm64__8wekyb3d8bbwe',
        'Microsoft.MicrosoftOfficeHub_19.2601.39061.0_arm64__8wekyb3d8bbwe',
        'Microsoft.MicrosoftSolitaireCollection_4.24.12220.0_arm64__8wekyb3d8bbwe',
        'Microsoft.MicrosoftStickyNotes_4.0.6105.0_arm64__8wekyb3d8bbwe',
        'Microsoft.Paint_11.2511.291.0_arm64__8wekyb3d8bbwe',
        'Microsoft.RawImageExtension_2.5.7.0_arm64__8wekyb3d8bbwe',
        'Microsoft.ScreenSketch_11.2510.31.0_arm64__8wekyb3d8bbwe',
        'Microsoft.StorePurchaseApp_22511.1401.2.0_arm64__8wekyb3d8bbwe',
        'Microsoft.Todos_0.148.3611.0_arm64__8wekyb3d8bbwe',
        'Microsoft.VP9VideoExtensions_1.2.12.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WebMediaExtensions_2.1.8.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WebpImageExtension_1.2.14.0_arm64__8wekyb3d8bbwe',
        'Microsoft.Windows.Photos_2025.11120.5001.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsAlarms_11.2510.4.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsCalculator_11.2508.4.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsCamera_2025.2510.2.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsFeedbackHub_1.2512.16303.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsNotepad_11.2508.38.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsSoundRecorder_1.1.47.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsStore_22511.1401.5.0_arm64__8wekyb3d8bbwe',
        'Microsoft.WindowsTerminal_1.23.13503.0_arm64__8wekyb3d8bbwe',
        'Microsoft.Xbox.TCUI_1.24.10001.0_x64__8wekyb3d8bbwe',
        'Microsoft.XboxGamingOverlay_7.325.11061.0_arm64__8wekyb3d8bbwe',
        'Microsoft.XboxIdentityProvider_12.130.16001.0_arm64__8wekyb3d8bbwe',
        'Microsoft.XboxSpeechToTextOverlay_1.111.30001.0_arm64__8wekyb3d8bbwe',
        'Microsoft.YourPhone_0.25112.36.0_arm64__cw5n1h2txyewy',
        'Microsoft.ZuneMusic_11.2511.5.0_arm64__8wekyb3d8bbwe',
        'MicrosoftCorporationII.QuickAssist_2.0.35.0_arm64__8wekyb3d8bbwe',
        'MicrosoftWindows.Client.WebExperience_525.31002.150.0_arm64__cw5n1h2txyewy'
    )

    # Packages EXCLUDED from removal (High Risk / System-Critical):
    # ============================================================
    # These are NOT included in the safe removal list and should NEVER be removed
    # without extensive testing and understanding of their function.
    #
    # Core Runtime Dependencies:
    #   - Microsoft.WindowsAppRuntime.*
    #   - Microsoft.NET.Native.Runtime.*
    #   - Microsoft.NET.Native.Framework.*
    #   - Microsoft.VCLibs.140.00*
    #   - Microsoft.UI.Xaml.*
    #   - Microsoft.WidgetsPlatformRuntime
    #
    # Security & Authentication:
    #   - Microsoft.AAD.BrokerPlugin
    #   - Microsoft.AccountsControl
    #   - Microsoft.BioEnrollment
    #   - Microsoft.CredDialogHost
    #   - Microsoft.LockApp
    #   - Microsoft.SecHealthUI
    #   - Microsoft.Windows.ParentalControls
    #   - Microsoft.Windows.SecureAssessmentBrowser
    #
    # System Core Components:
    #   - Microsoft.Windows.ShellExperienceHost
    #   - Microsoft.Windows.StartMenuExperienceHost
    #   - Microsoft.Windows.CloudExperienceHost
    #   - Microsoft.Windows.ContentDeliveryManager
    #   - MicrosoftWindows.Client.Core
    #   - MicrosoftWindows.Client.CBS
    #   - MicrosoftWindows.Client.OOBE
    #
    # New 25H2 Applications (System-Integrated):
    #   - Microsoft.Windows.DevHome
    #   - Microsoft.ApplicationCompatibilityEnhancements
    #   - Microsoft.AV1VideoExtension
    #   - Microsoft.AVCEncoderVideoExtension
    #   - Microsoft.MPEG2VideoExtension
    #   - Microsoft.MicrosoftEdge.Stable
    #   - Microsoft.OutlookForWindows
    #   - MSTeams
    #
    # Undocumented/Proprietary (High Risk):
    #   - MicrosoftWindows.Voiess_*
    #   - MicrosoftWindows.Speion_*
    #   - MicrosoftWindows.Livtop_*
    #   - MicrosoftWindows.Filons_*
    #   - MicrosoftWindows.Tasbar_*
    #   - Any *_arm64__cw5n1h2txyewy packages
}

# SIG # Begin signature block
# MIIfCAYJKoZIhvcNAQcCoIIe+TCCHvUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUfb1vS3R4cnu1wZWop2XlyFyA
# /2Kgghk5MIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c9MfjPzANBgkqhkiG9w0B
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
# DAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUSU08S5kw7cpxhJaatyhdU3Mv
# e4UwDQYJKoZIhvcNAQEBBQAEggEAmxQlL2yScHirNBoyL9Je/5RBXMRgl8RSDP+H
# ihDK7tmUGKJvMXtr2+zAJUowQRcFeutaTdYQ8hxAO+dk1w8jBHSZ9qdKdZuVeC55
# 1znDlLN7tmWCupTzfm987/K1IDVXR/tqEoUH1Xmv6d4ns0WPW+f4KmC3M1oJ8dqd
# GIrapWHc586J5EmOsB2wkZ2S9A9E+jsuSob8SdSGXv4q0AXInv7Wyuh4Lrv321Qv
# q/gFFv1d8b/EPVeAS2BV7UQxFjiFFoSCNDFUHxnaQSk6hFoQEOqRoZfHqmUbVwFw
# b599Ht7HlJeSPTwaf2SISzXVRArmb/psbbiLDcIVy0o3YfGNKKGCAyMwggMfBgkq
# hkiG9w0BCQYxggMQMIIDDAIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKB5
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDAxNTQ0MFowPwYJKoZIhvcNAQkEMTIEMOGJSAx5xtYymfxu1tIqhwU4RMzz9c15
# lVzKDkLIP6RhjHzoUgF02tpAz+OQdFhX6jANBgkqhkiG9w0BAQEFAASCAgCS5ELp
# pcaWOe+KkA5SkbAY2Cz0TFWaKfc9028IhHez1udTymSMNyoSDNpO7BrxZLeY6IJT
# o8RYvkhLu3v6YU4wb1dsbZUjml6O6OP+Vw145wCfLilT+u0D9KlIKUXVIF9DlzTx
# KmBYBdUa3/qRlLYA/0gtVYnA2H0qd5cLo4OrrcFd0NYzkMp109sBpWSGSbZHqwLb
# +/zNF/ivKLcRV+VaHuxB+eUb3tz9J2Oj9+HxIxkhCLGNePM3AFDVUcyE3OUPHlXD
# gIh5DizEfnFvxOakhADXDxcWIUgNdGdAq+Mma3bbHpDTAzga4hLtNvL2Z9+a0f1K
# 8KOcTi4tgki1pkFLKYjv6WNQjx2QFTA/T3fbtH7YW1vJKuBtxj/2cQjQsok8oNSc
# apRgWcX2BhubcdOtbogvzwLZNVf8C5UictuabaQyzskKuKFtPgF2GWud1H9eL9nR
# kAjbL1nal9ZwmgSocaP3oL7fEzCKSZD/MZIsUHdjtkGrVlekKqRmt6T0Nm/TPd1H
# Y3Ev5n1fLRtnh9VulLZtcNZ2ScSsh4Q7dXlRN1vEcw+Lg//kA/MbdYXD14weZMth
# A5NrTDdTLb0Fl1RnMfkA9oiEUw2X3v792mTJIYs3xG0QpsjCX3WHmbWHqrhaHlME
# yJa+IMX6D5FI+/F6YIW7LaO9WkvRYEmEoKrw+g==
# SIG # End signature block
