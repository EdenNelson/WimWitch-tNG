# Scribe Plan: Windows 11 Build Number Consistency Issue

**Date:** 2026-01-30

**Reporter:** Eden Nelson

**Status:** Investigation & Planning Phase

---

## Issue Summary

Windows 11 versions 23H2 and 22H2 exhibit the same build number inconsistency problem that was previously solved for Windows 10 22H2.

**Current Constraint:** WIMWitch-tNG only officially supports Windows 11:

- 23H2 (build 10.0.22631.*)
- 24H2 (build 10.0.26100.*)
- 25H2 (build 10.0.26200.*)

**Problem:** Windows 11 23H2 and 22H2 share overlapping build numbers (10.0.22621.*), making automatic version detection ambiguous. This is identical to the Windows 10 issue Microsoft created by releasing inconsistent ISOs.

---

## Background: How Windows 10 22H2 Was Solved

### The Windows 10 Pattern (SOLVED)

Microsoft released Windows 10 ISOs with inconsistent build numbers across 2004, 20H2, 21H1, 21H2, and 22H2 releases:

- Some ISOs labeled "22H2" showed builds: 19041, 19042, 19043, 19044
- The "official" 22H2 build: 19045

**Solution Implemented:**

1. **Auto-detection logic** in `Get-WinVersionNumber.ps1`:

   ```powershell
   '10\.0\.1904\d\.\d+' { # Matches 19040-19049
       $buildnum = '22H2'
       Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimBuild..." -Class Information
   }
   ```

2. **Logging strategy:** When any `10.0.1904*.*` build is detected, log an informational message explaining the inconsistency and noting that all variants will be treated as 22H2.
3. **No user dialog:** All detection is automatic—no version selection prompt.

### Key Features of the Windows 10 Solution

- ✅ Catches all build variants (19041-19049) with a single regex pattern
- ✅ Logs with `Update-Log -Class Information` to alert users to the build number variance
- ✅ Gracefully handles ISOs with inconsistent metadata
- ✅ Works transparently without user intervention

---

## Windows 11 Build Number Inconsistency

### The Windows 11 Problem

Microsoft has released Windows 11 ISOs with similar build number inconsistencies:

- **Windows 11 22H2:** Build 10.0.22621.* (e.g., 22621.1000)
- **Windows 11 23H2:** Also uses 10.0.22631.* (e.g., 22631.1000)
- **Issue:** Some ISOs labeled "23H2" may show build 10.0.22621.* instead of the expected 10.0.22631.*

### Current Detection Code

[Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1#L15):

```powershell
'10\.0\.22631\.\d+' { $buildnum = '23H2' }
```

**Limitation:** This exact-match regex only catches official 23H2 builds (22631). It does NOT catch variants using the 22621 build range.

---

## Investigation: Proposed Solution (Based on Windows 10 Pattern)

### Strategy: Apply the Same Approach to Windows 11 23H2

**Rationale:** Since we don't support Windows 11 22H2 (only 23H2, 24H2, 25H2), we can:

1. Treat all `10.0.2262*.*` builds as Windows 11 23H2 (similar to treating all `10.0.1904*.*` as Windows 10 22H2)
2. Update the regex pattern to catch both 22621 and 22631
3. Log an informational message about the build inconsistency

### Files to Modify

#### 1. Get-WinVersionNumber.ps1

**Location:** [WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1)

**Current code (line 15):**

```powershell
'10\.0\.22631\.\d+' { $buildnum = '23H2' }
```

**Proposed change:**

```powershell
'10\.0\.2262\d\.\d+' {
    $buildnum = '23H2'
    Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimBuild. Note: ISO build numbers from Microsoft are inconsistent—some 23H2 releases use build 10.0.22621.* instead of the expected 10.0.22631.*. All 10.0.2262*.* builds will be treated as 23H2." -Class Information
}
```

**Pattern explanation:**

- `10\.0\.2262\d\.` = Matches `10.0.22620.`, `10.0.22621.`, ..., `10.0.22629.`
- Catches both the variant (22621) and official (22631) builds

#### 2. Set-Version.ps1

**Location:** [WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1)

**Current code (line 1):**

```powershell
if ($wimversion -like '10.0.22631.*') { $version = '23H2' }
```

**Proposed change:**

```powershell
if ($wimversion -like '10.0.2262*.*') {
    $version = '23H2'
    Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimversion. Note: ISO build numbers from Microsoft are inconsistent, assuming 23H2." -Class Information
}
```

**Pattern explanation:**

- `10.0.2262*.*` = Matches `10.0.22620.*`, `10.0.22621.*`, ..., `10.0.22629.*`, `10.0.22631.*`, etc.
- Works with PowerShell's `-like` operator

---

## Implementation Checklist

### Phase 1: Core Functions Update

- [ ] Modify `Get-WinVersionNumber.ps1` to use `'10\.0\.2262\d\.\d+'` regex
- [ ] Add logging message explaining the build inconsistency
- [ ] Modify `Set-Version.ps1` to use `'10.0.2262*.*'` wildcard
- [ ] Add logging message in `Set-Version.ps1`

### Phase 2: Testing & Validation

- [ ] Test with Windows 11 23H2 build 22631.xxxx (official)
  - Expected: Auto-detect as 23H2, log information message
  - ✓ Operation proceeds normally
- [ ] Test with Windows 11 23H2 build 22621.xxxx (variant)
  - Expected: Auto-detect as 23H2, log information message
  - ✓ Operation proceeds normally
- [ ] Test Windows 11 24H2 (build 26100.xxxx)
  - Expected: No changes, operations work as before
- [ ] Test Windows 11 25H2 (build 26200.xxxx)
  - Expected: No changes, operations work as before
- [ ] Verify no regression in Windows 10 22H2 detection
  - Expected: Builds 19041-19049 still auto-detect as 22H2

### Phase 3: Documentation

- [ ] Update code comments in both functions to reference the Windows 11 build inconsistency
- [ ] Consider updating README or CHANGELOG to note this limitation

---

## Success Criteria

✅ **Detection works automatically without user intervention**

- Any Windows 11 build in the `10.0.2262*.*` range is correctly identified as 23H2

✅ **Logging is clear and informative**

- Users see an information-level message explaining the build variance
- No error messages for valid variant builds

✅ **No breaking changes**

- Windows 10 22H2 detection unaffected
- Windows 11 24H2 and 25H2 detection unaffected

✅ **Aligns with existing patterns**

- Uses the same approach that was successfully implemented for Windows 10 22H2
- Consistent logging style (`Update-Log -Class Information`)

---

## Reference Implementation (Windows 10 22H2)

For comparison, the Windows 10 22H2 solution is documented in:
- [plan-windows10-22h2Only.prompt.md](./plan-windows10-22h2Only.prompt.md) - Detailed technical specification
- Implemented in: [Get-WinVersionNumber.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1#L8-L10)
- And: [Set-Version.ps1](../../WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1#L8-L10)

The Windows 11 23H2 fix will follow the identical pattern.

---

## Next Steps (For Architect Review)

**Questions for Eden:**

1. Should we apply the same fix immediately, or would you like to see code samples first?
2. Are there any Windows 11 22H2 ISOs currently in use that we need to test against?
3. Should the logging message mention specific build numbers (22621 vs 22631) or keep it generic?

**Once approved:**

- Hand off to Pragmatic Architect for implementation
- Architect will create detailed technical plan (`plan-win11-build-consistency.md`)
- Implement and test according to validation checklist above
