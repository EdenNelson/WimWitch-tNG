# Bugfix 3: ConfigMgr Package Settings Duplicate Distribution Points

## Issue
When saving ConfigMgr package settings files, the `CMDPList` array contains duplicate Distribution Point entries instead of unique values only.

## Root Cause
[Save-Configuration](../../WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1) saves `$WPFCMLBDPs.Items` directly to `CMDPList` without deduplication. The UI list can accumulate duplicates from multiple operations.

## Solution
Deduplicate `CMDPList` before writing ConfigMgr package settings files.

## Implementation Details
- In `Save-Configuration`, when saving ConfigMgr package info (not standard config)
- Before setting `$CurrentConfig.CMDPList`, deduplicate the items:
  ```powershell
  $CurrentConfig.CMDPList = @($WPFCMLBDPs.Items | Select-Object -Unique)
  ```
- Or use PowerShell object deduplication if items are objects

## Testing
- Add duplicate DPs to the list via UI
- Save ConfigMgr package settings
- Load the saved file and verify only unique DPs are present
- Verify saved PSD1 file contains no duplicate entries
