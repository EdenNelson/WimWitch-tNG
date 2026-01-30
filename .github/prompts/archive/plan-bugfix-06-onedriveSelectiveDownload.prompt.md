# Bugfix 6: OneDrive Download Unnecessary Architectures

## Issue
All OneDrive installers (x86, x64, ARM64) are downloaded regardless of which Windows OS/architecture is being serviced, wasting bandwidth and storage.

## Root Cause
[Get-OneDrive](WIMWitch-tNG/Private/WWFunctions.ps1#L2202) function downloads all available architectures without detecting the target WIM version.

## Solution
Download only the OneDrive installer(s) matching the OS/architecture being serviced.

## Implementation Details
- Detect Windows version and architecture from serviced WIM
- Conditional downloads:
  - **Windows 10 x64**: Download x86 + x64 only
  - **Windows 11 x64**: Download x64 only (skip x86 and ARM64)
  - **Windows 11 ARM64**: Download ARM64 only (skip x86 and x64)
- Architecture detection uses `$WPFSourceWimArchTextBox.text`
- Use Windows version detection from `Get-WindowsType` function

## Testing
- Service Windows 10 image, verify only x86 and x64 OneDrive downloaded
- Service Windows 11 image, verify only x64 and ARM64 OneDrive downloaded
- Confirm x86 is never downloaded for Windows 11
- Verify directory structure matches downloaded architectures
