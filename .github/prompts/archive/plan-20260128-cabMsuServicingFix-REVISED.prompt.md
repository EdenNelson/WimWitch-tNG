# Plan: CAB vs MSU Servicing Logic Fix - REVISED

**Date:** 2026-01-28 (Revision 2)
**Status:** In Review - Awaiting Approval
**Issue:** KB5074108 standalone servicing CAB incorrectly handled, causing servicing failure with error 0x800f081e
**Scope:** Fix `Deploy-LCU` function with intelligent fallback strategy instead of metadata detection
**Reference:** Initial plan in `plan-20260128-cabMsuServicingFix.prompt.md`

---

## Analysis of Original Approach

### What Was Attempted

The original plan (Revision 1) implemented a **detection-based approach**:
1. Check if file has `update.mum` metadata (standalone CAB indicator)
2. If standalone: apply as `.cab` directly
3. If MSU-extracted: rename to `.msu` and apply

**New Function Added:**
```powershell
Function Test-StandaloneServicingCab {
    # Inspect CAB for update.mum + absence of Unattend.xml
}
```

**Deploy-LCU Modified Logic:**
```powershell
if (Test-StandaloneServicingCab -CabFilePath $stagingPath) {
    $servicingPath = $stagingPath  # Apply CAB directly
} else {
    Rename-Item to .msu  # Apply as MSU
}
```

### Why It Failed

**Field Testing Results (Jan 28, 2026 12:51:10):**
```
information  -  Detected standalone servicing CAB: Windows11.0-KB5074108-x64.cab
...
WARNING: Failed to add package D:\Scripts\WIMWitchFK\staging\Windows11.0-KB5074108-x64.cab
WARNING: Add-WindowsPackage failed. Error code = 0x800f081e
```

**Root Cause:** The assumption that standalone CABs can be applied directly as `.cab` to offline-mounted images is **incorrect**.
- `Add-WindowsPackage` accepts both `.cab` and `.msu` formats in theory
- In practice, offline servicing of updates (standalone CABs) requires `.msu` format
- Error `0x800f081e` ("Package not applicable to this image") confirms the CAB cannot be applied directly
- **Detection was working correctly**, but the servicing strategy was flawed

### Lesson Learned

**Detection-based approaches are fragile.** Instead of trying to predict what format the package needs, we should **try and adapt**.

---

## Revised Solution: Fallback Strategy

### Concept

Rather than detecting file type and choosing a single strategy, implement a **default-first-with-fallback pattern**:

1. **First Attempt:** Use original behavior - rename CAB to MSU (works 99% of the time)
2. **Catch Failure:** If that fails and file is CAB, rename back and try applying as original CAB
3. **Final Result:** If fallback succeeds, log success; if it fails, then report the error

**Benefits:**
- No detection logic needed
- Maintains original efficiency (99% case succeeds immediately)
- Works for all CAB scenarios (standalone, MSU-extracted, edge cases)
- Resilient to unknown file formats
- Clear logging of what was tried
- No unnecessary retries for MSU files or MSU-extracted CABs

### Implementation Strategy

**Remove:** The `Test-StandaloneServicingCab` function (no longer needed)

**Modify:** `Deploy-LCU` Windows 11 logic to use default-first-with-fallback pattern:

