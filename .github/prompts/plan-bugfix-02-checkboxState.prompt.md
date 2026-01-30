# Bugfix 2: Child Checkbox Responsiveness After Config Load

**TL;DR:** Ensure `Reset-MISCheckBox` sets child control `IsEnabled` states for both checked and unchecked parents so the UI matches loaded configs.

## Current Behavior
- After loading a configuration, child controls can stay enabled while the parent checkbox is unchecked; they only disable after a manual toggle.
- Root cause: Reset-MISCheckBox in [WIMWitch-tNG/Private/Functions/UI/Reset-MISCheckBox.ps1](../../WIMWitch-tNG/Private/Functions/UI/Reset-MISCheckBox.ps1) only handles the true case and never sets `IsEnabled = $False` for dependents.

## Goals
- Synchronize child control enablement to parent checkbox state during config load and manual toggles.
- Keep MIS status text boxes aligned with control state (True/False).

## Implementation
1. Add paired `if/else` branches in `Reset-MISCheckBox` for each parent → child set:
   - JSON Autopilot: `$WPFJSONEnableCheckBox` → `$WPFJSONButton`, `$WPFMISJSONTextBox` (set text to True/False).
   - Drivers: `$WPFDriverCheckBox` → `$WPFDriverDir1Button`..`Dir5Button`, `$WPFMISDriverTextBox`.
   - Updates: `$WPFUpdatesEnableCheckBox` → `$WPFMISUpdatesTextBox` (set text True/False).
   - AppX: `$WPFAppxCheckBox` → `$WPFAppxButton`, `$WPFMISAppxTextBox` (True/False text).
   - Custom Script: `$WPFCustomCBEnableApp` → `$WPFCustomBDefaultApp`.
   - Start Menu: `$WPFCustomCBEnableStart` → `$WPFCustomBStartMenu`.
   - Registry: `$WPFCustomCBEnableRegistry` → `$WPFCustomBRegistryAdd`, `$WPFCustomBRegistryRemove`.
2. Ensure every branch logs once (keep existing `Update-Log` call at function start only).
3. Keep logic idempotent so repeated calls from `Get-Configuration` or manual toggles always produce consistent enablement.

## Testing
- Load a config where each parent is unchecked; confirm all dependents are disabled and MIS text boxes show False.
- Load a config where each parent is checked; confirm dependents are enabled and MIS text boxes show True.
- Toggle each parent on/off manually after load; verify child states flip accordingly without requiring multiple toggles.
- Regression: run `Reset-MISCheckBox` twice in a row; states should remain correct (no double-toggling side effects).
