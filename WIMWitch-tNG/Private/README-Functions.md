# Function Organization Guide

## WIMWitch-tNG Private Functions Architecture

This document describes the modularized organization of WIMWitch-tNG private functions following the modularization completed on 2026-01-29.

---

## Overview

The original monolithic file `WWFunctions.ps1` (9,683 lines, 105 functions) has been refactored into 16 logical categories under `Private/Functions/`. This modularization improves:

- **Maintainability:** Individual files are 50–300 lines; easier to reason about
- **Collaboration:** Different developers can work on different categories without merge conflicts
- **Navigation:** IDE jumps directly to function file rather than scanning 9,683-line file
- **Testing:** Individual function files can be unit-tested in isolation
- **Performance:** Module loader can conditionally import only needed categories (future optimization)

---

## Directory Structure

```text
WIMWitch-tNG/Private/
├── Functions/
│   ├── Administrative/          # Privilege checks, prerequisite validation (5 functions)
│   ├── AppX/                    # AppX package removal workflows (3 functions)
│   ├── Autopilot/               # Autopilot profile handling (1 function)
│   ├── BootWIM/                 # Boot WIM updates, WinRE modifications (2 functions)
│   ├── Configuration/           # Config file I/O, XML/JSON conversion (4 functions)
│   ├── ConfigMgr/               # SCCM/ConfigMgr image package operations (13 functions)
│   ├── Drivers/                 # Driver installation, injection, discovery (3 functions)
│   ├── DotNetOneDrive/          # .NET detection/installation, OneDrive deployment (5 functions)
│   ├── ISO/                     # ISO building, media staging, validation (6 functions)
│   ├── LanguagePacksFOD/        # Language packs, Features on Demand installation (11 functions)
│   ├── Logging/                 # Log handling, verbose output, notifications (4 functions)
│   ├── Registry/                # Registry file installation, Start Layout, Assoc configs (6 functions)
│   ├── UI/                      # WPF form variable management, form state (12 functions)
│   ├── Updates/                 # Windows Update management, patch sourcing (13 functions)
│   ├── Utilities/               # Generic helpers, validation, main execution flow (13 functions)
│   └── WIMOperations/           # Mount management, WIM info queries (4 functions)
├── Assets/
│   ├── appxWin10_22H2.psd1
│   ├── appxWin11_23H2.psd1
│   ├── appxWin11_24H2.psd1
│   └── appxWin11_25H2.psd1
└── README-Functions.md          # This file
```

