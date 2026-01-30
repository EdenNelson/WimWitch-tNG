# Bugfix 1: WIM Selection Window Default Directory

## Issue
WIM file selection dialog defaults to Desktop folder instead of the working directory's Imports\Wims folder, forcing users to navigate away from where WIM files are typically stored.

## Root Cause
[Select-SourceWIM](WIMWitch-tNG/Private/WWFunctions.ps1#L131) function sets `InitialDirectory` to `[Environment]::GetFolderPath('Desktop')`.

## Solution
Update `InitialDirectory` property to use `$global:workdir\Imports\Wims` with directory validation before use.

## Implementation Details
- Set `InitialDirectory = $global:workdir\Imports\Wims`
- Add validation: if directory doesn't exist, use fallback (Documents or Desktop)
- Ensure the path exists before opening dialog

## Testing
- Verify dialog opens to correct directory
- Confirm fallback works if Imports\Wims doesn't exist
- Test with various working directory paths
