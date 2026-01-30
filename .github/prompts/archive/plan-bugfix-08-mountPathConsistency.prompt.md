# Bugfix 8: Mount Path Consistency—Hardcoded vs Working Directory

## Issue
Mount path is inconsistent across the codebase. Some paths use the configured working directory while others use hardcoded legacy path `D:\Scripts\WIMWitch\Mount`, causing operations to fail when files exist in the correct working directory location.

## Root Cause
Functions using `$mountpath` variable are not consistently deriving it from `$global:workdir`. Some references appear to be hardcoded or from old code paths.

Evidence from logs:
- Staging/updates paths: `D:\Scripts\WIMWitchFK\...` (correct working directory)
- Mount paths: `D:\Scripts\WIMWitch\Mount\...` (legacy hardcoded)
- DISM and file operations fail because they look for files in wrong location

## Solution
Audit and fix all mount path derivation to ensure consistent use of `$global:workdir\Mount`.

## Implementation Details
- Audit all functions using `$mountpath` variable:
  - Verify it's set from `$WPFMISMountTextBox.text` (user-configured) or
  - Derived from `$global:workdir\Mount` (default)
- Ensure all paths below mount point use this base path consistently
- Remove/update any hardcoded references to:
  - `D:\Scripts\WIMWitch\Mount`
  - Legacy mount paths
- Verify mount path validation happens early in workflow
- Confirm variable is passed correctly to all functions

## Testing
- Configure working directory to custom path
- Verify all mount operations use that directory
- Check logs show mount operations in correct location
- Test DISM operations find files correctly
- Verify no references to legacy hardcoded paths in logs
