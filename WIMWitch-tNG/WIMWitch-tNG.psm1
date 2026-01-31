<#
.SYNOPSIS
    WIMWitch-tNG PowerShell Module - Root module file for Windows image customization toolkit.
    "Engage." - Captain Jean-Luc Picard

.DESCRIPTION
    This module provides comprehensive Windows image (WIM) customization capabilities through
    a graphical interface and automation features. WIMWitch-tNG is a community fork of the
    original WIMWitch tool, designed to help IT professionals create customized Windows
    installation images.

    The "tNG" (the Next Generation) theme honors Donna Ryan's (TheNotoriousDRR) original
    Star Trek: The Next Generation inspiration, reflecting the project's evolution while
    maintaining its core mission.

    The module architecture follows PowerShell best practices:
    - Public functions are exported and available to users
    - Private functions contain internal implementation details
    - All functions are dot-sourced from separate files for maintainability

    Key capabilities:
    - Windows Update integration (driver and cumulative updates)
    - Application package (AppX) removal
    - Language pack and Features on Demand installation
    - Microsoft Endpoint Configuration Manager integration
    - Autopilot profile deployment
    - ISO media creation
    - Custom registry and start menu configuration

.NOTES
    Author: Alex Laurie, Donna Ryan
    Maintained By: Eden Nelson
    Module Name: WIMWitch-tNG
    Version: 5.0-beta
    License: See LICENSE file in repository

    Versioning: Transitioning to date-based format (YYYY.M.D)
    Next stable release will use 2026.1.x format

.LINK
    https://github.com/alaurie/WimWitchFK
#>

# Dot source public functions
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1') -ErrorAction Stop)
foreach ($import in $public) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

# Dot source private functions in logical categories (load order respects dependencies)
# Load order is based on dependency chain validated during Stage 0 of modularization
# See: .github/prompts/plan-20260127-wwfunctions-modularization.md for detailed rationale
#
# LOAD ORDER RATIONALE:
# 1. UI - Form controls and WPF state management (used by most other functions)
# 2. Administrative - Validation and privilege checks (prerequisite for module startup)
# 3. Configuration - Config file I/O (needed early in main function)
# 4. Logging - Logging infrastructure (used throughout module)
# 5. WIMOperations - Core WIM operations (prerequisite for media functions)
# 6. Drivers - Driver operations (used in main orchestration)
# 7. Updates - Windows Update operations (dependency: Logging, WIMOperations)
# 8. AppX - Package removal (dependency: Logging, WIMOperations)
# 9. Autopilot - Autopilot configuration (dependency: Configuration)
# 10. ISO - ISO creation (dependency: WIMOperations)
# 11. DotNetOneDrive - Runtime installation (dependency: Logging)
# 12. LanguagePacksFOD - Language installation (dependency: WIMOperations, Logging)
# 13. ConfigMgr - SCCM integration (dependency: Logging, WIMOperations)
# 14. Registry - Registry customization (dependency: Logging)
# 15. BootWIM - Boot image updates (dependency: WIMOperations)
# 16. Utilities - Utility functions and main orchestration (dependency: all categories)
#
# NOTE: This explicit load order prevents circular dependencies and ensures all functions
# are available when referenced. The dependency chain was validated during extraction;
# changes to this order should be tested thoroughly with Import-Module.
$privateFunctionDirs = @(
    'Private/Functions/UI',                    # Form & UI Controls (12 functions)
    'Private/Functions/Administrative',        # Administrative & Validation (5 functions)
    'Private/Functions/Configuration',         # Configuration Management (4 functions)
    'Private/Functions/Logging',               # Logging & Output (4 functions)
    'Private/Functions/WIMOperations',         # WIM Operations (4 functions)
    'Private/Functions/Drivers',               # Driver Management (3 functions)
    'Private/Functions/Updates',               # Windows Update Management (13 functions)
    'Private/Functions/AppX',                  # AppX Package Management (3 functions)
    'Private/Functions/Autopilot',             # Windows Autopilot (1 function)
    'Private/Functions/ISO',                   # ISO & Media Creation (6 functions)
    'Private/Functions/DotNetOneDrive',        # .NET & OneDrive (5 functions)
    'Private/Functions/LanguagePacksFOD',      # Language Packs & FODs (11 functions)
    'Private/Functions/ConfigMgr',             # ConfigMgr Integration (13 functions)
    'Private/Functions/Registry',              # Registry & Customization (6 functions)
    'Private/Functions/BootWIM',               # Boot WIM & WinRE (2 functions)
    'Private/Functions/Utilities'              # Utility & Orchestration (13 functions)
)

foreach ($dir in $privateFunctionDirs) {
    $dirPath = Join-Path -Path $PSScriptRoot -ChildPath $dir
    if (Test-Path -Path $dirPath) {
        $functionFiles = @(Get-ChildItem -Path $dirPath -Filter '*.ps1' -ErrorAction SilentlyContinue)
        foreach ($import in $functionFiles) {
            try {
                . $import.FullName
            } catch {
                throw "Unable to dot source [$($import.FullName)]"
            }
        }
    }
}

Export-ModuleMember -Function 'Invoke-WimWitchTng'

# Backward compatibility alias
New-Alias -Name 'Invoke-WIMWitch-tNG' -Value 'Invoke-WimWitchTng' -Force
Export-ModuleMember -Alias 'Invoke-WIMWitch-tNG'
