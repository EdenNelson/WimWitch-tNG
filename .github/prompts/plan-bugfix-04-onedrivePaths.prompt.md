# Bugfix 4: OneDrive Wrong Download Directory & Missing ARM64

## Issue
OneDrive x86 installer downloads to wrong directory, and ARM64 installer is never downloaded for Windows 11 systems.

## Root Cause
[Get-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Get-OneDrive.ps1) function:
- Downloads x86 to `\updates\OneDrive` instead of `\updates\OneDrive\x86`
- Downloads x64 to `\updates\OneDrive\x64` (correct)
- Never downloads ARM64 for Windows 11
- No Windows version detection to skip unnecessary downloads

## Solution
Fix download paths and add Windows version detection for architecture-specific downloads.

## Implementation Details
- Change x86 download path from `$global:workdir\updates\OneDrive` to `$global:workdir\updates\OneDrive\x86`
- Add Windows version detection (detect if servicing Windows 10 vs Windows 11)
- Windows 10: download x86 + x64 installers
- Windows 11: skip x86, download x64 + ARM64 installers
- ARM64 download URL: `https://go.microsoft.com/fwlink/?linkid=2282608`
- ARM64 download path: `$global:workdir\updates\OneDrive\arm64`
- Validate all architecture directories exist before attempting downloads

## Testing
- Service Windows 10 image, verify x86 and x64 downloaded to correct paths
- Service Windows 11 image, verify only x64 and ARM64 downloaded (no x86)
- Verify directory structure is created correctly
- Confirm file downloads complete successfully
