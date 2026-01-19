<#
.SYNOPSIS
    Windows 10 22H2 removable AppX package list for WIMWitch-tNG.

.DESCRIPTION
    This PowerShell data file contains a comprehensive list of AppX (Modern/UWP) packages
    that can be safely removed from Windows 10 22H2 installation images during customization.

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
    File: appxWin10_22H2.psd1
    Version: 1.0
    Author: Eden Nelson
    Target OS: Windows 10 22H2 (October 2022 Update)
    Last Updated: See file modification date

    Package Naming Convention:
        PackageFamilyName_Version_Architecture_~_PublisherID
        Example: Microsoft.WindowsCalculator_2020.2103.8.0_neutral_~_8wekyb3d8bbwe

    Architectures:
        - x64: 64-bit Intel/AMD processors
        - x86: 32-bit Intel/AMD processors
        - arm64: 64-bit ARM processors
        - neutral: Platform-independent packages

    Publisher IDs:
        - 8wekyb3d8bbwe: Microsoft Corporation
        - yxz26nhyzhsrt: Third-party publishers (e.g., Clipchamp)

.MAINTENANCE
    To update this list:
    1. Deploy a clean Windows 10 22H2 image
    2. Run: Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
    3. Identify new consumer packages safe for removal
    4. Add full PackageName to the Packages array
    5. Test removal on reference systems before production use
    6. Update version number and Last Updated date

    Testing Checklist:
    - Verify Windows Update functionality
    - Confirm Microsoft Store operation (if retained)
    - Test core Windows features (Settings, Search, Notifications)
    - Validate no system errors in Event Viewer

.COMPATIBILITY
    This list is specific to Windows 10 22H2. Do not use for:
    - Windows 10 21H2 or earlier (package versions differ)
    - Windows 11 (different package set - use appxWin11_*.psd1 files)
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
        'Microsoft.StorePurchaseApp_12008.1001.113.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Todos_2.54.42772.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.VCLibs.140.00_14.0.30704.0_x64__8wekyb3d8bbwe',
        'Microsoft.VP9VideoExtensions_1.0.50901.0_x64__8wekyb3d8bbwe',
        'Microsoft.WebMediaExtensions_1.0.42192.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WebpImageExtension_1.0.42351.0_x64__8wekyb3d8bbwe',
        'Microsoft.Windows.Photos_21.21030.25003.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsAlarms_2022.2202.24.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsCalculator_2020.2103.8.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsCamera_2022.2201.4.0_neutral_~_8wekyb3d8bbwe',
        'microsoft.windowscommunicationsapps_16005.14326.20544.0_neutral_~_8wekyb3d8bbwe'
    )
}