**Total Functions:** 105 across 16 categories
**Load Order:** See [Module Loader Load Order](#module-loader-load-order) below

---

## Category Descriptions

### 1. UI — Form & UI Controls (12 functions)

**File:** `Functions/UI/`

Manages WPF form elements, form state, and user interaction workflows.

| Function | Purpose |
| --- | --- |
| `Get-FormVariables` | Extract form control values and build hash table |
| `Reset-MISCheckBox` | Reset checkbox states in Micro-Infrastructure Selection tab |
| `Show-ClosingText` | Display closing/completion messages to user |
| `Show-OpeningText` | Display welcome/opening messages to user |
| `Get-WWAutopilotProfile` | Retrieve Autopilot profile metadata from JSON |
| `Select-Config` | Prompt user to select existing configuration file |
| `Save-Configuration` | Persist form state to configuration file |
| `Get-Configuration` | Load configuration from file and populate form |
| `Invoke-RunConfigFile` | Execute deferred operations from loaded configuration |
| `Suspend-MakeItSo` | Pause execution and prompt user for confirmation |
| `Start-Script` | Initialize script execution and set up logging |
| `Select-TargetDir` | Prompt user to select target/output directory |

### 2. Administrative — Admin & Validation (5 functions)

**File:** `Functions/Administrative/`

Privilege checks, OS prerequisites, and architecture validation.

| Function | Purpose |
| --- | --- |
| `Test-Admin` | Check if script is running with administrator privilege |
| `Invoke-ArchitectureCheck` | Validate system architecture (x64, ARM64) |
| `Invoke-2XXXPreReq` | Validate OS prerequisites for Windows 2022/2025 |
| `Invoke-OSDCheck` | Check for OSD module/tools availability |
| `Invoke-DadJoke` | Display humorous messages (Easter egg) |

### 3. Configuration — Configuration Management (4 functions)

**File:** `Functions/Configuration/`

Config file I/O, format conversion, and JSON/XML parsing helpers.

| Function | Purpose |
| --- | --- |
| `Convert-ConfigMgrXmlToPsd1` | Convert ConfigMgr XML manifests to PowerShell data files |
| `Invoke-ParseJSON` | Parse JSON content and return hashtable |
| `Select-JSONFile` | Prompt user to select JSON file |
| `Select-NewJSONDir` | Prompt user to select directory for new JSON |

### 4. Logging — Logging & Output (4 functions)

**File:** `Functions/Logging/`

Structured logging, verbose output, and user notifications.

| Function | Purpose |
| --- | --- |
| `Update-Log` | Write log entries to file with timestamp/severity |
| `Set-Logging` | Configure logging parameters (level, path, rotation) |
| `Invoke-TextNotification` | Display on-screen or toast notifications |
| `Select-ImportOtherPath` | Prompt user to select alternate import source path |

### 5. WIMOperations — WIM Operations (4 functions)

**File:** `Functions/WIMOperations/`

WIM mounting, info queries, and version management.

| Function | Purpose |
| --- | --- |
| `Select-MountDir` | Prompt user to select WIM mount directory |
| `Select-SourceWIM` | Prompt user to select source WIM file |
| `Import-WimInfo` | Load WIM metadata (indexes, editions, versions) |
| `Get-ImageInfo` | Retrieve WIM image information via DISM |

### 6. Drivers — Driver Management (3 functions)

**File:** `Functions/Drivers/`

Driver installation, injection into WIM, and source discovery.

| Function | Purpose |
| --- | --- |
| `Install-Driver` | Apply driver files to mounted WIM |
| `Start-DriverInjection` | Orchestrate driver installation workflow |
| `Select-DriverSource` | Prompt user to select driver source directory |

### 7. Updates — Windows Update Management (13 functions)

**File:** `Functions/Updates/`

LCU (Latest Cumulative Update) and servicing stack update sourcing, deployment, and supersedence tracking.

| Function | Purpose |
| --- | --- |
| `Get-OSDBInstallation` | Check if OSD Builder is installed |
| `Get-OSDSUSInstallation` | Check if OSD SUS (Servicing Update Source) is installed |
| `Get-OSDBCurrentVer` | Retrieve current OSD Builder version |
| `Get-OSDSUSCurrentVer` | Retrieve current OSD SUS version |
| `Update-OSDB` | Download latest OSD Builder updates |
| `Update-OSDSUS` | Download latest OSD SUS updates |
| `Compare-OSDBuilderVer` | Compare installed vs. available OSD Builder versions |
| `Compare-OSDSUSVer` | Compare installed vs. available OSD SUS versions |
| `Test-Superceded` | Check if update is superseded by newer version |
| `Get-WindowsPatches` | Query available Windows patches from WSUS or Microsoft |
| `Update-PatchSource` | Refresh local patch cache |
| `Deploy-LCU` | Apply Latest Cumulative Update to mounted WIM |
| `Deploy-Updates` | Deploy multiple updates to mounted WIM |

### 8. AppX — AppX Package Management (3 functions)

**File:** `Functions/AppX/`

AppX package removal and bloatware cleanup.

| Function | Purpose |
| --- | --- |
| `Select-Appx` | Prompt user to select AppX packages to remove |
| `Remove-Appx` | Remove selected AppX packages from mounted WIM |
| `Remove-OSIndex` | Remove provisioned appx from specific OS index |

### 9. Autopilot — Windows Autopilot (1 function)

**File:** `Functions/Autopilot/`

Autopilot profile import and deployment.

| Function | Purpose |
| --- | --- |
| `Update-Autopilot` | Import and apply Autopilot profile to image |

### 10. ISO — ISO & Media Creation (6 functions)

**File:** `Functions/ISO/`

ISO building, bootable media creation, and binary validation.

| Function | Purpose |
| --- | --- |
| `Import-ISO` | Mount and extract ISO media |
| `Select-ISO` | Prompt user to select ISO file |
| `Copy-StageIsoMedia` | Stage ISO media files for customization |
| `New-WindowsISO` | Create bootable ISO from staged media |
| `Select-ISODirectory` | Prompt user to select ISO output directory |
| `Test-IsoBinariesExist` | Verify OSCDIMG.EXE and required tools are present |

### 11. DotNetOneDrive — .NET & OneDrive Deployment (5 functions)

**File:** `Functions/DotNetOneDrive/`

.NET Framework detection/installation and OneDrive deployment.

| Function | Purpose |
| --- | --- |
| `Add-DotNet` | Install .NET Framework components to WIM |
| `Test-DotNetExists` | Check if .NET Framework is installed |
| `Get-OneDrive` | Retrieve OneDrive installer/configuration |
| `Copy-OneDrive` | Copy OneDrive (x86) to staged media |
| `Copy-OneDrivex64` | Copy OneDrive (x64) to staged media |

### 12. LanguagePacksFOD — Language Packs & Features on Demand (11 functions)

**File:** `Functions/LanguagePacksFOD/`

Language pack installation, Local Experience Packs, and Windows Features on Demand.

| Function | Purpose |
| --- | --- |
| `Select-LPFODCriteria` | Prompt user to select language/region criteria |
| `Select-LanguagePacks` | Prompt user to select language packs |
| `Select-LocalExperiencePack` | Prompt user to select Local Experience Pack |
| `Select-FeaturesOnDemand` | Prompt user to select Features on Demand |
| `Install-LanguagePacks` | Apply language packs to mounted WIM |
| `Install-LocalExperiencePack` | Apply Local Experience Pack to WIM |
| `Install-FeaturesOnDemand` | Apply Windows Features on Demand to WIM |
| `Import-LanguagePacks` | Import language pack source files |
| `Import-LocalExperiencePack` | Import Local Experience Pack source files |
| `Import-FeatureOnDemand` | Import Features on Demand source files |
| `Update-ImportVersionCB` | Update version checkbox in import UI |

### 13. ConfigMgr — ConfigMgr Integration (13 functions)

**File:** `Functions/ConfigMgr/`

Microsoft Endpoint Configuration Manager (SCCM) image package operations and integration.

| Function | Purpose |
| --- | --- |
| `Select-DistributionPoints` | Prompt user to select SCCM distribution points |
| `New-CMImagePackage` | Create new image package in ConfigMgr |
| `Enable-ConfigMgrOptions` | Enable ConfigMgr-specific customization options |
| `Update-CMImage` | Update ConfigMgr image package |
| `Invoke-UpdateTabOptions` | Refresh ConfigMgr options in UI |
| `Invoke-MSUpdateItemDownload` | Download Microsoft Updates from WSUS/ConfigMgr |
| `Invoke-MEMCMUpdatecatalog` | Query Microsoft Update catalog |
| `Invoke-MEMCMUpdateSupersedence` | Check update supersedence in ConfigMgr |
| `Invoke-MISUpdates` | Orchestrate ConfigMgr update import |
| `Set-ImageProperties` | Set ConfigMgr package metadata |
| `Find-ConfigManager` | Detect installed ConfigMgr client/tools |
| `Set-ConfigMgr` | Configure ConfigMgr connection parameters |
| `Import-CMModule` | Load ConfigMgr PowerShell module |

### 14. Registry — Registry & Customization (6 functions)

**File:** `Functions/Registry/`

Registry customization, start menu layout, and default app associations.

| Function | Purpose |
| --- | --- |
| `Install-StartLayout` | Apply custom start menu layout to WIM |
| `Install-DefaultApplicationAssociations` | Apply default app associations to WIM |
| `Select-DefaultApplicationAssociations` | Prompt user to select app association files |
| `Select-StartMenu` | Prompt user to select start menu layout |
| `Select-RegFiles` | Prompt user to select registry customization files |
| `Install-RegistryFiles` | Apply registry customization files to WIM |

### 15. BootWIM — Boot WIM & WinRE (2 functions)

**File:** `Functions/BootWIM/`

Boot image updates and WinRE (Windows Recovery Environment) modifications.

| Function | Purpose |
| --- | --- |
| `Update-BootWIM` | Apply customizations to boot WIM |
| `Update-WinReWim` | Apply customizations to WinRE WIM |

### 16. Utilities — Utility & Orchestration (13 functions)

**File:** `Functions/Utilities/`

Generic helpers, validation, directory selection, and main execution orchestration.

| Function | Purpose |
| --- | --- |
| `Get-WinVersionNumber` | Retrieve Windows version/build number |
| `Get-WindowsType` | Determine Windows edition (Pro, Enterprise, etc.) |
| `Test-Name` | Validate naming convention and format |
| `Rename-Name` | Rename or sanitize path/file names |
| `Test-MountPath` | Validate WIM mount point path |
| `Test-WorkingDirectory` | Validate working directory path |
| `Select-WorkingDirectory` | Prompt user to select working directory |
| `Repair-MountPoint` | Cleanup or repair failed WIM mounts |
| `Set-Version` | Set version metadata in image |
| `Backup-WIMWitch` | Backup current configuration/state |
| `Install-WimWitchUpgrade` | Install updates to WIMWitch itself |
| `Copy-UpgradePackage` | Copy upgrade media to staging location |
| `Invoke-MakeItSo` | **Main orchestration function** — executes entire workflow |

---

## Module Loader Load Order

Functions are loaded in the following order by [WIMWitch-tNG.psm1](../WIMWitch-tNG.psm1). This order respects dependency chains and ensures all functions are available when called.

1. UI (12 functions) — Form state, user interaction
2. Administrative (5 functions) — Privilege & prerequisite checks
3. Configuration (4 functions) — Config file I/O
4. Logging (4 functions) — Logging setup
5. WIMOperations (4 functions) — WIM mounting, querying
6. Drivers (3 functions) — Driver injection
7. Updates (13 functions) — Patch sourcing & deployment
8. AppX (3 functions) — Package removal
9. Autopilot (1 function) — Autopilot profiles
10. ISO (6 functions) — Media creation
11. DotNetOneDrive (5 functions) — .NET & OneDrive
12. LanguagePacksFOD (11 functions) — Language packs & FOD
13. ConfigMgr (13 functions) — SCCM integration
14. Registry (6 functions) — Registry customization
15. BootWIM (2 functions) — Boot image updates
16. Utilities (13 functions) — Helpers & orchestration

**Dependency Notes:**

- Categories 1–4 are prerequisites for all downstream operations
- Categories 5–8 handle core image modifications
- Categories 9–12 handle optional enhancements
- Category 13 provides enterprise integration
- Category 14 handles user customization
- Category 15 finalizes boot/recovery images
- Category 16 provides utilities and the main entry point (`Invoke-MakeItSo`)

---

## Contributing Guide

### Adding a New Function

When adding a new private function:

1. **Determine Category:** Identify which of the 16 categories best fits the function's purpose
2. **Create File:** Create `Functions/<Category>/<FunctionName>.ps1`
3. **Follow Standards:** Adhere to [STANDARDS_POWERSHELL.md](../../../STANDARDS_POWERSHELL.md)
4. **Include Help Block:** Use PowerShell comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, etc.)
5. **Update Loader:** Update load order in [WIMWitch-tNG.psm1](../WIMWitch-tNG.psm1) if new category is added
6. **Update This Document:** Add function to appropriate section and alphabetical index