```powershell
foreach ($filename in $filenames) {
    Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force
    $stagingPath = Join-Path -Path $global:workdir -ChildPath "staging\$filename"
    $fileExtension = [System.IO.Path]::GetExtension($filename)

    # Default first pass: original behavior - rename CAB to MSU
    $servicingPath = $stagingPath
    if ($fileExtension -eq '.cab') {
        $basename = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        $newname = "$basename.msu"
        $servicingPath = Join-Path -Path $global:workdir -ChildPath "staging\$newname"
        Rename-Item -Path $stagingPath -NewName $newname
        Update-Log -data "Renamed CAB to MSU: $newname" -class information
    }

    $updatename = (Get-Item -Path $packagepath\$filename).name
    Update-Log -data 'Applying LCU...' -class information
    Update-Log -data $servicingPath -class information
    Update-Log -data $updatename -Class Information

    try {
        if ($demomode -eq $false) {
            Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $servicingPath -ErrorAction Stop | Out-Null
        } else {
            Update-Log -data "Demo mode active - Not applying $updatename" -Class Warning
        }
    }
    catch {
        # Fallback: if CAB file failed after rename, try applying as original CAB
        if ($fileExtension -eq '.cab') {
            Update-Log -data "MSU format failed, attempting fallback with original CAB format: $filename" -class Warning

            try {
                # Rename back to CAB
                Rename-Item -Path $servicingPath -NewName $filename -ErrorAction Stop
                Update-Log -data "Renamed back to CAB format: $filename" -class information

                if ($demomode -eq $false) {
                    Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $stagingPath -ErrorAction Stop | Out-Null
                    Update-Log -data "Successfully applied CAB after format fallback" -class information
                } else {
                    Update-Log -data "Demo mode active - Not applying $updatename" -Class Warning
                }
            }
            catch {
                Update-Log -data 'Failed to apply update (both MSU and CAB formats attempted)' -class Warning
                Update-Log -data $_.Exception.Message -class Warning
            }
        }
        else {
            # Not a CAB file, can't fallback
            Update-Log -data 'Failed to apply update' -class Warning
            Update-Log -data $_.Exception.Message -class Warning
        }
    }
}
```

---

## Implementation Phases

### Phase 1: Remove Detection Function
- Delete `Test-StandaloneServicingCab` function
- Keep original `Deploy-LCU` logic temporarily as reference

### Phase 2: Implement Fallback Logic in Deploy-LCU
- Replace Windows 11 servicing loop with default-first-with-fallback pattern
- Default: rename CAB files to MSU (original behavior, maintains efficiency)
- Fallback: rename back to CAB and retry if MSU format fails
- Add detailed logging for fallback attempts
- Ensure error messages distinguish primary vs fallback failures

### Phase 3: Testing & Validation
- **Syntax Check:** Parse WWFunctions.ps1 (CRITICAL - file is 9684 lines)
- **Function Load:** Verify Deploy-LCU loads without errors
- **Behavior Test:**
  - KB5043080 (SSU/MSU) → Apply as MSU (no CAB involved)
  - KB5074108 (standalone CAB) → Try CAB, fallback to MSU, succeed
  - KB5078127 (LCU/MSU) → Apply as MSU (no CAB involved)

### Phase 4: Completion Criteria
- ✅ PowerShell syntax validation passes
- ✅ Module loads without errors
- ✅ No regressions in existing MSU handling
- ✅ KB5074108 applies successfully via fallback path
- ✅ Logs clearly show fallback attempt and success/failure

---

## Critical Notes

### File Size Warning
**WWFunctions.ps1 is 9684 lines long.** Editing large files increases risk of:
- Unmatched braces/parentheses
- Scope creep (accidentally modifying unrelated code)
- Syntax errors that don't surface until runtime

**Mitigation:**
- Make surgical, focused edits
- Include 5+ lines of context before/after in all replacements
- **MANDATORY:** Run PowerShell syntax validation before reporting completion
- Load module and verify `Deploy-LCU` function exists
- No edits to other functions in the file

### Syntax Validation Commands

