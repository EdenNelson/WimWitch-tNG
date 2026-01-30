# Plan: Working Directory Path Consistency Fix

**Date:** 2026-01-28
**Type:** Bug Fix
**Priority:** High
**Status:** Pending Approval

---

## 1. PROBLEM STATEMENT

### Primary Issue

Configuration file loads blindly overwrite working directory-based paths with saved absolute paths, causing the application to use incorrect directories when the working directory changes between sessions.

### User Impact

- Mount directory defaults to `D:\Scripts\WimWitch\Mount\` regardless of configured working directory
- Completed WIMs output to wrong location
- Autopilot profiles save to wrong location
- Breaks portability across different systems/users
- Multiple attempted fixes failed due to scope misunderstanding

### Evidence

**Initialization (WIMWitch-tNG.ps1:533-535):**

```powershell
$WPFMISWimFolderTextBox.Text = "$global:workdir\CompletedWIMs"  # Correct
$WPFMISMountTextBox.Text = "$global:workdir\Mount"              # Correct
$WPFJSONTextBoxSavePath.Text = "$global:workdir\Autopilot"      # Correct
```

**Config Save ([Save-Configuration](WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1)):**

```powershell
WIMPath          = $WPFMISWimFolderTextBox.text   # Saves absolute path
MountPath        = $WPFMISMountTextBox.text        # Saves absolute path
```

**Config Load ([Save-Configuration](WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1)):**

```powershell
$WPFMISWimFolderTextBox.text = $settings.WIMPath   # Overwrites with absolute path
$WPFMISMountTextBox.text = $settings.MountPath     # Overwrites with absolute path
```

**Result:** Legacy configs with `D:\Scripts\WimWitch\Mount` overwrite correct `C:\MyWorkDir\Mount`

---

## 2. ROOT CAUSE ANALYSIS

### Design Flaw

Configs store **absolute paths** instead of **relative paths** or **path components**.

### Affected Paths

1. **Mount Path** (`$WPFMISMountTextBox.Text`)
   - Init: `$global:workdir\Mount`
   - Saved as: Absolute path (e.g., `D:\Scripts\WimWitch\Mount`)
   - Loaded: Overwrites correct value

2. **Completed WIMs Path** (`$WPFMISWimFolderTextBox.Text`)
   - Init: `$global:workdir\CompletedWIMs`
   - Saved as: Absolute path
   - Loaded: Overwrites correct value

3. **Autopilot Save Path** (`$WPFJSONTextBoxSavePath.Text`)
   - Init: `$global:workdir\Autopilot`
   - Not saved/loaded in config (different issue)

4. **Other Paths NOT Affected:**
   - Driver paths (user-selected, should remain absolute)
   - Source WIM path (user-selected, should remain absolute)
   - Custom script paths (user-selected, should remain absolute)

---

## 3. SOLUTION DESIGN

### Strategy: Path Normalization on Config Load

**Principle:** Working directory-relative paths must ALWAYS be recomputed based on current `$global:workdir`, never loaded from saved configs.

### Approach A: Auto-Correct on Load (RECOMMENDED)

After loading config, detect and fix paths that should be working directory-relative:

- If loaded path is absolute AND ends with known subdirectory (`\Mount`, `\CompletedWIMs`), replace with `$global:workdir\<subdir>`
- Log the correction for user awareness
- Preserves all other config settings

### Approach B: Omit from Config (Breaking Change)

- Remove `MountPath` and `WIMPath` from config save/load
- Always initialize from `$global:workdir`
- **Rejected:** Breaks existing configs, loses user customizations

### Selected: Approach A

---

## 4. IMPLEMENTATION PLAN

### Stage 1: Add Path Normalization Function

**Location:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1` (new helper function before config load logic)

**Function:**

```powershell
Function Repair-WorkingDirectoryPath {
    <#
    .SYNOPSIS
        Corrects working directory-relative paths loaded from configuration files.

    .DESCRIPTION
        Detects paths that should be relative to $global:workdir but were saved as
        absolute paths in legacy configurations. Replaces them with correct paths
        based on current working directory.

    .PARAMETER Path
        The path to evaluate and potentially correct.

    .PARAMETER Subdirectory
        The expected subdirectory name (Mount, CompletedWIMs, Autopilot).

    .OUTPUTS
        System.String. Corrected path or original path if correction not needed.
    #>
    param(
        [string]$Path,
        [string]$Subdirectory
    )

    # If path is empty or null, return working directory default
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return Join-Path -Path $global:workdir -ChildPath $Subdirectory
    }

    # If path ends with expected subdirectory, replace with current workdir
    if ($Path -match "\\$Subdirectory`$") {
        $correctedPath = Join-Path -Path $global:workdir -ChildPath $Subdirectory
        if ($Path -ne $correctedPath) {
            Update-Log -Data "Config path corrected: $Subdirectory ($Path -> $correctedPath)" -Class Warning
        }
        return $correctedPath
    }

    # Path is user-customized (not standard subdirectory), preserve it
    return $Path
}
```

### Stage 2: Modify Get-Configuration Function

**Location:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1` (config load section)