### Function File Naming

- **Pattern:** `<Verb>-<Noun>.ps1`
- **Example:** `Install-LanguagePacks.ps1`
- **Standard Verbs:** Follow [PowerShell Approved Verbs](https://learn.microsoft.com/en-us/powershell/developer/cmdlet/approved-verbs-for-powershell-commands)

### Best Practices

1. **Single Responsibility:** Each function should do one thing well
2. **Error Handling:** Use `-ErrorAction` and try-catch blocks appropriately
3. **Help Documentation:** Every function must include complete comment-based help
4. **Logging:** Use `Update-Log` function for all messages
5. **Dependencies:** Minimize cross-category dependencies; prefer lower-category functions
6. **Testing:** Test function in isolation before integration

---

## Performance & Future Optimization

### Current State

- Module load time: **< 100ms** (negligible overhead from multiple dot-sources)
- Function availability: All 105 functions loaded immediately

### Future Optimization Opportunities

1. **Lazy Loading:** Load category modules only when first called (opt-in per category)
2. **Category Aliases:** Create category-specific module manifests for selective loading
3. **Parallel Loading:** Load non-dependent categories in parallel
4. **Compression:** Archive infrequently-used category files

---

## Related Documentation

- [STANDARDS_POWERSHELL.md](../../../STANDARDS_POWERSHELL.md) — PowerShell coding standards
- [WIMWitch-tNG.psm1](../WIMWitch-tNG.psm1) — Module manifest and loader
- [WIMWitch-tNG.psd1](../WIMWitch-tNG.psd1) — Module definition file
- [PROJECT_CONTEXT.md](../../../PROJECT_CONTEXT.md) — Project overview

---

**Last Updated:** 2026-01-29
**Modularization Status:** ✅ Complete (Stage 1)
**Total Functions:** 105
**Total Categories:** 16
