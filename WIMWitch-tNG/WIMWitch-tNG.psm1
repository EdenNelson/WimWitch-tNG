<#
.SYNOPSIS
    WIMWitch-tNG PowerShell Module - Root module file for Windows image customization toolkit.

.DESCRIPTION
    This module provides comprehensive Windows image (WIM) customization capabilities through
    a graphical interface and automation features. WIMWitch-tNG is a community fork of the
    original WIMWitch tool, designed to help IT professionals create customized Windows
    installation images.

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
    Module Name: WIMWitch-tNG
    Version: 4.0.1
    License: See LICENSE file in repository

.LINK
    https://github.com/alaurie/WimWitchFK
#>

# Dot source public/private functions
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1') -Recurse -ErrorAction Stop)
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1') -Recurse -ErrorAction Stop)
foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

Export-ModuleMember -Function 'Invoke-WimWitchTng'

# Backward compatibility alias
New-Alias -Name 'Invoke-WIMWitch-tNG' -Value 'Invoke-WimWitchTng' -Force
Export-ModuleMember -Alias 'Invoke-WIMWitch-tNG'

