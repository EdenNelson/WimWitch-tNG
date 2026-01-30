# Plan: CAB vs MSU Servicing Logic Fix

**Date:** 2026-01-28
**Status:** Draft - Awaiting Approval
**Issue:** KB5074108 standalone servicing CAB incorrectly renamed to MSU, causing servicing failure
**Scope:** Fix `Deploy-LCU` function to distinguish standalone CABs from MSU-extracted CABs

---

## Analysis

### Problem Statement

The `Deploy-LCU` function (in [WIMWitch-tNG/Private/Functions/Updates/Deploy-LCU.ps1](../../WIMWitch-tNG/Private/Functions/Updates/Deploy-LCU.ps1)) blindly renames ALL files from `.cab` to `.msu` without checking the file's original format or structure. This causes servicing failures when legitimate standalone servicing CABs (like KB5074108) are processed.

**Evidence from Log:**
```
01/27/2026 16:03:54 Information  -  CAB file validation passed - update.mum metadata found (via COM)
...
01/27/2026 16:17:54 information  -  Changing file extension type from CAB to MSU...
01/27/2026 16:17:54 Information  -  Windows11.0-KB5074108-x64.cab
01/27/2026 16:18:12 Warning  -  Failed to apply update
01/27/2026 16:18:12 Warning  -  Unable to find the Unattend.xml file in the expanded .msu package.
```

**Validation:**
```powershell
expand -D "...\Windows11.0-KB5074108-x64.cab" | Select-String "Unattend.xml|update.mum"
# Result: Contains update.mum only (standalone CAB, NOT extracted from MSU)
```

### Root Cause

1. **Download Phase (Smart):** Correctly validates CAB files for `update.mum` metadata and accepts standalone servicing CABs as valid offline-serviceable packages
2. **Servicing Phase (Naive):** Assumes all CAB files were extracted from MSU packages and need to be renamed back to `.msu` for servicing
3. **The Disconnect:** Download phase says "this standalone CAB is good," but servicing phase doesn't distinguish standalone CABs from MSU-extracted CABs

### Affected Code

**File:** `WIMWitch-tNG/Private/Functions/Updates/Deploy-LCU.ps1`
**Function:** `Deploy-LCU`
**Problematic Logic:** The foreach loop that renames all CAB files to MSU

```powershell
foreach ($filename in $filenames) {
    Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force

    Update-Log -data 'Changing file extension type from CAB to MSU...' -class information
    $basename = (Get-Item -Path $global:workdir\staging\$filename).BaseName
    $newname = $basename + '.msu'
    Rename-Item -Path $global:workdir\staging\$filename -NewName $newname  # ← BUG HERE

    # Then tries to apply as MSU (fails for standalone CABs)
    Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $global:workdir\staging\$newname -ErrorAction Stop
}
```

### Impact

- **Severity:** High - Blocks servicing of valid standalone CAB updates
- **Scope:** Windows 11 LCU deployment (potentially affects other update classes)
- **Workaround:** None for end users; updates fail silently or with cryptic errors

---

## Assessment

### Update File Type Classification

Based on download phase logic and Windows servicing requirements:

| File Type | Extension | Structure | Servicing Method |
|-----------|-----------|-----------|------------------|
| MSU Package | `.msu` | Contains CAB + Unattend.xml + metadata | Apply as `.msu` |
| Standalone Servicing CAB | `.cab` | Contains `update.mum` metadata | Apply as `.cab` |
| MSU-Extracted CAB | `.cab` | Extracted from MSU, lacks wrapper | Reassemble to `.msu` or apply original MSU |
| Express CAB | `.cab` (suffix: `-express.cab`) | Requires online servicing | Skip (already filtered by download) |
| Baseless CAB | `.cab` (suffix: `-baseless.cab`) | Requires baseline installed | Skip (already filtered by download) |

### Current Behavior vs Expected Behavior

| Scenario | Current Behavior | Expected Behavior |
|----------|------------------|-------------------|
| MSU file downloaded | Rename CAB→MSU (works by accident) | Apply MSU directly |
| Standalone CAB downloaded | Rename CAB→MSU (FAILS) | Apply CAB directly |
| MSU-extracted CAB | Rename CAB→MSU (works if reassembled correctly) | Apply original MSU or reassembled MSU |

### Solution Options

#### Option 1: File Extension Detection (Naive)
**Approach:** Check file extension; apply MSU as MSU, CAB as CAB.
**Pros:** Simple, minimal code change
**Cons:** Doesn't handle MSU-extracted CABs correctly; assumes download phase never extracts MSUs

#### Option 2: Metadata Validation (Robust)
**Approach:** Inspect each file for MSU structure (Unattend.xml presence) vs CAB structure (update.mum only).
**Pros:** Accurate detection, handles all edge cases
**Cons:** Requires file inspection (expand/COM validation), adds processing overhead

