# PLAN 1: Comment Out Broken PELCU Call with Feature Warning

**Status:** DRAFT (Awaiting Approval)

**Created:** 2026-01-28

**Priority:** High (Stops production blocking failures)

**Complexity:** Low

**Risk Level:** VERY LOW (Minimal code change; comment-out + logging only)

---

## 1. ANALYSIS

### 1.1 Problem Statement

The `Update-BootWIM()` function calls `Deploy-Updates -class 'PELCU'`, which attempts to apply Windows production Cumulative Update packages to Windows PE (Preinstallation Environment) images. This fails because:

- WinPE is a minimal OS; production LCU packages contain Unattend.xml metadata incompatible with WinPE
- OSDSUS does NOT provide PE-specific update downloads
- No separate PE-specific update folders exist
- The feature was architecturally designed but never fully implemented

### 1.2 Current Behavior

Lines 8590-8592 in [Update-BootWIM.ps1](../../WIMWitch-tNG/Private/Functions/BootWIM/Update-BootWIM.ps1):

```powershell
Update-Log -data 'Applying SSU Update' -Class Information
Deploy-Updates -class 'PESSU'
Update-Log -data 'Applying LCU Update' -Class Information
Deploy-Updates -class 'PELCU'
```

**Result:** Error "An error occurred applying the Unattend.xml file from the .msu package" at boot.wim update phase.

### 1.3 Solution Scope

**Minimal fix:** Comment out the PELCU call. Add a warning log message indicating the feature is broken and will be reimplemented in a future release.

---

## 2. ASSESSMENT

### Why This Approach

1. **Immediate pain relief** — Stops production build failures
2. **Transparency** — Log warning informs users the feature is disabled
3. **Minimal risk** — Only removes two lines; no logic changes
4. **Preserves code** — Commented-out code preserved for future implementation
5. **Low complexity** — Suitable for immediate deployment while Plan 2 is researched
6. **PESSU preserved** — SSU patching still attempted (if updates exist)

### What This Does NOT Do

- Does NOT implement PE-specific update support
- Does NOT provide actual WinPE patching
- WinPE will only receive SSU if available (currently none in OSDSUS)

---

## 3. SOLUTION DESIGN

### 3.1 Code Changes

**File:** `WIMWitch-tNG/Private/Functions/BootWIM/Update-BootWIM.ps1`

**Function:** `Update-BootWIM()`

**Current Code (lines 8590-8592):**

```powershell
Update-Log -data 'Applying SSU Update' -Class Information
Deploy-Updates -class 'PESSU'
Update-Log -data 'Applying LCU Update' -Class Information
Deploy-Updates -class 'PELCU'
```

**New Code:**

```powershell
Update-Log -data 'Applying SSU Update' -Class Information
Deploy-Updates -class 'PESSU'
# PELCU patching disabled - feature incomplete (no PE-specific updates in OSDSUS)
# This will be reimplemented in a future release (Plan 2).
Update-Log -data 'PELCU (LCU) patching not available for WinPE - feature disabled pending implementation' -Class Warning
# Deploy-Updates -class 'PELCU'
```

### 3.2 Syntax Preservation

- No new control flow introduced
- No variable changes
- Comments and one additional `Update-Log` call only
- Function signature unchanged
- All surrounding blocks preserved

---

## 4. IMPLEMENTATION STAGES

### Stage 1: Pre-Flight Validation

**Objectives:**

1. Review and approve this minimal-change plan
2. Confirm stakeholder agreement on approach

**Success Criteria:**

- User approves the comment-out + warning approach
- No questions about minimal scope

**Outputs:**

- This plan document (APPROVED)

### Stage 2: Code Modification with Validation

**Objectives:**

1. Edit WWFunctions.ps1 carefully
2. Validate PowerShell syntax
3. Ensure module imports without errors

**Success Criteria:**

- [ ] Edit applied without syntax errors
- [ ] PowerShell syntax validation passes (mcp_pylance)
- [ ] File encoding verified as CRLF + UTF-8
- [ ] Module imports without errors (dry-run import test)
- [ ] Surrounding functions untouched and valid
- [ ] Braces balanced; no orphaned code

**Outputs:**

- Modified WWFunctions.ps1 with PELCU call commented
- Syntax validation report
- Module load verification

### Stage 3: Functional Testing

**Objectives:**

1. Run test build with "Update Boot.WIM" enabled
2. Verify log shows warning message
3. Confirm no LCU errors on boot.wim
4. Ensure main image patching unaffected

**Success Criteria:**

- [ ] Build completes without "Unattend.xml" errors
- [ ] Log shows: "PELCU (LCU) patching not available for WinPE - feature disabled pending implementation"
- [ ] PESSU attempt logged
- [ ] Main image receives all LCU patches correctly
- [ ] ISO/upgrade package creation succeeds

**Outputs:**

- Test build log showing clean boot.wim phase
- Evidence warning message appears

---

## 5. RISK ASSESSMENT

| Risk | Likelihood | Severity | Mitigation |
| --- | --- | --- | --- |
| Syntax error in 9000-line file | Low | High | mcp_pylance validation before commit |
| Brace mismatch in surrounding code | Very Low | High | Careful context matching (5 lines before/after) |
| New Update-Log call causes issues | Very Low | Medium | Verify log function signature unchanged |
| User confusion about disabled feature | Low | Low | Warning message clearly explains |

**Overall Risk Level: VERY LOW** — Only comments and one logging statement added.

---

## 6. SUCCESS CRITERIA

### Functional Success

1. **No boot.wim LCU errors** — Build log shows no "An error occurred applying the Unattend.xml file" messages
2. **Warning logged** — Log contains message about PELCU being disabled
3. **Main image patching unaffected** — Windows 11/10 image continues receiving all LCU patches
4. **Build completes** — ISO and upgrade package creation succeeds

### Code Quality Success

1. **Syntax passes validation** — mcp_pylance reports no syntax errors
2. **Module imports cleanly** — `Import-Module WIMWitch-tNG` completes without warnings
3. **Function signatures preserved** — `Update-BootWIM` and all callers work as before
4. **File encoding correct** — CRLF + UTF-8 verified
5. **No orphaned code** — All braces and blocks intact

---

## 7. NEXT STEPS

### Status: AWAITING APPROVAL

Response options:

- **"Approve"** or **"Proceed"** → Advance to Stage 2 (Code modification + validation)
- **"Revise"** → Detail requested changes
- **"Defer"** → Postpone

**Note:** Plan 2 (feature implementation) will be reviewed separately after Plan 1 approval.

No implementation code will be generated until approval is recorded.
