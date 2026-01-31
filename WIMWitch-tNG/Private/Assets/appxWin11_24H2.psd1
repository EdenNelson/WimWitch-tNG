<#
.SYNOPSIS
    Windows 11 24H2 removable AppX package list for WIMWitch-tNG.

.DESCRIPTION
    This PowerShell data file contains a comprehensive list of AppX (Modern/UWP) packages
    that can be safely removed from Windows 11 24H2 installation images during customization.

    The list includes consumer-oriented applications and features that are not essential for
    enterprise or managed environments:
    - Consumer entertainment apps (games, music, video)
    - Microsoft Store promotional content
    - Consumer-focused utilities and helper apps
    - Bloatware and pre-installed promotional software
    - New Windows 11 24H2 consumer features (Dev Home, etc.)

    EXCLUDED from this list (intentionally NOT removable):
    - Core Windows components and system dependencies
    - Security and authentication components
    - Windows Update and servicing components
    - Essential runtime libraries (VCLibs, .NET Native, UI.Xaml)
    - Microsoft Edge browser and WebView2

.NOTES
    File: appxWin11_24H2.psd1
    Version: 1.0
    Author: Eden Nelson
    Target OS: Windows 11 24H2 (October 2024 Update)
    Last Updated: See file modification date

    Package Naming Convention:
        PackageFamilyName_Version_Architecture_~_PublisherID
        Example: Microsoft.Windows.DevHome_0.100.128.0_neutral_~_8wekyb3d8bbwe

    Architectures:
        - x64: 64-bit Intel/AMD processors
        - arm64: 64-bit ARM processors
        - neutral: Platform-independent packages

    Publisher IDs:
        - 8wekyb3d8bbwe: Microsoft Corporation
        - yxz26nhyzhsrt: Third-party publishers (e.g., Clipchamp)

    24H2-Specific Packages:
        - Microsoft.Windows.DevHome: Developer productivity hub
        - Microsoft.BingSearch: Enhanced search integration
        - Additional AI and Copilot components

.MAINTENANCE
    To update this list:
    1. Deploy a clean Windows 11 24H2 image
    2. Run: Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
    3. Identify new consumer packages safe for removal
    4. Add full PackageName to the Packages array
    5. Test removal on reference systems before production use
    6. Update version number and Last Updated date

    Testing Checklist:
    - Verify Windows Update functionality
    - Confirm Microsoft Store operation (if retained)
    - Test core Windows features (Settings, Search, Notifications)
    - Validate Widgets, Snap Layouts, and AI features
    - Test Copilot functionality (if retained)
    - Check Event Viewer for system errors

.COMPATIBILITY
    This list is specific to Windows 11 24H2. Do not use for:
    - Windows 11 23H2 or earlier (package versions differ)
    - Windows 11 25H2 or later (use appropriate version-specific file)
    - Windows 10 (different package set - use appxWin10_*.psd1 files)
    - Windows Server editions (minimal AppX packages)

.LINK
    https://github.com/alaurie/WimWitchFK
#>

@{
    Packages = @(
        'Clipchamp.Clipchamp_3.0.10220.0_neutral_~_yxz26nhyzhsrt',
        'Microsoft.ApplicationCompatibilityEnhancements_1.2401.10.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.AV1VideoExtension_1.1.61781.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.AVCEncoderVideoExtension_1.0.271.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.BingNews_4.1.24002.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.BingSearch_2022.0.79.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.BingWeather_4.53.52892.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.DesktopAppInstaller_2024.112.2235.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.GamingApp_2024.311.2341.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.GetHelp_10.2302.10601.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.HEIFImageExtension_1.0.63001.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.HEVCVideoExtension_2.0.61931.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MicrosoftEdge.Stable_129.0.2792.79_neutral__8wekyb3d8bbwe',
        'Microsoft.MicrosoftOfficeHub_18.2308.1034.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MicrosoftSolitaireCollection_4.19.3190.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MicrosoftStickyNotes_4.6.2.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.MPEG2VideoExtension_1.0.61931.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Paint_11.2302.20.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.PowerAutomateDesktop_11.2401.28.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.RawImageExtension_2.3.171.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.ScreenSketch_2022.2307.52.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.SecHealthUI_1000.26100.1.0_x64__8wekyb3d8bbwe',
        'Microsoft.StorePurchaseApp_22312.1400.6.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Todos_2.104.62421.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.VP9VideoExtensions_1.1.451.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WebMediaExtensions_1.0.62931.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WebpImageExtension_1.0.62681.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Windows.DevHome_0.100.128.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Windows.Photos_24.24010.29003.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsAlarms_2022.2312.2.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsCalculator_2021.2311.0.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsCamera_2022.2312.3.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsFeedbackHub_2024.125.1522.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsNotepad_11.2312.18.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsSoundRecorder_2021.2312.5.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsStore_22401.1400.6.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.WindowsTerminal_3001.18.10301.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.Xbox.TCUI_1.23.28005.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.XboxGamingOverlay_2.624.1111.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.XboxIdentityProvider_12.110.15002.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.XboxSpeechToTextOverlay_1.97.17002.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.YourPhone_1.24012.105.0_neutral_~_8wekyb3d8bbwe',
        'Microsoft.ZuneMusic_11.2312.8.0_neutral_~_8wekyb3d8bbwe',
        'MicrosoftCorporationII.QuickAssist_2024.309.159.0_neutral_~_8wekyb3d8bbwe',
        'MicrosoftWindows.Client.WebExperience_424.1301.270.9_neutral_~_cw5n1h2txyewy',
        'MicrosoftWindows.CrossDevice_1.23101.22.0_neutral_~_cw5n1h2txyewy'
    )
}