**Change:**
Replace direct assignment with normalization:

```powershell
# Before:
$WPFMISWimFolderTextBox.text = $settings.WIMPath
$WPFMISMountTextBox.text = $settings.MountPath

# After:
$WPFMISWimFolderTextBox.text = Repair-WorkingDirectoryPath -Path $settings.WIMPath -Subdirectory 'CompletedWIMs'
$WPFMISMountTextBox.text = Repair-WorkingDirectoryPath -Path $settings.MountPath -Subdirectory 'Mount'
```

### Stage 3: Testing & Validation

1. Create test config with legacy absolute paths
2. Load config in session with different working directory
3. Verify paths corrected to new working directory
4. Verify log messages show corrections
5. Verify custom paths (non-standard) preserved
6. Test automated mode with config file

---

## 5. EDGE CASES

### Custom Mount Paths

**Scenario:** User manually selected custom mount path outside working directory
**Detection:** Path does NOT end with `\Mount`
**Behavior:** Preserve custom path (don't normalize)

### Empty/Null Paths in Config

**Scenario:** Config missing MountPath or WIMPath
**Behavior:** Return default `$global:workdir\<subdir>`

### Cross-Platform Paths

**Scenario:** Config created on Windows, loaded on... (this is Windows-only tool)
**N/A:** PowerShell 5.1 requirement = Windows only

---

## 6. BACKWARDS COMPATIBILITY

### Impact on Existing Configs

- **No breaking changes:** All existing configs continue to work
- **Automatic correction:** Legacy absolute paths auto-corrected on load
- **User visibility:** Corrections logged to make user aware

### Migration Path

- No migration required
- Users can continue using existing configs
- Correction happens transparently

---

## 7. RISKS & MITIGATIONS

| Risk | Impact | Mitigation |
|------|--------|------------|
| Custom paths incorrectly normalized | User loses custom mount location | Regex check for exact `\Mount` suffix; only normalize if matches |
| Log spam on every config load | Cluttered logs | Only log when correction occurs (not when path already correct) |
| Context loss in 9714-line file | Incomplete/wrong edits | Use multi_replace with 5-line context; verify line numbers |

---

## 8. SUCCESS CRITERIA

- [ ] `Repair-WorkingDirectoryPath` function implemented and tested
- [ ] `Get-Configuration` modified to call repair function
- [ ] Test: Load legacy config with `D:\Scripts\WimWitch\Mount`
- [ ] Verify: Mount path corrected to `<new-workdir>\Mount`
- [ ] Verify: Completed WIMs path corrected to `<new-workdir>\CompletedWIMs`
- [ ] Verify: Custom paths (drivers, source WIM) NOT modified
- [ ] Verify: Corrections logged with Warning class
- [ ] No hardcoded path references in code
- [ ] Automated mode works with corrected paths

---

## 9. RELATED ISSUES

### Supersedes

- `.github/prompts/plan-bugfix-08-mountPathConsistency.prompt.md` (incomplete scope)

### Does NOT Address

- Autopilot path (`$WPFJSONTextBoxSavePath.Text`) not saved/loaded in configs (separate issue if needed)
- ISO file paths (user-selected, should remain absolute)
- ConfigMgr paths (system-specific, should remain absolute)

---

## 10. APPROVAL CHECKPOINT

**File Count:** 1 file modified (`WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`)
**Line Changes:** ~40 lines added (new function), 2 lines modified (config load)
**Risk Level:** Low (auto-correction with fallback to original values)
**Context Window:** 9714 lines manageable with precise line targeting

**Ready for Implementation:** YES / NO

**Approval Signature:** _____________________ Date: _________

**Notes:**

---

## APPENDIX: AFFECTED CODE LOCATIONS

### Initialization (Correct Behavior)

- File: `WIMWitch-tNG/Public/WIMWitch-tNG.ps1`
- Lines: 533-535

### Config Save (Root Cause)

- File: `WIMWitch-tNG/Private/WWFunctions.ps1`
- Lines: 2241-2242

### Config Load (Fix Target)

- File: `WIMWitch-tNG/Private/WWFunctions.ps1`
- Lines: 2420-2421

### Additional Reference Points

- `Save-Configuration` function: Line 2215
- `Get-Configuration` function: Line 2397
- Config load invocations: `WIMWitch-tNG.ps1` lines 817, 1197
