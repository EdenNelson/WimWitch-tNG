# Bugfix 5: OneDrive Copy Wrong Architecture to WIM

## Issue
OneDrive installer copy operation attempts to apply wrong architecture to serviced WIM. For Windows 11 x64, it tries to copy x86 installer to SysWOW64, which doesn't exist, causing silent failures.

## Root Cause
[Copy-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Copy-OneDrive.ps1) function:
- Doesn't detect WIM architecture being serviced
- Attempts to copy both x86 and x64 without checking if target paths exist
- Fails with unhandled exceptions when paths don't exist (Get-Acl, Get-Item on non-existent files)
- No architecture-specific logic

## Solution
Add architecture detection and silent path existence checks, apply only correct installer.

## Implementation Details
- Detect WIM architecture being serviced (x64, ARM64, x86) from global context
- Add silent file existence test before attempting ACL operations:
  ```powershell
  if (-not (Test-Path "$mountpath\Windows\SysWOW64\OneDriveSetup.exe")) {
      return  # Skip silently if not found
  }
  ```
- Windows 11 images: only copy x64 or ARM64 OneDrive (never x86)
- Windows 10 images:
  - x86 to `System32\SysWOW64\OneDriveSetup.exe`
  - x64 to `System32\OneDriveSetup.exe`
- Skip architecture not being applied

## Testing
- Service Windows 11 x64, verify only x64 OneDrive copied
- Service Windows 11 ARM64, verify only ARM64 OneDrive copied
- Service Windows 10 x64, verify both x86 and x64 copied
- Verify no errors on missing files (silent skip)
- Confirm OneDrive actually updated in mount
