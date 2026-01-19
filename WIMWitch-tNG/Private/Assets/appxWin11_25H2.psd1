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

