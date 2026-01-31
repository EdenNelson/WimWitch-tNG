# Technical Implementation Plan: Driver Injection Method Selection

**Date:** 2026-01-30
**Scribe Plan:** [scribe-plan-20260130-driverInjection.md](scribe-plan-20260130-driverInjection.md)
**Approver:** Eden Nelson

---

## Executive Summary

Add a user-selectable driver injection method to WIMWitch-tNG with two options:
1. **PowerShell Loop** (existing, slower, per-INF processing)
2. **DISM Recursive** (new, faster, native `/Recurse` flag)

The user selects the method via a checkbox on the Driver tab. The choice persists in configuration files. Both methods continue processing on failure; the new DISM method parses logs to surface failed INF files to the user.

---

## Current State Analysis

### Existing Components

**Driver Injection Flow:**
- **Trigger:** [`Invoke-MakeItSo.ps1`](../../WIMWitch-tNG/Private/Functions/Utilities/Invoke-MakeItSo.ps1#L184-L191)
  - Checks `$WPFDriverCheckBox.IsChecked`
  - Calls `Start-DriverInjection` for each of 5 driver source folders

**PowerShell Loop Implementation:**
- **Function:** [`Start-DriverInjection`](../../WIMWitch-tNG/Private/Functions/Drivers/Start-DriverInjection.ps1#L1-L12)
  - Validates folder path
  - Recursively enumerates `*.inf` files
  - Calls `Install-Driver` for each INF

- **Function:** [`Install-Driver`](../../WIMWitch-tNG/Private/Functions/Drivers/Install-Driver.ps1#L1-L8)
  - Calls `Add-WindowsDriver -Path <mount> -Driver <inf>`
  - On success: logs "Applied `<inf>`" (Information)
  - On failure: logs "Couldn't apply `<inf>`" (Warning) — **does not throw/stop**

**UI Controls:**
- **Checkbox:** `$WPFDriverCheckBox` ([WIMWitch-tNG.ps1#L255](../../WIMWitch-tNG/Public/WIMWitch-tNG.ps1#L255))
  - Label: "Enable Driver Injection"
  - Enables/disables 5 driver source folder selectors

**Configuration Persistence:**
- **Save:** [`Save-Configuration.ps1#L17`](../../WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1#L17)
  - `DriversEnabled = $WPFDriverCheckBox.IsChecked`
- **Load:** [`Get-Configuration.ps1#L18`](../../WIMWitch-tNG/Private/Functions/UI/Get-Configuration.ps1#L18)
  - `$WPFDriverCheckBox.IsChecked = $settings.DriversEnabled`

**Logging Infrastructure:**
- **Log Location:** `$global:workdir\logging\WIMWitch-tNG.log` ([Set-Logging.ps1#L5](../../WIMWitch-tNG/Private/Functions/Logging/Set-Logging.ps1#L5))
- **Log Function:** [`Update-Log`](../../WIMWitch-tNG/Private/Functions/Logging/Update-Log.ps1#L1-L50)
  - Writes timestamped messages to log file
  - Console output color-coded by class: Information (Gray), Warning (Yellow), Error (Red)

### Current Failure Behavior
- `Install-Driver` catches exceptions, logs warning, **continues** (does not throw)
- No aggregated failure report — user must scan log for "Couldn't apply" lines

---

## Design Decisions

### UI Approach: Single Checkbox (Recommended)
**Control:** `$WPFDriverDismRecurseCheckBox`
**Label:** "Use Fast DISM Recursive Injection"
**Behavior:**
- **Unchecked (default):** PowerShell loop (existing logic)
- **Checked:** DISM recursive (new logic)

**Rationale:**
- Minimal UI footprint (one control vs. two radio buttons or dropdown)
- Clear intent: "Fast" signals performance improvement
- Visually grouped with existing `$WPFDriverCheckBox`

**Alternative Rejected:** Radio buttons (more verbose, takes more vertical space on Driver tab)

### Configuration Schema Extension
Add to configuration hashtable/PSD1:
```powershell
UseDismRecurse = $WPFDriverDismRecurseCheckBox.IsChecked  # Boolean
```

### Logging Strategy

**DISM Log Path:**
`$global:workdir\logging\DISM-DriverInjection.log`

**Log Level:** `/LogLevel:3` (standard DISM verbosity — warnings and errors)

**Retention:** Overwrite on each run (matches current WIMWitch-tNG.log behavior)

**Failure Detection Pattern:**
```powershell
$Errors = Select-String -Path "$global:workdir\logging\DISM-DriverInjection.log" -Pattern "\[.*\]\s+Error"
```

**INF Extraction Logic:**
- DISM error logs typically include the INF filename in the error line
- Example: `[0x80070002] Error: Could not find driver file: C:\drivers\Intel\NUC\network.inf`
- Parse pattern: extract filename from error context (regex or split on path separator)

### Failure Reporting UX
**On Completion:**
1. **All Drivers Succeed:** Log "All drivers injected successfully" (Information class, green/gray)
2. **Some Drivers Fail:**
   - Log "Driver injection completed with errors" (Warning class, yellow)
   - For each failed INF: Log "Failed: `<filename.inf>`" (Warning class)
   - User sees list in standard log output (no pop-up — matches current pattern)

**Rationale for Warning (not Error):**
Current `Install-Driver` uses Warning class for failures. Maintain consistency.

---

## Implementation Plan

### Stage 1: UI Modifications

**File:** [`WIMWitch-tNG/Public/WIMWitch-tNG.ps1`](../../WIMWitch-tNG/Public/WIMWitch-tNG.ps1)

**Actions:**
1. **Add Checkbox Control** (XAML, after line 255):
   ```xml
   <CheckBox x:Name="DriverDismRecurseCheckBox" Content="Use Fast DISM Recursive Injection"
             HorizontalAlignment="Left" Margin="26,100,0,0" VerticalAlignment="Top"
             IsEnabled="False"/>
   ```
   - Positioned below `$WPFDriverCheckBox`
   - Starts disabled (enabled when `$WPFDriverCheckBox` is checked)

2. **Add Event Handler** (PowerShell, near line 918):
   ```powershell
   $WPFDriverCheckBox.Add_Click({
       If ($WPFDriverCheckBox.IsChecked -eq $true) {
           # Enable DISM checkbox
           $WPFDriverDismRecurseCheckBox.IsEnabled = $true
           # ... existing logic to enable folder selectors ...
       } Else {
           # Disable and uncheck DISM checkbox
           $WPFDriverDismRecurseCheckBox.IsEnabled = $false
           $WPFDriverDismRecurseCheckBox.IsChecked = $false
           # ... existing logic to disable folder selectors ...
       }
   })
   ```

### Stage 2: Configuration File Support

**File 1:** [`Save-Configuration.ps1`](../../WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1)

**Action:** Add to hashtable (after line 17):
```powershell
UseDismRecurse   = $WPFDriverDismRecurseCheckBox.IsChecked
```

**File 2:** [`Get-Configuration.ps1`](../../WIMWitch-tNG/Private/Functions/UI/Get-Configuration.ps1)

**Action:** Add after line 18:
```powershell
$WPFDriverDismRecurseCheckBox.IsChecked = $settings.UseDismRecurse
```

**Edge Case Handling:**
If loading an old config (no `UseDismRecurse` key):
```powershell
if ($null -ne $settings.UseDismRecurse) {
    $WPFDriverDismRecurseCheckBox.IsChecked = $settings.UseDismRecurse
} else {
    $WPFDriverDismRecurseCheckBox.IsChecked = $false  # Default to PowerShell loop
}
```

### Stage 3: Create DISM Injection Function

**New File:** `WIMWitch-tNG/Private/Functions/Drivers/Start-DismDriverInjection.ps1`

**Function Signature:**
```powershell
Function Start-DismDriverInjection {
    Param(
        [string]$Folder
    )
```

**Logic:**
1. **Path Validation:**
   ```powershell
   $testpath = Test-Path $Folder -PathType Container
   If ($testpath -eq $false) { return }
   ```

2. **Log Location:**
   ```powershell
   $LogPath = "$global:workdir\logging\DISM-DriverInjection.log"
   ```

3. **DISM Command:**
   ```powershell
   Update-Log -Data "Applying drivers from $Folder using DISM /Recurse" -Class Information

   $MountPath = $WPFMISMountTextBox.Text
   $dismArgs = @(
       "/Image:`"$MountPath`""
       "/Add-Driver"
       "/Driver:`"$Folder`""
       "/Recurse"
       "/LogPath:`"$LogPath`""
       "/LogLevel:3"
   )

   & dism.exe $dismArgs
   ```

4. **Failure Detection:**
   ```powershell
   if (Test-Path $LogPath) {
       $Errors = Select-String -Path $LogPath -Pattern "\[.*\]\s+Error"

       if ($Errors.Count -gt 0) {
           Update-Log -Data "Driver injection completed with errors from $Folder" -Class Warning

           # Extract failed INFs
           foreach ($ErrorLine in $Errors) {
               # Pattern: extract filename from error context
               # Example: "C:\drivers\network.inf" -> "network.inf"
               if ($ErrorLine -match '([^\\]+\.inf)') {
                   $FailedInf = $matches[1]
                   Update-Log -Data "Failed: $FailedInf" -Class Warning
               }
           }
       } else {
           Update-Log -Data "All drivers from $Folder injected successfully" -Class Information
       }
   }

   Update-Log -Data "Completed DISM driver injection from $Folder" -Class Information
   ```

**Error Handling:**
- DISM exit codes are **not** checked (mirrors PowerShell loop behavior of continuing on failure)
- Parse log for errors instead (more granular)

### Stage 4: Modify Invoke-MakeItSo

**File:** [`Invoke-MakeItSo.ps1`](../../WIMWitch-tNG/Private/Functions/Utilities/Invoke-MakeItSo.ps1)

**Current Code (lines 184-191):**
```powershell
If ($WPFDriverCheckBox.IsChecked -eq $true) {
    Start-DriverInjection -Folder $WPFDriverDir1TextBox.text
    Start-DriverInjection -Folder $WPFDriverDir2TextBox.text
    Start-DriverInjection -Folder $WPFDriverDir3TextBox.text
    Start-DriverInjection -Folder $WPFDriverDir4TextBox.text
    Start-DriverInjection -Folder $WPFDriverDir5TextBox.text
} Else {
    Update-Log -Data 'Drivers were not selected for injection. Skipping.' -Class Information
}
```

**New Code:**
```powershell
If ($WPFDriverCheckBox.IsChecked -eq $true) {
    # Check which injection method to use
    If ($WPFDriverDismRecurseCheckBox.IsChecked -eq $true) {
        # Use DISM Recursive method
        Start-DismDriverInjection -Folder $WPFDriverDir1TextBox.text
        Start-DismDriverInjection -Folder $WPFDriverDir2TextBox.text
        Start-DismDriverInjection -Folder $WPFDriverDir3TextBox.text
        Start-DismDriverInjection -Folder $WPFDriverDir4TextBox.text
        Start-DismDriverInjection -Folder $WPFDriverDir5TextBox.text
    } Else {
        # Use PowerShell Loop method (existing)
        Start-DriverInjection -Folder $WPFDriverDir1TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir2TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir3TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir4TextBox.text
        Start-DriverInjection -Folder $WPFDriverDir5TextBox.text
    }
} Else {
    Update-Log -Data 'Drivers were not selected for injection. Skipping.' -Class Information
}
```

---

## Testing Checklist

### Functional Tests
- [ ] Checkbox starts disabled when Driver Injection is off
- [ ] Checkbox enables when Driver Injection checkbox is checked
- [ ] Checkbox disables and unchecks when Driver Injection is unchecked
- [ ] PowerShell loop method still works (existing behavior)
- [ ] DISM recursive method injects drivers successfully
- [ ] DISM log file is created in `$global:workdir\logging\`
- [ ] Failed INF files are detected and logged
- [ ] Success message displays when all drivers succeed
- [ ] Both methods continue processing after failures (no halt)

### Configuration Tests
- [ ] Saving config with DISM checkbox checked persists `UseDismRecurse = $true`
- [ ] Loading config with `UseDismRecurse = $true` checks the DISM checkbox
- [ ] Loading old config (no `UseDismRecurse` key) defaults to unchecked
- [ ] Multiple driver folders work with both methods

### Edge Cases
- [ ] Empty driver folder (no INFs) — both methods handle gracefully
- [ ] Invalid driver folder path — both methods skip without error
- [ ] Mixed success/failure (some INFs succeed, some fail) — DISM method lists failures

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| DISM log parsing fails to extract INF names | Medium | Low | Fallback: log raw error count if extraction fails |
| Old config files missing `UseDismRecurse` key | High | Low | Default to `$false` (PowerShell loop) |
| DISM `/Recurse` behaves differently across OS versions | Low | Medium | Test on Windows 10/11 (22H2, 23H2, 24H2, 25H2) |
| User confusion about which method to use | Medium | Low | Tooltip or help text: "DISM is faster for large driver sets" |

---

## Success Criteria (From Scribe Plan)

1. ✅ Driver tab has checkbox: "Use Fast DISM Recursive Injection"
2. ✅ Existing PowerShell loop method still works
3. ✅ New DISM recursive method:
   - Calls `dism.exe /Add-Driver /Recurse /LogPath /LogLevel:3`
   - Uses existing log directory
   - Does not halt on failures
   - Parses log for failed INFs
   - Displays failures to user
4. ✅ Success message when all drivers succeed
5. ✅ User can switch methods; both work correctly
6. ✅ Configuration files save/load the method choice

---

## Consent Gate

**This plan is ready for implementation pending approval.**

**Approver:** Eden Nelson
**Approval Date:** _[Pending]_
**Approval Method:** Explicit confirmation in chat or via `/approve` command

**Changes Since Scribe Plan:**
- Added edge case handling for old config files
- Specified DISM log parsing regex pattern
- Defined Warning class for failure logs (consistency with `Install-Driver`)

---

## References

- **Scribe Plan:** [scribe-plan-20260130-driverInjection.md](scribe-plan-20260130-driverInjection.md)
- **DISM Documentation:** [Microsoft Docs - DISM Driver Servicing](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-and-remove-drivers-to-an-offline-windows-image)
- **Existing Functions:**
  - [Start-DriverInjection.ps1](../../WIMWitch-tNG/Private/Functions/Drivers/Start-DriverInjection.ps1)
  - [Install-Driver.ps1](../../WIMWitch-tNG/Private/Functions/Drivers/Install-Driver.ps1)
  - [Invoke-MakeItSo.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Invoke-MakeItSo.ps1)