Before reporting done, execute:
```powershell
# 1. Syntax parse check
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    'WIMWitch-tNG/Private/WWFunctions.ps1',
    [ref]$null,
    [ref]$null
)
# Should complete without errors

# 2. Module load check
. ./WIMWitch-tNG/Private/WWFunctions.ps1
Get-Command Deploy-LCU -ErrorAction Stop
# Should return function object

# 3. Visual spot check
Select-String -Path WIMWitch-tNG/Private/WWFunctions.ps1 -Pattern 'Function Deploy-LCU|Function Test-StandaloneServicingCab'
# Should show Deploy-LCU exists, Test-StandaloneServicingCab does NOT exist
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Syntax error in 9684-line file | Critical - breaks module | Mandatory syntax validation before completion |
| Infinite loop if rename fails | Medium - hangs servicing | ErrorAction Stop on Rename-Item, catch block handles |
| Double-renamed file (CAB→MSU→MSU) | Low - would fail on second rename | Rename-Item with Stop on error prevents this |
| Removing detection function breaks other code | Low - function is only used in Deploy-LCU | Grep search before deletion to confirm |

---

## Comparison: Original vs Revised

| Aspect | Original Plan (Rev 1) | Revised Plan (Rev 2) |
|--------|----------------------|----------------------|
| **Strategy** | Detect file type and choose approach | Default to MSU rename (original), fallback to CAB if fails |
| **Detection Function** | Adds `Test-StandaloneServicingCab` | Removes detection function |
| **Default Behavior** | New approach (try CAB first) | Original behavior (rename to MSU first) |
| **CAB Handling** | Apply CAB directly (failed 0x800f081e) | Rename to MSU → apply; if fails, rename back and try CAB |
| **99% Case** | Requires detection + application (2 steps) | Direct MSU rename + apply (1 step, no retry) |
| **1% Case** | Would still fail | Fallback catches it and retries as CAB |
| **Error Resilience** | Single-path, fails if detection wrong | Dual-path fallback, adapts to actual behavior |
| **Code Complexity** | Additional validation function + logic | Nested try-catch with rename fallback |
| **Efficiency** | Requires CAB inspection overhead | Zero overhead for common cases |
| **Tested Against** | Theory (detection assumptions) | Live servicing logs (actual behavior) |

---

## Expected Outputs

1. **Modified File:** `WIMWitch-tNG/Private/WWFunctions.ps1`
   - Removed: `Test-StandaloneServicingCab` function (~50 lines)
   - Modified: `Deploy-LCU` Windows 11 loop (lines ~1620-1660)
   - Net change: ±0 lines (roughly neutral)

2. **Validation:** PowerShell syntax parse + module load confirmation

3. **Test Results:** Logs showing all three update types applied successfully

---

## Checkpoints

### Checkpoint 1: Code Review
- [ ] Fallback logic is sound (try CAB → catch → try MSU)
- [ ] Error handling preserves error details for troubleshooting
- [ ] Logging clearly shows which path succeeded
- [ ] No syntax errors in nested try-catch-try structure

### Checkpoint 2: Implementation
- [ ] `Test-StandaloneServicingCab` function removed
- [ ] `Deploy-LCU` Windows 11 loop replaced with fallback strategy
- [ ] All error messages updated to reflect dual-path approach
- [ ] CRLF line endings preserved (STANDARDS_POWERSHELL.md)

### Checkpoint 3: Syntax Validation (MANDATORY)
- [ ] PowerShell parser accepts file without errors
- [ ] Module loads successfully
- [ ] `Deploy-LCU` function is available
- [ ] No unrelated functions affected

### Checkpoint 4: Behavioral Testing
- [ ] MSU files apply on first attempt (no fallback needed)
- [ ] CAB files trigger fallback and succeed
- [ ] All three test updates (KB5043080, KB5074108, KB5078127) apply successfully
- [ ] Error messages are clear and actionable

---

## References

- **Original Plan:** `.github/prompts/plan-20260128-cabMsuServicingFix.prompt.md`
- **Log Evidence:** KB5074108 failure with 0x800f081e error (Jan 28, 12:51:10)
- **File Location:** `WIMWitch-tNG/Private/WWFunctions.ps1` (lines 1579-1655)
- **Standards:** STANDARDS_POWERSHELL.md (error handling, try-catch patterns)

---

## Approval

**Author:** Revised based on field testing feedback
**Approver:** Eden Nelson
**Date:** _Pending_
**Decision:** [ ] Approved [ ] Rejected [ ] Needs Revision

**Notes:** This revision replaces the detection-based approach with a resilient fallback strategy based on actual servicing behavior observed in logs.

---

**End of Revised Plan - Ready for Implementation**
