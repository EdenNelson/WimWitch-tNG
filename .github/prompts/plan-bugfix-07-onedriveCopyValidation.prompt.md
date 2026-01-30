# Bugfix 7: OneDrive Copy Path Validation and Architecture Detection

## Issue
Copy-OneDrive function fails on missing files with unhandled exceptions and applies wrong architecture without checking.

## Root Cause
[Copy-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Copy-OneDrive.ps1) function:
- No file existence checks before ACL operations (Get-Acl, Get-Item fail on non-existent paths)
- No architecture detection—blindly attempts all operations
- Error logs show attempts to modify x86 installer on x64 Windows 11 systems

## Solution
Add silent file existence checks and architecture-aware conditional logic.

## Implementation Details
- Test path existence before ACL operations:
  ```powershell
  if (-not (Test-Path "$mountpath\Windows\SysWOW64\OneDriveSetup.exe")) {
      Update-Log -Data "Skipping x86 OneDrive—SysWOW64 not present" -Class Information
      return
  }
  ```
- Detect WIM architecture to copy correct installer
- Windows 11: only copy x64 or ARM64 (never x86)
- Windows 10: copy based on target architecture
- Log all skipped operations as Information, not Error

## Testing
- Service Windows 11 x64, verify x86 copy skipped silently
- Service Windows 11 ARM64, verify x64 skipped, ARM64 applied
- Service Windows 10, verify both architectures copied
- Check logs for proper messaging (skip vs apply)
- Verify no unhandled exceptions in error log