#### Option 3: Download Phase Tagging (Optimal)
**Approach:** Have download phase tag/track original file format; servicing phase reads tags.
**Pros:** No redundant validation, accurate, efficient
**Cons:** Requires cross-function state tracking (metadata file or naming convention)

### Recommended Approach

**Hybrid: Extension Detection + Metadata Validation Fallback**

1. **Primary Check:** If file extension is `.msu`, apply as MSU directly
2. **CAB Files:** Validate whether it's a standalone CAB (contains `update.mum`, no wrapper) or MSU-extracted CAB
3. **Standalone CAB:** Apply as `.cab` directly
4. **MSU-Extracted CAB:** Rename to `.msu` (current behavior, keep for backward compatibility)

**Rationale:**
- Leverages existing download phase validation (already checks for `update.mum`)
- Minimal performance impact (only validates CAB files)
- Backward compatible with existing update folder structures
- No cross-function state tracking required

---

## Stages

### Stage 1: Add CAB Validation Helper Function

**Objective:** Create reusable function to detect standalone servicing CABs vs MSU-extracted CABs.

**Implementation:**
```powershell
Function Test-StandaloneServicingCab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CabFilePath
    )

    # Validate file exists and is a CAB
    if (-not (Test-Path -Path $CabFilePath)) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($CabFilePath)
    if ($extension -ne '.cab') {
        return $false
    }

    # Check for update.mum (servicing metadata) without Unattend.xml (MSU wrapper indicator)
    try {
        $cabContents = & expand -D $CabFilePath 2>&1
        $hasUpdateMum = $cabContents -match 'update\.mum'
        $hasUnattend = $cabContents -match 'Unattend\.xml'

        # Standalone servicing CAB: has update.mum, no Unattend.xml
        return ($hasUpdateMum -and -not $hasUnattend)
    }
    catch {
        Write-Verbose "Failed to inspect CAB contents: $_"
        return $false
    }
}
```

**Location:** Insert after `Deploy-LCU` function definition (around line 1655)

**Success Criteria:**
- Function returns `$true` for KB5074108 (standalone CAB with update.mum)
- Function returns `$false` for MSU-extracted CABs (contains Unattend.xml)
- Function returns `$false` for non-CAB files

### Stage 2: Refactor Deploy-LCU File Processing Logic

**Objective:** Replace blind CAB→MSU rename with intelligent file type detection.

**Current Logic (lines 1623-1638):**
```powershell
foreach ($filename in $filenames) {
    Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force

    Update-Log -data 'Changing file extension type from CAB to MSU...' -class information
    $basename = (Get-Item -Path $global:workdir\staging\$filename).BaseName
    $newname = $basename + '.msu'
    Rename-Item -Path $global:workdir\staging\$filename -NewName $newname

    Update-Log -data 'Applying LCU...' -class information
    Update-Log -data $global:workdir\staging\$newname -class information

    Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $global:workdir\staging\$newname -ErrorAction Stop
}
```

**New Logic:**
```powershell
foreach ($filename in $filenames) {
    Copy-Item -Path $packagepath\$filename -Destination $global:workdir\staging -Force
    $stagingPath = Join-Path -Path $global:workdir -ChildPath "staging\$filename"
    $fileExtension = [System.IO.Path]::GetExtension($filename)

    # Determine servicing file path based on file type
    if ($fileExtension -eq '.msu') {
        # MSU file: apply directly, no rename needed
        $servicingPath = $stagingPath
        Update-Log -data "Applying MSU package: $filename" -class information
    }
    elseif ($fileExtension -eq '.cab') {
        # CAB file: check if standalone or MSU-extracted
        if (Test-StandaloneServicingCab -CabFilePath $stagingPath) {
            # Standalone servicing CAB: apply as-is
            $servicingPath = $stagingPath
            Update-Log -data "Applying standalone servicing CAB: $filename" -class information
        }
        else {
            # MSU-extracted CAB: rename to MSU for servicing
            Update-Log -data "Converting MSU-extracted CAB to MSU: $filename" -class information
            $basename = [System.IO.Path]::GetFileNameWithoutExtension($filename)
            $newname = "$basename.msu"
            $servicingPath = Join-Path -Path $global:workdir -ChildPath "staging\$newname"
            Rename-Item -Path $stagingPath -NewName $newname
        }
    }
    else {
        # Unknown file type: log and skip
        Update-Log -data "Skipping unsupported file type: $filename" -class Warning
        continue
    }

    Update-Log -data "Servicing package path: $servicingPath" -class information

    try {
        if ($demomode -eq $false) {
            Add-WindowsPackage -Path $WPFMISMountTextBox.Text -PackagePath $servicingPath -ErrorAction Stop | Out-Null
        }
        else {
            Update-Log -data "Demo mode active - Not applying $filename" -Class Warning
        }
    }
    catch {
        Update-Log -data 'Failed to apply update' -class Warning
        Update-Log -data $_.Exception.Message -class Warning
    }
}
```

