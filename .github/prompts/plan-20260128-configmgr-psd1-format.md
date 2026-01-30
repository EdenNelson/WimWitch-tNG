# PLAN: Fix ConfigMgr Data File Format (XML → PSD1)

**Date:** January 28, 2026
**Status:** Pending Approval
**Scope:** Bug fix; non-breaking (internal data format change)
**Priority:** High (regression from 10 days ago)

---

## Problem Statement

ConfigMgr package settings files are being saved as XML (via `Export-Clixml`) instead of PSD1 format. This is a regression—the code was working 10 days ago and now defaults back to XML serialization.

**Impact:**

- ConfigMgr workflow broken for users creating/updating images
- Files saved with `.xml` extension and CLIXML binary format
- Expected `.psd1` format with PowerShell hashtable syntax
- Incompatible with configuration loading logic that expects PSD1

---

## Analysis & Assessment

### Root Cause

In `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`, the `Save-Configuration` function has two code paths:

1. **Standard config save** (line ~95-127): Correctly serializes to PSD1 format
   - Builds hashtable syntax manually
   - Handles data types: booleans, integers, arrays, null, strings
   - Saves with `Set-Content`
   - Produces valid `.psd1` file

2. **ConfigMgr package save** (line ~132-225): Incorrectly uses XML serialization
   - Uses `Export-Clixml` cmdlet
   - Saves binary XML format
   - Uses `$filename` directly without extension conversion
   - **This is the bug**

### Why It Broke

The ConfigMgr save path was likely refactored or reverted without updating to match the PSD1 serialization logic. The standard config path has the correct implementation; the ConfigMgr path was left behind.

### Options Considered

1. **Option A (Preferred):** Replace ConfigMgr save logic with PSD1 serialization
   - Reuse the same hashtable-to-PSD1 conversion logic as standard config
   - Ensure filename uses `.psd1` extension
   - Consistent with standard config behavior
   - Low risk; proven pattern already in code

2. **Option B:** Keep XML but fix extension
   - Change `Export-Clixml` output to `.xml`
   - Does not fix the actual problem (format is still wrong)
   - Rejected: breaks PSD1 expectation

3. **Option C:** Dual support (XML → PSD1 migration)
   - Read both formats, write only PSD1
   - Too complex; users need immediate fix
   - Rejected: over-engineered

**Selected:** Option A (reuse PSD1 logic)

### Risk Assessment

**Low Risk:**

- Same serialization pattern already tested in standard config path
- Only affects ConfigMgr package info saves (not critical path)
- Can be tested with ConfigMgr workflow
- Rollback is trivial (restore original code)

**Trade-offs:**

- None; this is a pure bug fix

---

## Plan

### STAGE 1: Update Save-Configuration Function

**Objective:** Replace ConfigMgr XML save logic with PSD1 serialization

**Location:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`, lines ~205-225

**Changes:**

1. In the ConfigMgr else block, replace `Export-Clixml` call (current line 221)
2. Add filename extension normalization: `[System.IO.Path]::ChangeExtension($filename, '.psd1')`
3. Copy PSD1 serialization logic from standard config section (lines ~115-127)
4. Update log message to confirm PSD1 format

**Current Code (BROKEN - line 221-225):**

```powershell
try {
    $CurrentConfig | Export-Clixml -Path $global:workdir\ConfigMgr\PackageInfo\$filename -Force -ErrorAction Stop
    Update-Log -data 'file saved' -Class Information
} catch {
    Update-Log -data "Couldn't save file" -Class Error
}
```

**After (PSD1 - FIXED):**

```powershell
try {
    # Ensure filename has .psd1 extension
    if ($filename -notmatch '\.psd1$') {
        $filename = [System.IO.Path]::ChangeExtension($filename, '.psd1')
    }

    # Save as PSD1 format (PowerShell Data File)
    $PSD1Lines = @('@{')
    foreach ($key in $CurrentConfig.Keys | Sort-Object) {
        $value = $CurrentConfig[$key]
        $formattedValue = if ($null -eq $value) {
            '$null'
        } elseif ($value -is [bool]) {
            if ($value) { '$true' } else { '$false' }
        } elseif ($value -is [int]) {
            $value
        } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
            $items = @($value | ForEach-Object {
                if ($_ -is [string]) {
                    "'$($_ -replace "'", "''")'"
                } else {
                    "'$($_.ToString() -replace "'", "''")'"
                }
            })
            if ($items.Count -eq 0) { '@()' } else { "@($($items -join ', '))" }
        } else {
            "'$($value.ToString() -replace "'", "''")'"
        }
        $PSD1Lines += "    $key = $formattedValue"
    }
    $PSD1Lines += '}'
    $PSD1Content = $PSD1Lines -join "`r`n"
    Set-Content -Path "$global:workdir\ConfigMgr\PackageInfo\$filename" -Value $PSD1Content -ErrorAction Stop
    Update-Log -data "ConfigMgr Image info saved as PSD1: $filename" -Class Information
} catch {
    Update-Log -data "Couldn't save file: $($_.Exception.Message)" -Class Error
}
```

**Deliverable:** Modified `Save-Configuration.ps1` with PSD1 serialization in ConfigMgr save path

**Checkpoint:** File edits complete, syntax verified

---

### STAGE 2: Validation

**Objective:** Verify ConfigMgr files now save as PSD1

**Tests:**

1. Code review: Verify serialization logic matches standard config path
2. Syntax check: Ensure no PowerShell syntax errors
3. Integration: Verify `Save-Configuration` function still callable
4. Expected output: Sample ConfigMgr save produces valid `.psd1` file with hashtable syntax

**Checkpoint:** No syntax errors, file structure correct

---

## Consent Gate

**Breaking Change?** No

- Internal data format change
- Users will not be affected (old XML files are discarded; new saves use PSD1)
- ConfigMgr workflow continues to work

**User Action Required?** No

- Backward compatibility: Old XML files can be ignored
- Forward compatibility: New PSD1 files will work with existing loading logic

**Approval Requested:** ✓ Proceed with Option A (reuse PSD1 logic)

---

## References

- **File:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`
- **Function:** `Save-Configuration` (lines 1-312 total; target: lines 205-225)
- **Related:** `WIMWitch-tNG/Private/Functions/Configuration/Convert-ConfigMgrXmlToPsd1.ps1` - already handles XML→PSD1 migration
- **Standards:** STANDARDS_POWERSHELL.md, PROJECT_CONTEXT.md

---

## Persistence & Recovery

If session crashes during implementation:

1. Read this plan artifact: `.github/prompts/plan-20260128-configmgr-psd1-format.md`
2. Current stage: Check which checkpoint was completed
3. Resume from next incomplete stage
4. All changes are isolated to one function (low complexity)

---

**Prepared by:** Pragmatic Architect
**Awaiting approval to proceed with Stage 1**
