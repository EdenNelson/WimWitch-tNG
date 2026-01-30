# WIMWitch-tNG Project Context

**AI Development Guide for WIMWitch-tNG**

_"Make it so." - Captain Jean-Luc Picard_

This document provides comprehensive context for AI-assisted development, maintenance, and updates to the WIMWitch-tNG project.

**Note:** The "tNG" (the Next Generation) naming pays homage to Star Trek: The Next Generation, as envisioned by original author Donna Ryan (TheNotoriousDRR). This theme reflects the project's evolution from the original WIMWitch while honoring its legacy.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Key Components](#key-components)
- [Coding Standards](#coding-standards)
- [Critical Functions](#critical-functions)
- [Common Workflows](#common-workflows)
- [Dependencies](#dependencies)
- [Testing Guidelines](#testing-guidelines)
- [Maintenance Tasks](#maintenance-tasks)

**⚠️ IMPORTANT:** See [CHANGELOG.md](CHANGELOG.md) for complete project history, planned features, and implementation status.

---

## Project Overview

**Name:** WIMWitch-tNG (the Next Generation)
**Type:** PowerShell Module & GUI Application
**Purpose:** Windows installation image (WIM file) customization toolkit
**Original Creator:** Donna Ryan (TheNotoriousDRR)
**Primary Authors:** Alex Laurie, Donna Ryan
**Maintained By:** Eden Nelson
**Version:** 5.0-beta
**Repository:** <https://github.com/alaurie/WimWitchFK>

**Theme:** The "tNG" suffix and Star Trek: The Next Generation references throughout the codebase honor Donna Ryan's original vision. Like the starship Enterprise-D, this tool represents an evolution of its predecessor while maintaining the core mission: to boldly go where no image customization tool has gone before.

**Versioning Strategy:**
- **Current:** 5.0-beta (pre-release, comprehensive documentation)
- **Future:** Date-based versioning (YYYY.M.D format)
  - Example: 2026.1.1 = January 2026, first patch
  - Example: 2026.3.5 = March 2026, fifth patch
  - Benefits: Clear release timing, easier tracking, no semantic versioning confusion

### What It Does

WIMWitch-tNG is a comprehensive toolkit for IT professionals to customize Windows installation images. It provides:

- GUI and automation modes for WIM customization
- Windows Update injection (drivers, cumulative updates)
- AppX package removal (bloatware)
- Language pack and Features on Demand installation
- Microsoft Endpoint Configuration Manager integration
- Autopilot profile deployment
- Bootable ISO creation
- Registry and Start Menu customization

### Target Users

- Enterprise IT administrators
- System deployment engineers
- MDT/SCCM/ConfigMgr administrators
- Windows deployment specialists

### Current State Check (2026-01-19)

- Codebase mirrors upstream WimWitchFK 4.0.1 functionality; primary additions are comprehensive documentation (111 functions with comment-based help).
- Version bumped to 5.0-beta (2026-01-19) to reflect significant documentation milestone.
- Transitioning to date-based versioning: next stable release will use YYYY.M.D format (e.g., 2026.1.1).
- Required modules are not declared in the manifest even though features rely on OSDSUS/OSDUpdate, ConfigMgr, and WindowsAutopilotIntune when enabled.
- Logging remains the legacy `Update-Log` host/file writer; the verbose [SAVE]/[LOAD] messages described in earlier drafts are not present.
- Parameter validation currently excludes the default `'none'` for `Win10Version`/`Win11Version`, which can trigger validation errors; server switches from upstream are not available.

---

## Architecture

### Module Structure

```text
WIMWitch-tNG/
├── WIMWitch-tNG.psd1          # Module manifest (metadata, exports)
├── WIMWitch-tNG.psm1          # Module loader (category-based dot-sources)
├── Public/
│   └── WIMWitch-tNG.ps1       # Main entry point: Invoke-WimWitchTng
└── Private/
    ├── Functions/             # Modularized private functions (16 categories)
    │   ├── UI/                # UI & Form controls (12 functions)
    │   ├── Administrative/    # Admin & validation (5 functions)
    │   ├── Configuration/     # Config management (4 functions)
    │   ├── Logging/           # Logging & output (4 functions)
    │   ├── WIMOperations/     # WIM operations (4 functions)
    │   ├── Drivers/           # Driver management (3 functions)
    │   ├── Updates/           # Update management (13 functions)
    │   ├── AppX/              # AppX management (3 functions)
    │   ├── Autopilot/         # Autopilot (1 function)
    │   ├── ISO/               # ISO & media (6 functions)
    │   ├── DotNetOneDrive/    # .NET & OneDrive (5 functions)
    │   ├── LanguagePacksFOD/  # Language packs & FODs (11 functions)
    │   ├── ConfigMgr/         # ConfigMgr integration (13 functions)
    │   ├── Registry/          # Registry & customization (6 functions)
    │   ├── BootWIM/           # Boot WIM & WinRE (2 functions)
    │   ├── Utilities/         # Utility functions (13 functions)
    │   └── README-Functions.md # Function index & organization guide
    ├── Assets/
    │   ├── appxWin10_22H2.psd1   # Windows 10 AppX removal list
    │   ├── appxWin11_23H2.psd1   # Windows 11 23H2 AppX list
    │   ├── appxWin11_24H2.psd1   # Windows 11 24H2 AppX list
    │   └── appxWin11_25H2.psd1   # Windows 11 25H2 AppX list
    ├── WWFunctions.ps1.deprecated-20260129  # Archive of original monolithic file
    └── README-Functions.md    # Function category index & reference
```

**Status:** ✅ Functions modularized as of 2026-01-29

**Note on Structure:** The 105 private functions were refactored from the monolithic `WWFunctions.ps1` into organized subdirectories for improved maintainability and navigation. Each category is a separate directory containing individual function files. The original monolithic file is archived as `WWFunctions.ps1.deprecated-20260129` for reference. See [README-Functions.md](WIMWitch-tNG/Private/README-Functions.md) for complete function directory and organization details.

### Design Pattern
**Modular PowerShell Module:**
- **Public Functions:** Exported to users (1 function: `Invoke-WimWitchTng`)
- **Private Functions:** Internal implementation (105+ functions in WWFunctions.ps1)
- **Dot-Sourcing:** Module loads all functions at import time
- **WPF GUI:** XAML-based graphical interface embedded in main function
- **Configuration-Driven:** JSON/PSD1 config files for automation

### Execution Modes

1. **Interactive GUI Mode** (Default)
   - Launches WPF application
   - User-driven selections and actions
   - Real-time logging in GUI

2. **Automated Mode** (`-auto` switch)
   - Runs headless using configuration file
   - No GUI displayed
   - Batch/CI/CD friendly

3. **ConfigMgr Integration Mode** (`-CM` parameter)
   - Creates or updates SCCM/ConfigMgr image packages
   - Distributes to distribution points
   - Updates package properties

---

## File Structure

### Critical Files

#### WIMWitch-tNG.psd1
**Purpose:** Module manifest
**Contains:** Metadata, exported functions, required modules
**Key Properties:**
- `ModuleVersion`: Current version
- `FunctionsToExport`: `Invoke-WimWitchTng`
- `AliasesToExport`: `Invoke-WIMWitch-tNG` (backward compatibility)
- `RequiredModules`: OSDSUS, OSDUpdate

#### WIMWitch-tNG.psm1
**Purpose:** Module loader
**Function:** Dot-sources all Public and Private functions
**Pattern:**
```powershell
$public = @(Get-ChildItem -Path 'Public/*.ps1')
$private = @(Get-ChildItem -Path 'Private/*.ps1')
foreach ($import in @($public + $private)) {
    . $import.FullName
}
Export-ModuleMember -Function 'Invoke-WimWitchTng'
```

#### Public/WIMWitch-tNG.ps1
**Purpose:** Main entry point and GUI
**Size:** ~1,240 lines
**Contains:**
- Function signature with 12 parameters
- Embedded XAML for WPF interface (~300 lines)
- Event handlers for all GUI controls
- Main application logic and orchestration

**Parameters:**
- `auto`, `autofile`, `autopath` - Automation mode
- `UpdatePoShModules` - Update dependencies
- `DownloadUpdates` - Enable update downloads
- `Win10Version`, `Win11Version` - OS version targeting
- `CM` - ConfigMgr integration mode
- `demomode` - Skip lengthy operations
- `WorkingPath`, `workdir` - Working directory
- `AutoFixMount` - Automatic mount repair

**Notes:**
- Current ValidateSet values do not include the default `'none'`, which can raise parameter validation errors until corrected.
- Server switches from upstream WimWitchFK are not exposed in this fork.

#### Private/Functions/ (Modularized Function Categories)

**Status:** ✅ REFACTORED (2026-01-29)

**Purpose:** Organized subdirectories containing individual private function files (105 functions total across 16 categories)

**Organization:**

- `Administrative/` - Privilege checks, prerequisite validation (5 functions)
- `AppX/` - AppX package removal workflows (3 functions)
- `Autopilot/` - Windows Autopilot profile handling (1 function)
- `BootWIM/` - Boot image and WinRE updates (2 functions)
- `ConfigMgr/` - SCCM/ConfigMgr image package operations (13 functions)
- `Configuration/` - Configuration file I/O and conversion (4 functions)
- `DotNetOneDrive/` - .NET detection/installation and OneDrive deployment (5 functions)
- `Drivers/` - Driver installation and injection (3 functions)
- `ISO/` - ISO building and media staging (6 functions)
- `LanguagePacksFOD/` - Language pack and Features on Demand installation (11 functions)
- `Logging/` - Logging, output handling, notifications (4 functions)
- `Registry/` - Registry file installation and customization (6 functions)
- `UI/` - WPF form controls and UI state management (12 functions)
- `Updates/` - LCU, cumulative updates, patch sourcing (13 functions)
- `Utilities/` - Generic utility functions and helpers (13 functions)
- `WIMOperations/` - WIM mount, info queries, version checks (4 functions)

**Reference Documentation:**

- `README-Functions.md` - Complete function index with file paths and category descriptions
- `.github/prompts/plan-20260127-wwfunctions-modularization.md` - Modularization plan and implementation details

**Migration Details:**

- Original monolithic `WWFunctions.ps1` (9,683 lines) refactored into individual function files
- Each function file contains function definition and comment-based help
- Archive copy saved as `WWFunctions.ps1.deprecated-20260129` for reference and rollback capability
- Module loader updated to use category-based load order
- All 105 functions tested and verified during integration testing
- No breaking changes; public API remains unchanged

#### Private/WWFunctions.ps1.deprecated-20260129

**Purpose:** Archive of original monolithic functions file (deprecated as of 2026-01-29)

**Note:** This file is retained for reference and historical purposes. All functions have been extracted to `Private/Functions/` subdirectories. Do not modify this file; it is deprecated and will be removed in a future release. See `Private/README-Functions.md` and `.github/prompts/plan-20260127-wwfunctions-modularization.md` for migration details.

#### Private/Assets/appxWin*.psd1

**Purpose:** Version-specific AppX package removal lists
**Format:** PowerShell data files (hash tables)
**Structure:**

```powershell
@{
    Packages = @(
        'PackageName_Version_Arch_~_Publisher',
        # ... more packages
    )
}
```

**Maintenance:** Update when new Windows versions release

---

## Key Components

### Global Variables

Used throughout the application for state management:

- `$global:workdir` - Working directory path
- `$global:VerboseLogging` - Verbose mode flag
- `$WWScriptVer` - Application version (currently 5.0-beta, transitioning to date-based format)
- `$Form` - Main WPF form object
- Various `$WPF*` variables - WPF control references

### WPF Form Controls

Naming convention: `$WPF<ControlName>`

Examples:

- `$WPFSourceWIMTextBox` - Source WIM path
- `$WPFMountTextBox` - Mount directory
- `$WPFMISDriverButton` - Driver injection button
- `$WPFUpdatesEnableCheckBox` - Enable updates checkbox

### Working Directory Structure

```text
WorkingDir/
├── CompletedWIMs/        # Output WIMs
├── imports/              # Imported ISO content
│   ├── DotNet/          # .NET 3.5 binaries
│   └── ISO/             # ISO media files
├── logging/              # Log files
├── Mount/                # WIM mount point
├── Staging/              # ISO creation staging
├── updates/              # Downloaded updates
│   ├── win10-x64-22h2/
│   └── win11-x64-24h2/
├── Autopilot/            # Autopilot JSON files
├── Configs/              # Configuration files
├── Drivers/              # Driver folders
├── LanguagePacks/        # Language pack files
│   ├── Windows10/
│   └── Windows11/
├── LocalExperiencePacks/ # LXP files
├── FeaturesOnDemand/     # FOD files
├── CustomScripts/        # User scripts
├── RegistryFiles/        # .reg files
└── OneDrive/             # OneDrive installers
```

### Logging System

**Primary Function:** `Update-Log`
**Severity Levels:**

- `Information` - Standard messages (gray)
- `Warning` - Warnings (yellow)
- `Error` - Errors (red)
- `Comment` - Headers/separators (green)

**Log Files:**

- `Update-Log` writes to host and only writes to disk when `$Log` is populated; current code does not automatically set `$Log` to a default path.
- Legacy guidance assumes `WorkingDir/logging/`; verify log path at runtime via `$global:ScriptLogFilePath`.
- Named: `WIMWitch_[timestamp].log` when created by the caller.

---

## Coding Standards

**Source:** `vscode-userdata:/Users/nelson/Library/Application Support/Code/User/prompts/Powershell.instructions.md`

### PowerShell Best Practices

#### Output & Logging

1. **Write-Output for user messages**
   - Standard messages to users
   - Example: `Write-Output "Starting process..."`

2. **Write-Verbose for diagnostic info**
   - Progress messages, intermediate steps
   - Example: `Write-Verbose -Message "Step 1: Loading configuration..."`
   - Users control visibility with `-Verbose` flag

3. **Write-Error for error conditions**
   - Use for actual errors, not warnings
   - Always include `-Message` parameter
   - Example: `Write-Error -Message "Failed to load file: $_"`

4. **Write-Warning for non-critical issues**
   - Use when something unexpected but not fatal occurs
   - Example: `Write-Warning -Message "Package count lower than expected"`

5. **NO Write-Host**
   - Never use `Write-Host` in production code
   - Reason: Cannot be redirected, breaks pipeline architecture, interferes with automation
   - Exception: Only for interactive scripts where output redirection is not needed
   - **DO NOT** use color parameters (`-ForegroundColor`, `-BackgroundColor`)

#### Parameter Usage

1. **Always use explicit parameter names**
   - ❌ Bad: `Get-Content $file`
   - ✅ Good: `Get-Content -Path $file`

2. **Always use `-Message` for Write-* cmdlets**
   - ❌ Bad: `Write-Output "Message"`
   - ✅ Good: `Write-Output -Message "Message"`

3. **Always use full cmdlet names (no aliases)**
   - ❌ Bad: `gci $path`
   - ✅ Good: `Get-ChildItem -Path $path`

4. **Use `-Path` not positional position**
   - ❌ Bad: `Get-Item $filePath`
   - ✅ Good: `Get-Item -Path $filePath`

5. **Use `-Property` for Select-Object**
   - ❌ Bad: `Select-Object Name, Size`
   - ✅ Good: `Select-Object -Property Name, Size`

6. **Use `-FilterScript` for Where-Object**
   - ❌ Bad: `Where-Object { $_.Count -gt 5 }`
   - ✅ Good: `Where-Object -FilterScript { $_.Count -gt 5 }`

7. **Use `-Process` for ForEach-Object**
   - ❌ Bad: `ForEach-Object { Write-Output $_ }`
   - ✅ Good: `ForEach-Object -Process { Write-Output -Message $_ }`

#### Path Construction

1. **Always use `Join-Path` for building file paths**
   - ❌ Bad: `$path = $directory + "\file.txt"`
   - ✅ Good: `$path = Join-Path -Path $directory -ChildPath "file.txt"`
   - Reason: Handles path separators correctly across platforms (Windows `\`, Unix `/`)

2. **Never use string concatenation for paths**
   - ❌ Bad: `"$dir\$file"` or `"$dir/$file"`
   - ✅ Good: `Join-Path -Path $dir -ChildPath $file`
   - Reason: Fails on cross-platform scenarios, harder to read, error-prone

3. **Use `-ChildPath` explicitly for clarity**
   - ✅ Good: `Join-Path -Path $base -ChildPath "subfolder\file.ps1"`
   - Note: `Join-Path` handles nested paths correctly

4. **Use `Join-Path` in command parameters**
   - ❌ Bad: `Get-ChildItem -Path "$dir\$childdir" -Filter "*.ps1"`
   - ✅ Good: `Get-ChildItem -Path (Join-Path -Path $dir -ChildPath $childdir) -Filter "*.ps1"`
   - Reason: Properly handles path construction within expressions, maintains readability

#### Function Parameters

1. **Always declare parameter types**
   - ❌ Bad: `param($Name)`
   - ✅ Good: `param([string]$Name)`

2. **Always use CmdletBinding**

   ```powershell
   [CmdletBinding()]
   param(
       [Parameter(Mandatory = $false)]
       [string]$OutputPath = ".\default\"
   )
   ```

3. **Always use full parameter declarations**
   - Use `[Parameter(Mandatory = $false)]` not implicit defaults
   - Use `[Parameter(Mandatory = $true)]` for required parameters

#### Loop Constructs

1. **Prefer `ForEach-Object` for pipelines**
   - ✅ Good: `$items | ForEach-Object -Process { Do-Something -Item $_ }`

2. **Use `foreach` only when necessary**
   - Use when piping doesn't fit the pattern
   - Example: Building complex object collections

3. **Always use `-Process` with ForEach-Object**
   - ❌ Bad: `ForEach-Object { ... }`
   - ✅ Good: `ForEach-Object -Process { ... }`

4. **Always use `-FilterScript` with Where-Object**
   - ❌ Bad: `Where-Object { ... }`
   - ✅ Good: `Where-Object -FilterScript { ... }`

#### Error Handling

1. **Use `[CmdletBinding()]` with `-ErrorAction Stop`**

   ```powershell
   [CmdletBinding()]
   param()

   try {
       $result = Get-Item -Path $path -ErrorAction Stop
   } catch {
       Write-Error -Message "Failed: $_"
       exit 1
   }
   ```

2. **Always catch exceptions explicitly**
   - ❌ Bad: `try { ... } catch { ... }`
   - ✅ Good: `try { ... } catch { Write-Error -Message "..."; exit 1 }`

#### Code Generation & AI Disclosure

1. **Always disclose AI-assisted code**
   ```powershell
   .NOTES
       Author: Eden Nelson [edennelson]
       Version: 1.0

       Code Origin:
       Portions of this script were generated with assistance from GitHub Copilot AI.
       The author has reviewed and tested all code.
       This is disclosed in the interest of transparency.
   ```

2. **Do NOT claim to certify code as plagiarism-free**
   - Be honest: "Reviewed and tested" vs "verified no plagiarism"
   - Reason: Cannot certify what AI models trained on

### Legacy Standards (Pre-5.0)

The following may appear in older code but should be updated:

- ❌ `Write-Host` (replace with `Write-Output`)
- ❌ Positional parameters (add `-ParameterName`)
- ❌ Cmdlet aliases (use full names)
- ❌ Color parameters (remove, let users customize)

**Comment-Based Help Required:**

```powershell
<#
.SYNOPSIS
    Brief one-line description

.DESCRIPTION
    Detailed multi-line description

.PARAMETER ParameterName
    Description of parameter

.EXAMPLE
    Example usage with explanation

.NOTES
    Author: Eden Nelson
    Version: X.X.X
    Additional notes

.LINK
    Related documentation

.OUTPUTS
    Type of output returned
#>
```

**Required Sections:**

- SYNOPSIS (always)
- DESCRIPTION (always)
- PARAMETER (for each parameter)
- EXAMPLE (minimum 1, prefer 2-5)
- NOTES (always, include author)
- OUTPUTS (always)
- LINK (when applicable)

### Naming Conventions

**Functions:**

- Verb-Noun format (PowerShell standard)
- Approved verbs: `Get-`, `Set-`, `New-`, `Remove-`, `Test-`, `Invoke-`, `Update-`, `Install-`, `Import-`, `Select-`, `Deploy-`
- Examples: `Get-ImageInfo`, `Install-Driver`, `Select-SourceWIM`

**Variables:**

- camelCase for local variables
- `$global:` prefix for global scope
- WPF controls: `$WPF<ControlName>`

**Files:**

- PascalCase for module files
- lowercase for asset files
- Extensions: `.ps1` (scripts), `.psm1` (modules), `.psd1` (data/manifests)

---

## Critical Functions

### Tier 1: Core Orchestration

#### Invoke-WimWitchTng

**File:** Public/WIMWitch-tNG.ps1
**Purpose:** Main entry point, launches GUI or automation
**Parameters:** 12 parameters for various modes
**DO NOT:** Modify without thorough testing

#### Invoke-MakeItSo

**File:** Private/WWFunctions.ps1 (line ~8957)
**Purpose:** Core build orchestration function
**Name Origin:** Star Trek: TNG - Captain Picard's iconic command
**Workflow:**

1. Validation (admin, paths, WIM)
2. Mount WIM
3. Apply customizations (drivers, updates, AppX, etc.)
4. Dismount and save
5. Export to final location

**Critical:** This is the main workflow coordinator - when you're ready to apply all customizations, you "Make it so."

#### Invoke-RunConfigFile

**File:** Private/WWFunctions.ps1 (line ~2593)
**Purpose:** Executes configuration files in auto mode
**Input:** JSON/PSD1 configuration file
**Use Case:** CI/CD, batch processing

### Tier 2: Major Subsystems

#### Update-Log

**File:** Private/WWFunctions.ps1
**Purpose:** Universal logging function
**Called From:** Everywhere
**DO NOT:** Modify signature without checking all 500+ usages

#### Start-DriverInjection

**File:** Private/WWFunctions.ps1
**Purpose:** Recursively applies drivers from folder
**Dependencies:** `Install-Driver` (individual driver application)

#### Deploy-Updates

**File:** Private/WWFunctions.ps1
**Purpose:** Applies Windows Updates to mounted image
**Dependencies:** OSDUpdate, OSDSUS modules

#### Remove-Appx

**File:** Private/WWFunctions.ps1
**Purpose:** Removes AppX packages from image
**Input:** Array of package names from asset files

### Tier 3: UI & Selection

All `Select-*` functions display dialogs and return user selections:

- `Select-SourceWIM` - WIM file selection
- `Select-MountDir` - Mount directory
- `Select-DriverSource` - Driver folder
- `Select-Appx` - AppX packages for removal
- Many more (21 total)

### Tier 4: Configuration & Validation

#### Test-Admin

**File:** Private/WWFunctions.ps1
**Purpose:** Validates administrator privileges
**Called:** Early in execution

#### Test-WorkingDirectory

**File:** Private/WWFunctions.ps1
**Purpose:** Validates/creates working directory structure
**Creates:** All 13 required subdirectories

#### Repair-MountPoint

**File:** Private/WWFunctions.ps1
**Purpose:** Fixes stuck WIM mounts
**Options:** Automatic or interactive cleanup

---

## Common Workflows

### Adding a New Feature

1. **Determine Scope**
   - Public function (exported) or private (internal)?
   - GUI changes needed?
   - Configuration file support?

2. **Implement Function**
   - Add to `Private/WWFunctions.ps1` (or create new file in Private/)
   - Follow naming conventions
   - Add complete documentation
   - Follow coding standards

3. **Integrate into Workflow**
   - Update `Invoke-MakeItSo` if part of main workflow
   - Add GUI controls if needed (XAML + event handlers)
   - Add configuration file support

4. **Update Configuration Schema**
   - Add new properties to config JSON/PSD1
   - Update `Get-Configuration` and `Save-Configuration`

5. **Test**
   - GUI mode
   - Automation mode
   - ConfigMgr mode (if applicable)

### Updating for New Windows Version

1. **Create New AppX List**
   - Deploy clean Windows image
   - Run: `Get-AppxProvisionedPackage -Online`
   - Create new `appxWin<Version>.psd1` file
   - Add documentation header
   - List safe-to-remove packages

2. **Update Version Detection**
   - Modify `Get-WindowsType` if needed
   - Update `Set-Version` for new build numbers
   - Add to version dropdown in GUI

3. **Update Update Management**
   - Add new version to `Get-WindowsPatches`
   - Update download paths
   - Test with OSDSUS module

4. **Test Full Workflow**
   - Import ISO
   - Apply all customizations
   - Create bootable ISO
   - Deploy and verify

### Modifying GUI

1. **Locate XAML**
   - In `Public/WIMWitch-tNG.ps1`
   - Lines ~62-388
   - Embedded as string in `$inputXML`

2. **Modify XAML**
   - Add/modify controls
   - Set `x:Name` for code access
   - Follow existing naming: `<ControlType><Purpose>`

3. **Add Event Handlers**
   - After `#Connect to Controls` section
   - Pattern: `$WPFControlName.Add_Event({ # code })`
   - Use global variables for state

4. **Test Layout**
   - Launch GUI
   - Check all tab navigation
   - Verify control states and interactions

### Adding Dependencies

1. **Module Dependencies**
   - Add to `RequiredModules` in `.psd1`
   - Document in DESCRIPTION
   - Add version checking if needed

2. **External Tools**
   - Add detection function (`Test-<Tool>Exists`)
   - Add installation/download function
   - Update `Invoke-MakeItSo` validation

3. **Update Documentation**
   - README.md
   - Function help
   - This file

---

## Dependencies

### Required PowerShell Modules

**Manifest Note:** `RequiredModules` is not set in [WIMWitch-tNG/WIMWitch-tNG.psd1](WIMWitch-tNG/WIMWitch-tNG.psd1); modules below must be installed or imported manually when their features are used.

**OSDSUS** (OSD Update Support)

- Purpose: Windows Update catalog access
- Functions: Update download and metadata
- Install: `Install-Module -Name OSDSUS`

**OSDUpdate** (OSD Update)

- Purpose: Windows Update management
- Functions: Update application to WIM
- Install: `Install-Module -Name OSDUpdate`

**ConfigurationManager** (Optional)

- Purpose: SCCM/ConfigMgr integration
- Functions: Image package management
- Install: Included with ConfigMgr console

**WindowsAutopilotIntune** (Optional)

- Purpose: Autopilot profile management
- Functions: Download profiles from Intune
- Install: `Install-Module -Name WindowsAutopilotIntune`

### System Requirements

- **PowerShell:** 5.1 or higher
- **OS:** Windows 10/11 or Windows Server
- **Privileges:** Administrator required
- **Architecture:** 64-bit preferred (auto-relaunches from 32-bit)
- **Disk Space:** Varies (10GB+ recommended for working directory)

### External Tools

**Windows ADK** (Assessment and Deployment Kit)

- Purpose: ISO creation (oscdimg.exe)
- Required For: `New-WindowsISO` function
- Download: Microsoft website

**DISM** (Deployment Image Servicing and Management)

- Purpose: WIM manipulation
- Included: With Windows
- Used: Throughout application

### .NET Assemblies

**PresentationFramework** (WPF)

- Purpose: GUI rendering
- Required: For interactive mode
- Loaded: Automatically in GUI mode

---

## Testing Guidelines

### Pre-Testing Setup

1. **Working Directory**
   - Create clean working directory
   - Verify folder structure creation
   - Check permissions

2. **Source Media**
   - Obtain Windows ISO files
   - Place in accessible location
   - Verify integrity

3. **Test Environment**
   - Windows 10/11 workstation
   - Administrator account
   - 20GB+ free disk space

### Test Scenarios

#### Basic Functionality

- [ ] Launch GUI successfully
- [ ] Import Windows ISO
- [ ] Select source WIM and index
- [ ] Mount WIM
- [ ] Dismount WIM
- [ ] Export final WIM

#### Driver Injection

- [ ] Select driver folder
- [ ] Inject single driver
- [ ] Inject folder of drivers
- [ ] Verify drivers in WIM

#### Update Management

- [ ] Download Windows Updates
- [ ] Apply updates to mounted WIM
- [ ] Verify update installation
- [ ] Check for superseded updates

#### AppX Removal

- [ ] Load AppX list
- [ ] Select packages
- [ ] Remove from WIM
- [ ] Verify removal

#### Configuration Files

- [ ] Save configuration
- [ ] Load configuration
- [ ] Run in auto mode
- [ ] Verify all settings applied

#### ConfigMgr Integration

- [ ] Create new image package
- [ ] Update existing package
- [ ] Distribute to DPs
- [ ] Verify in SCCM console

### Validation Checks

After each operation:

1. Check log file for errors
2. Verify GUI status messages
3. Test resulting WIM deployment
4. Check Event Viewer for system errors

### Regression Testing

Before releasing changes:

1. Test all major workflows
2. Verify backward compatibility
3. Test on Windows 10 and 11
4. Test x64 and ARM64 (if applicable)

---

## Maintenance Tasks

### Regular Maintenance

**Monthly:**

- [ ] Update AppX lists for new Windows builds
- [ ] Check for module updates (OSDSUS, OSDUpdate)
- [ ] Review and close GitHub issues
- [ ] Update documentation for changes

**Quarterly:**

- [ ] Test with latest Windows builds
- [ ] Update version numbers
- [ ] Review and optimize slow functions
- [ ] Check for deprecated cmdlets

**Annually:**

- [ ] Major version review
- [ ] Refactor technical debt
- [ ] Performance optimization
- [ ] Security audit

### Code Maintenance

**Adding Documentation:**

- Always use comment-based help
- Follow documentation standards
- Include practical examples
- Test with `Get-Help`

**Refactoring:**

- Maintain backward compatibility
- Update all usages of modified functions
- Run full regression tests
- Update documentation

**Performance Optimization:**

- Profile slow operations
- Optimize loops and pipelines
- Cache repeated operations
- Consider parallel processing

### Version Management

**Date-Based Versioning (YYYY.M.D):**

Starting with first stable release after 5.0-beta, versions will use:

- **YYYY** = Year of release (e.g., 2026)
- **M** = Month of release (1-12, no leading zero)
- **D** = Patch/build number within that month (starts at 1)

Examples:

- `2026.1.1` = January 2026, first release
- `2026.1.2` = January 2026, second release (bugfix)
- `2026.3.1` = March 2026, first release

**Incrementing Versions:**

1. Update `ModuleVersion` in `.psd1` to YYYY.M.D format
2. Update `$WWScriptVer` in main function
3. Update XAML window title
4. Update README.md
5. Update CHANGELOG.md
6. Tag release in Git

**Breaking Changes:**

- Increment month or add suffix (e.g., 2026.2.1 or 2026.1.1-breaking)
- Document in CHANGELOG
- Provide migration guide
- Support legacy mode if possible

**Feature Additions:**

- New month release (e.g., 2026.1.1 → 2026.2.1)
- Document in release notes
- Add examples to documentation

**Bug Fixes:**

- Increment patch number (e.g., 2026.1.1 → 2026.1.2)
- Reference issue numbers
- Add regression test

**Pre-Releases:**

- Use suffix notation (e.g., 5.0-beta, 2026.1.1-rc1)
- Document pre-release status clearly

---

## Common Issues & Solutions

### Mount Point Stuck

**Symptom:** WIM mount won't unmount
**Solution:** Run `Repair-MountPoint` with `-AutoFix`
**Prevention:** Always dismount cleanly, handle errors

### PowerShell Version Issues

**Symptom:** Module won't load
**Check:** PowerShell version 5.1+
**Solution:** Update PowerShell or use compatibility mode

### GUI Not Displaying

**Symptom:** Black screen or crash on launch
**Causes:**

- Missing .NET assemblies
- Display scaling issues
- PowerShell ISE incompatibility

**Solution:** Run from PowerShell console, not ISE

### Update Download Failures

**Symptom:** Updates won't download
**Causes:**

- OSDSUS module outdated
- Network connectivity
- Microsoft catalog changes

**Solution:** Update module, check network, verify catalog URLs

### ConfigMgr Connection Issues

**Symptom:** Can't connect to ConfigMgr
**Checks:**

- ConfigMgr console installed?
- Correct site code?
- Network access to site server?

**Solution:** Install console, verify site code, check connectivity

---

## Future Development Considerations

### Planned Features

- Multi-threading for faster processing
- Cloud integration (Azure, Intune)
- Enhanced logging (structured logs)
- Web-based GUI option
- Linux support (PowerShell Core)

### Technical Debt

- Refactor monolithic WWFunctions.ps1 into modules
- Separate XAML into external file
- Implement proper error handling framework
- Add unit tests (Pester framework)
- Migrate from Write-Host to proper logging

### Architecture Improvements

- Plugin system for extensibility
- API for external integrations
- Database backend for asset management
- Central configuration management
- Telemetry and analytics

---

## Quick Reference

### Most Modified Functions

1. `Invoke-MakeItSo` - Main workflow changes
2. `Update-Log` - Logging enhancements
3. `Deploy-Updates` - Update management
4. `Select-Appx` - AppX package selection
5. GUI event handlers - UI changes

### Files Requiring Signatures

- All `.ps1`, `.psm1`, `.psd1` files have signature blocks
- DO NOT manually edit signature blocks
- Re-sign after changes using proper certificate

### Key Git Branches

- `main` - Stable release branch
- `development` - Active development
- Feature branches - Specific features

### Critical Paths

- Working Directory: User-specified
- Module Path: `$PSModulePath`
- Logs: `WorkingDir/logging/`
- Configs: `WorkingDir/Configs/`

---

## Document Maintenance

**Last Updated:** January 19, 2026
**Updated By:** AI Assistant
**Version:** 1.0

**Update Triggers:**

- Major architectural changes
- New feature additions
- Significant refactoring
- Breaking changes
- Quarterly reviews
- **See [CHANGELOG.md](CHANGELOG.md) for detailed project history and planned work**

**Maintainers:**

- Add your name when making significant updates
- Include date and summary of changes
- Link to related PRs/issues
- Update [CHANGELOG.md](CHANGELOG.md) to reflect completed work and status changes

---

## Additional Resources

**Primary Documentation:**

- [CHANGELOG.md](CHANGELOG.md) - Complete project history, completed work, and planned features since fork
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) - This file: comprehensive AI development guide

**Supporting Documentation:**

- README.md - User-facing documentation
- USAGE.md - Usage examples
- LICENSE - License information
- .github/TESTING_GUIDE.md - Testing procedures for verbose logging
- .github/VERBOSE_LOGGING_IMPLEMENTATION.md - Logging implementation details
- .github/prompts/*.prompt.md - Detailed implementation plans for features and bug fixes

**External Links:**

- GitHub Repository: <https://github.com/alaurie/WimWitchFK>
- PowerShell Gallery: (if published)
- Wiki: (if available)

**Community:**

- GitHub Issues - Bug reports and feature requests
- Discussions - General questions and ideas

---

_This document is maintained for AI-assisted development. Keep it updated as the project evolves._
