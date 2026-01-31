# Technical Implementation Plan: Windows 11 Build Number Consistency

**Date:** 2026-01-30
**Architect:** The Pragmatic Architect
**Related Scribe Plan:** [scribe-plan-win11-build-number-consistency.md](scribe-plan-win11-build-number-consistency.md)
**Status:** Ready for Implementation

---

## Executive Summary

Apply the proven Windows 10 22H2 build variance solution to Windows 11 23H2. Microsoft ships Windows 11 23H2 ISOs with inconsistent build numbers (both 22621 and 22631), requiring automatic detection logic to treat all `10.0.2262*.*` builds as 23H2.

**Files Modified:** 2
**Functions Modified:** 2
**Breaking Changes:** None
**Regression Risk:** Low (isolated to version detection logic)

---

## Problem Statement

### Current State

**Supported Windows 11 Versions:**

- 23H2 (build 10.0.22631.*)
- 24H2 (build 10.0.26100.*)
- 25H2 (build 10.0.26200.*)

**Issue:** Windows 11 23H2 ISOs exhibit build number variance:

- **Official:** 10.0.22631.* (e.g., 22631.1000)
- **Variant:** 10.0.22621.* (some ISOs labeled 23H2 use this build)

**Current Detection Logic:**

- [Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1#L15): `'10\.0\.22631\.\d+'` (exact match)
- [Set-Version.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1#L2): `'10.0.22631.*'` (exact match)

**Result:** ISOs with build 22621 are not recognized as 23H2, causing version detection failures.

### Desired State

All builds in the range `10.0.22620.*` through `10.0.22639.*` should auto-detect as Windows 11 23H2, with informational logging explaining the build variance.

### Precedent

Windows 10 22H2 exhibits identical behavior and was solved using this pattern:

```powershell
# Get-WinVersionNumber.ps1 (line 8)
'10\.0\.1904\d\.\d+' {
    $buildnum = '22H2'
    Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimBuild..." -Class Information
}

# Set-Version.ps1 (line 8)
elseif ($wimversion -like '10.0.1904*.*') {
    $version = '22H2'
    Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimversion..." -Class Information
}
```

**Success Criteria:** Apply the identical pattern to Windows 11 23H2.

---

## Technical Specification

### Modification 1: Get-WinVersionNumber.ps1

**File:** [WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1)

**Current Code (line 15):**

```powershell
# Windows 11 version checks
'10\.0\.22631\.\d+' { $buildnum = '23H2' }
'10\.0\.26100\.\d+' { $buildnum = '24H2' }
```

**New Code:**

```powershell
# Windows 11 version checks (23H2 has build variance like Windows 10 22H2)
'10\.0\.2262\d\.\d+' {
    $buildnum = '23H2'
    Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimBuild. Note: ISO build numbers from Microsoft are inconsistent—some 23H2 releases use build 10.0.22621.* instead of the expected 10.0.22631.*. All 10.0.2262*.* builds will be treated as 23H2." -Class Information
}
'10\.0\.26100\.\d+' { $buildnum = '24H2' }
```

**Changes:**

1. Replace exact-match regex `22631` with range-match `2262\d` (catches 22620-22629)
2. Add multi-line block with informational logging (mirrors Windows 10 pattern)
3. Maintain alphabetical ordering (23H2, 24H2, 25H2)

**Pattern Analysis:**

- `10\.0\.2262\d\.\d+` matches:
  - `10.0.22620.` through `10.0.22629.`
  - Covers both variant (22621) and official (22631) builds
  - Narrow enough to avoid false positives (22632+ would be different versions)

### Modification 2: Set-Version.ps1

**File:** [WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1)

**Current Code (lines 2-4):**

```powershell
# Windows 11 versions
if ($wimversion -like '10.0.22631.*') { $version = '23H2' }
elseif ($wimversion -like '10.0.26100.*') { $version = '24H2' }
```

**New Code:**

```powershell
# Windows 11 versions (23H2 has build variance like Windows 10 22H2)
if ($wimversion -like '10.0.2262*.*') {
    $version = '23H2'
    Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimversion. Note: ISO build numbers from Microsoft are inconsistent—some 23H2 releases use build 10.0.22621.* instead of the expected 10.0.22631.*. All 10.0.2262*.* builds will be treated as 23H2." -Class Information
}
elseif ($wimversion -like '10.0.26100.*') { $version = '24H2' }
```

**Changes:**

1. Replace exact-match `22631` with wildcard `2262*` (PowerShell `-like` operator)
2. Convert single-line `if` to multi-line block
3. Add informational logging (identical message to Get-WinVersionNumber.ps1)

**Pattern Analysis:**

- `10.0.2262*.*` is slightly broader than the regex (technically matches 22622222.*, etc.)
- Acceptable trade-off: PowerShell's `-like` is inherently less precise than regex
- Matches the Windows 10 pattern style (`10.0.1904*.*`)

---

## Implementation Details

### Code Style & Standards

**Alignment with Existing Patterns:**

1. **Logging Class:** Use `Update-Log -Class Information` (not Error/Warning)
2. **Message Content:** Explain the build variance and action taken
3. **Verbosity:** Match the Windows 10 22H2 message length/detail
4. **Code Structure:** Multi-line blocks for clarity (not one-liners)

**Comment Updates:**

- Add inline comment: `# 23H2 has build variance like Windows 10 22H2`
- Maintains consistency with existing Windows 10 comment style

### Regex vs. Wildcard Patterns

**Design Decision:**

- **Get-WinVersionNumber.ps1:** Uses regex (`-Regex` switch in `switch` statement)
  - Pattern: `10\.0\.2262\d\.\d+`
  - Precision: Matches exactly 22620-22629
- **Set-Version.ps1:** Uses PowerShell `-like` wildcard
  - Pattern: `10.0.2262*.*`
  - Precision: Matches 2262* (broader, but acceptable)

**Rationale:** Each function uses the pattern style appropriate to its matching method (regex vs. wildcard). This maintains consistency with the Windows 10 22H2 implementation.

---

## Testing & Validation

### Test Matrix

| Build Number    | Version Label   | Expected Detection | Log Message Expected  |
|-----------------|-----------------|--------------------|-----------------------|
| 10.0.22621.1000 | 23H2 (variant)  | ✓ 23H2             | ✓ Information         |
| 10.0.22631.2000 | 23H2 (official) | ✓ 23H2             | ✓ Information         |
| 10.0.22629.5000 | 23H2 (edge)     | ✓ 23H2             | ✓ Information         |
| 10.0.22620.1000 | 23H2 (edge)     | ✓ 23H2             | ✓ Information         |
| 10.0.26100.1000 | 24H2            | ✓ 24H2             | ✗ No message          |
| 10.0.26200.1000 | 25H2            | ✓ 25H2             | ✗ No message          |
| 10.0.19045.1000 | Win10 22H2      | ✓ 22H2             | ✓ Information (Win10) |

### Regression Testing

**Critical Paths:**

1. **Windows 10 22H2 Detection:**
   - Verify all `10.0.1904*.*` builds still detect as 22H2
   - Verify Windows 10 log message is unchanged
2. **Windows 11 24H2/25H2:**
   - Verify no logging changes for these versions
   - Verify detection logic unchanged
3. **Unsupported Builds:**
   - Verify error messages for Windows 10 legacy builds still trigger
   - Verify "Unknown Version" fallback still works

### Manual Testing Checklist

- [ ] Load Windows 11 23H2 ISO with build 22631.* → Auto-detect as 23H2, log info message
- [ ] Load Windows 11 23H2 ISO with build 22621.* → Auto-detect as 23H2, log info message
- [ ] Load Windows 11 24H2 ISO → No regression, no extra logging
- [ ] Load Windows 11 25H2 ISO → No regression, no extra logging
- [ ] Load Windows 10 22H2 ISO (19045) → No regression, original log message
- [ ] Load unsupported Windows 10 build (17763) → Error message triggers correctly

---

## Risk Assessment

### Low Risk

**Isolation:**

- Changes are isolated to two utility functions
- No changes to UI, WIM operations, or critical logic paths
- Pattern matches the proven Windows 10 22H2 solution

**Backward Compatibility:**

- No breaking changes
- Existing ISOs will continue to work
- New pattern is additive (expands detection range)

### Edge Cases

**Build Number Outside Range:**

- Build `10.0.22632.*`: Would NOT match (falls through to "Unknown Version")
- **Mitigation:** Pattern is intentionally narrow to avoid false positives
- **Justification:** Any build >22631 is likely a different version (unsupported 22H2 or future release)

**Windows 11 22H2 ISO:**

- If a user loads an unsupported Windows 11 22H2 ISO (build 22621.*), it will now auto-detect as 23H2
- **Impact:** User gets 23H2 customization applied to a 22H2 ISO
- **Mitigation:** WIMWitch-tNG does not officially support Windows 11 22H2, so this is acceptable behavior
- **Logging:** The information message clarifies the build variance; users are informed

---

## Rollback Plan

**If Issues Arise:**

1. Revert both files to exact-match patterns:
   - Get-WinVersionNumber.ps1: `'10\.0\.22631\.\d+'`
   - Set-Version.ps1: `'10.0.22631.*'`
2. Remove informational logging blocks
3. Document the variant build issue in README/CHANGELOG as a known limitation

**Rollback Risk:** Minimal—changes are isolated to two functions with no external dependencies.

---

## Documentation Updates

### Code Comments

**Already Included in Implementation:**

- Inline comment: `# 23H2 has build variance like Windows 10 22H2`
- Mirrors existing Windows 10 comment style

### External Documentation

**Optional (Not Required for Implementation):**

- Update [CHANGELOG.md](../../CHANGELOG.md) to note the Windows 11 23H2 build variance fix
- Add section to [README.md](../../README.md) or [USAGE.md](../../USAGE.md) explaining supported versions and build variance behavior

**Recommendation:** Document in CHANGELOG only—this is a bug fix, not a feature.

---

## Approval & Sign-Off

**Pre-Implementation Checklist:**

- [x] Scribe plan reviewed and approved
- [ ] Technical plan reviewed by Eden Nelson
- [ ] Implementation approved to proceed

**Post-Implementation Checklist:**

- [ ] Code changes implemented
- [ ] Manual testing completed (see Testing & Validation section)
- [ ] No regressions detected in Windows 10 or Windows 11 24H2/25H2
- [ ] CHANGELOG updated (optional)

---

## Implementation Notes

### Execution Order

1. Implement both functions simultaneously (avoid partial deployment)
2. Test with Get-WinVersionNumber.ps1 first (called earlier in the workflow)
3. Validate Set-Version.ps1 catches the same builds

### Code Signing

**Post-Edit Action:**

- Both files have Authenticode signatures (see `# SIG # Begin signature block`)
- Signatures will break on edit
- **Action Required:** Re-sign both files after implementation (or remove signature blocks if development mode)

---

## References

- **Precedent:** [plan-windows10-22h2Only.prompt.md](./plan-windows10-22h2Only.prompt.md)
- **Scribe Plan:** [scribe-plan-win11-build-number-consistency.md](./scribe-plan-win11-build-number-consistency.md)
- **Windows 10 Implementation:**
  - [Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1#L8-L10)
  - [Set-Version.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1#L8-L10)

---

## Success Criteria (Final)

✅ **Detection is automatic and transparent**

- Users loading any Windows 11 23H2 ISO (variant or official build) get correct version detection
- No manual version selection required

✅ **Logging is clear and informative**

- Information-level message explains the build variance
- Users understand why a 22621 build is being treated as 23H2

✅ **No regressions**

- Windows 10 22H2 detection unaffected
- Windows 11 24H2/25H2 detection unaffected
- Unsupported build error messages still trigger correctly

✅ **Code quality maintained**

- Matches existing code style and patterns
- Comments explain the build variance rationale
- Aligns with Windows 10 22H2 precedent

---

**Ready for implementation upon approval.**
