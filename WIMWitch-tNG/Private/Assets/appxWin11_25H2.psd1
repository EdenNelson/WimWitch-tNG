@{
    # Windows 11 25H2 Safe-to-Remove AppX Packages
    # Version: 1.0
    # Last Updated: 2026-01-12
    # Compatibility: Windows 11 25H2 (November 2024 Update and later)
    #
    # This list contains consumer bloatware packages that are safe to remove.
    # All core runtime dependencies (WindowsAppRuntime, VCLibs, .NET Native, UI.Xaml)
    # and system-critical components are EXCLUDED.
    #
    # Package Selection Criteria:
    # - Confirmed safe in Windows 10 22H2, Windows 11 23H2, and Windows 11 24H2
    # - Non-essential consumer applications
    # - No system dependencies on these packages
    # - Does NOT include security, authentication, or core UI components

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