**Success Criteria:**
- KB5074108 (standalone CAB) is applied as `.cab` without renaming
- MSU files (KB5043080, KB5078127) are applied directly as `.msu`
- MSU-extracted CABs (if present) are renamed to `.msu` and applied
- No regression in existing update deployment scenarios

### Stage 3: Update Logging for Transparency

**Objective:** Enhance logging to show file type detection decisions.

**Changes:**
- Log file type detection: "Detected standalone servicing CAB" vs "Detected MSU-extracted CAB"
- Log servicing method: "Applying as CAB" vs "Applying as MSU"
- Preserve existing log format for backward compatibility

**Success Criteria:**
- Logs clearly show why each file was handled in a specific way
- No breaking changes to log parsing (if any automation depends on it)

### Stage 4: Testing & Validation

**Objective:** Verify fix resolves KB5074108 issue without breaking existing functionality.

**Test Cases:**

1. **Standalone Servicing CAB (KB5074108)**
   - Input: `Windows11.0-KB5074108-x64.cab`
   - Expected: Applied as `.cab`, no rename, no "Unattend.xml not found" error
   - Validation: Check DISM log for successful package installation

2. **MSU Package (KB5078127)**
   - Input: `Windows11.0-KB5078127-x64.msu`
   - Expected: Applied directly as `.msu`, no rename
   - Validation: Check DISM log for successful package installation

3. **Legacy SSU (KB5043080)**
   - Input: `Windows11.0-KB5043080-x64.msu`
   - Expected: Applied directly as `.msu`, no rename
   - Validation: Check DISM log for successful package installation

4. **Mixed Update Folder**
   - Input: Folder containing MSU, standalone CAB, and MSU-extracted CAB
   - Expected: Each file type handled correctly based on structure
   - Validation: All valid updates applied, appropriate logging

**Rollback Strategy:**
- Keep original `Deploy-LCU` function as `Deploy-LCU-Legacy` (commented out)
- If regression detected, revert to legacy logic and re-analyze

---

## Checkpoints

### Checkpoint 1: Function Design Review
- [ ] `Test-StandaloneServicingCab` function signature approved
- [ ] Metadata validation approach confirmed (expand vs COM vs hybrid)
- [ ] Error handling strategy defined

### Checkpoint 2: Code Implementation
- [ ] `Test-StandaloneServicingCab` function implemented
- [ ] `Deploy-LCU` refactored with new logic
- [ ] Logging enhancements applied
- [ ] STANDARDS_POWERSHELL.md compliance verified (CRLF, UTF-8, explicit parameters)

### Checkpoint 3: Pre-Deployment Testing
- [ ] Test Case 1 (KB5074108 standalone CAB) passed
- [ ] Test Case 2 (KB5078127 MSU) passed
- [ ] Test Case 3 (KB5043080 SSU MSU) passed
- [ ] Test Case 4 (mixed update folder) passed
- [ ] No regressions in existing update scenarios

### Checkpoint 4: Documentation
- [ ] CHANGELOG.md updated with bug fix entry
- [ ] Code comments added explaining CAB vs MSU detection logic
- [ ] Update troubleshooting guide (if exists) with file type detection details

---

## Expected Outputs

1. **Modified File:** `WIMWitch-tNG/Private/Functions/Updates/Deploy-LCU.ps1`
   - New function: `Test-StandaloneServicingCab` (~30 lines)
   - Modified function: `Deploy-LCU` (foreach loop for CAB processing, replaced with ~50 lines)
   - Total net change: +50 lines

2. **Updated Documentation:** `CHANGELOG.md`
   - Bug fix entry for KB5074108 servicing failure
   - Technical explanation of CAB vs MSU detection logic

3. **Test Results:** Validation log showing all test cases passed

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `expand` command unavailable on some systems | High - function fails | Add fallback to COM validation (existing download logic) |
| MSU-extracted CABs misidentified as standalone | Medium - servicing failure | Add additional checks (file size, naming convention) |
| Performance degradation from file inspection | Low - minor delay | Limit validation to CAB files only; MSUs bypass check |
| Regression in legacy update scenarios | High - breaks existing functionality | Comprehensive test suite, rollback plan |

---

## References

- **Existing Download Validation Logic:** WWFunctions.ps1 lines 1122-1145 (CAB update.mum validation)
- **Microsoft DISM Documentation:** Add-WindowsPackage supports both CAB and MSU formats
- **SPEC_PROTOCOL.md:** Section 2.2 - Hard Gate workflow for architectural changes
- **STANDARDS_POWERSHELL.md:** Section on error handling, logging, and parameter usage

---

## Approval

**Approver:** Eden Nelson
**Date:** _Pending_
**Decision:** [ ] Approved [ ] Rejected [ ] Needs Revision

**Notes:**

---

**End of Plan - Awaiting Approval**
