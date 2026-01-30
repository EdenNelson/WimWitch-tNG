# PLAN 2: Implement PE-Specific Update Support

**Status:** DRAFT (Awaiting Approval; Contingent on Plan 1)

**Created:** 2026-01-28

**Priority:** Medium (Feature enhancement; non-blocking)

**Complexity:** HIGH (Requires OSDSUS research + multi-file changes + new directory structure)

**Risk Level:** MEDIUM (Larger scope; potential syntax impact on 9000-line file)

**Contingency:** Plan 2 starts ONLY after Plan 1 is approved and deployed.

---

## 1. ANALYSIS

### 1.1 Problem Statement

The feature to patch boot.wim with PE-specific updates was architecturally designed but never fully implemented. The deployment layer (Update-BootWIM, Deploy-Updates) is ready; the download/catalog layer is missing.

**Gap:** `Get-WindowsPatches()` does NOT download PE-specific updates from OSDSUS. It only downloads production updates (SSU, LCU, etc.).

**Result:** Even if PELCU call is enabled, there are no PE-specific update files to apply.

### 1.2 Missing Implementation

The feature requires:

1. **OSDSUS Research** — Does OSDSUS expose PE-specific updates? What UpdateGroup classifications exist for PE variants?
2. **Download Logic** — Add code to download PE-specific SSU and LCU separately (if available)
3. **Storage Structure** — Create PE-specific folder hierarchy (e.g., `\updates\OS\build\PE-SSU\`, `\updates\OS\build\PE-LCU\`)
4. **Deployment Logic** — Ensure Deploy-Updates correctly routes PE variants to PE mount path
5. **Testing** — Validate that PE updates (if sourced) apply without errors

### 1.3 Current Architecture (Ready)

**Deployment already designed:**

- `Update-BootWIM()` mounts each PE image and calls Deploy-Updates with 'PESSU' and 'PELCU'
- `Deploy-Updates()` has logic to handle PE variants (sets `$IsPE = $true` and routes to PE mount)
- Storage paths are already defined: `\updates\OS\build\PESSU\`, `\updates\OS\build\PE-LCU\`

**Download NOT designed:**

- `Get-WindowsPatches()` has NO code to download PE-specific updates
- OSDSUS support for PE updates is unknown

---

## 2. ASSESSMENT

### 2.1 Required Investigation

**CRITICAL:** Before implementation, must determine:

1. **Does OSDSUS provide PE-specific updates?**
   - Query OSDSUS catalog for UpdateGroup values containing 'PE', 'WinPE', 'Preinstall', or similar
   - Check OSDUpdate module documentation for PE classification
   - If YES → Implement download logic for those groups
   - If NO → Pursue alternative: Windows PE ADK, Microsoft catalog, or manual sourcing

2. **What PE updates exist and are applicable?**
   - SSU (Servicing Stack Update) for WinPE?
   - LCU (Cumulative Update) for WinPE?
   - Or only via ADK/media?

3. **Compatibility concerns:**
   - Are PE updates architecture-specific (x64, x86, ARM64)?
   - Do they require special handling beyond Add-WindowsPackage?

### 2.2 Decision Tree

#### Outcome A: OSDSUS provides PE updates

- Implement filter in `Get-WindowsPatches()` to download PE variants
- Create PE-specific folders
- Uncomment PELCU call in `Update-BootWIM()`
- Test end-to-end

#### Outcome B: OSDSUS does NOT provide PE updates

- Explore alternative sources:
  - Windows PE ADK (Microsoft official source)
  - Manual PE update sourcing
  - Accept that WinPE updates are not downloadable/available offline
- May require architecture redesign (beyond scope of this plan)

---

## 3. SOLUTION DESIGN

### 3.1 Proposed Implementation (Conditional on Investigation)

**Assuming** OSDSUS provides PE updates with identifiable UpdateGroup values:

#### Stage 1: Research OSDSUS API

**Task 1.1:** Query OSDSUS catalog for PE-related update classifications

```powershell
# Pseudo-code for research
Get-OSDUpdate | Select-Object -Property UpdateGroup -Unique | Sort-Object UpdateGroup
# Expected output may include: 'PE-SSU', 'PE-LCU', 'PE10-SSU', 'PEBuild-SSU', etc.
```

**Task 1.2:** Document available UpdateGroup values and their meanings

**Task 1.3:** Verify PE updates are available for target Windows versions (10, 11)

#### Stage 2: Modify Get-WindowsPatches()

**Task 2.1:** Add download logic for PE-SSU

```powershell
# After existing SSU download, add:
# For PE SSU (if available in OSDSUS)
try {
    Get-OSDUpdate -ErrorAction Stop | Where-Object {
        $_.UpdateOS -eq $OS -and
        $_.UpdateArch -eq 'x64' -and
        $_.UpdateBuild -eq $build -and
        ($_.UpdateGroup -eq 'PE-SSU' -or $_.UpdateGroup -eq 'PESSU')
    } | Get-DownOSDUpdate -DownloadPath $global:workdir\updates\$OS\$build\PE-SSU
} catch {
    Update-Log -data 'No PE-SSU updates available' -Class Warning
}
```

**Task 2.2:** Add download logic for PE-LCU (same pattern)

**Task 2.3:** Add folder creation for PE-specific directories if they don't exist

#### Stage 3: Verify Deploy-Updates() Routing

**Task 3.1:** Confirm Deploy-Updates correctly interprets PESSU/PELCU and routes to PE mount

**Task 3.2:** Test that Add-WindowsPackage applies PE updates without errors

#### Stage 4: Uncomment PELCU in Update-BootWIM()

**Task 4.1:** Restore PELCU call (undoing Plan 1 changes)

```powershell
Deploy-Updates -class 'PELCU'
```

---

## 4. IMPLEMENTATION STAGES

### Stage 1: OSDSUS Research & Validation

**Objectives:**

1. Query OSDSUS API to determine PE update availability
2. Document findings and feasibility assessment
3. Obtain approval to proceed (or pivot to alternative approach)

**Success Criteria:**

- [ ] OSDSUS API queried for PE-specific UpdateGroup values
- [ ] Available PE update classifications documented
- [ ] PE updates confirmed available for Windows 10 and/or Windows 11
- [ ] Decision made: Continue with implementation OR pivot to alternative

**Outputs:**

- Research report: "OSDSUS PE Update Availability"
- UpdateGroup mapping (if PE updates exist)
- Feasibility assessment with recommendations

**Effort:** 2-4 hours research

### Stage 2: Code Modification with Syntax Validation

**Objectives:**

1. Modify Get-WindowsPatches() to download PE updates
2. Add PE folder creation logic
3. Validate PowerShell syntax
4. Ensure module imports cleanly

**Success Criteria:**

- [ ] Download logic added for PE-SSU and PE-LCU
- [ ] Folder creation code added for PE directories
- [ ] PowerShell syntax validation passes (mcp_pylance)
- [ ] File encoding verified as CRLF + UTF-8
- [ ] Module imports without errors
- [ ] No syntax errors in surrounding functions
- [ ] Braces balanced; no orphaned code
- [ ] All variable scope preserved

**Outputs:**

- Modified WIMWitch-tNG/Private/Functions/Updates/Get-WindowsPatches.ps1 with PE download logic
- Syntax validation report
- Module load verification

**Effort:** 4-6 hours (coding + validation)

**File Safety Precautions:**

- Backup Get-WindowsPatches.ps1 before editing
- Edit only Get-WindowsPatches() function
- Use mcp_pylance for syntax validation
- Test import: `Import-Module WIMWitch-tNG -Verbose`
- Verify surrounding functions unchanged

### Stage 3: Functional Testing

**Objectives:**

1. Download updates to confirm PE folders created
2. Run test build with Update Boot.WIM enabled
3. Verify PE updates applied without errors
4. Confirm main image patching unaffected

**Success Criteria:**

- [ ] Get-WindowsPatches() creates PE-specific directories
- [ ] PE updates (if available) downloaded successfully
- [ ] Update-BootWIM processes PE images without LCU errors
- [ ] Main image receives all LCU patches correctly
- [ ] Build completes; ISO/upgrade package created
- [ ] Boot.WIM verified with proper updates applied

**Outputs:**

- Test build log showing successful PE patching
- Verification that PE updates applied without errors

**Effort:** 3-4 hours (testing + troubleshooting)

---

## 5. RISK ASSESSMENT

| Risk | Likelihood | Severity | Mitigation |
| --- | --- | --- | --- |
| OSDSUS doesn't provide PE updates | Medium | High | Research Phase gates this; pivot to alternatives |
| Syntax error in 9000-line file | Medium | High | mcp_pylance validation; careful context matching |
| Brace/block mismatch | Low | High | 5-line context matching; backup file |
| PE updates incompatible with WinPE | Low | Medium | Stage 3 testing catches this; revert if needed |
| Performance impact (more downloads) | Low | Low | PE updates smaller than main image |
| Variable scope pollution | Low | Medium | Review all variable declarations in modified function |

**Overall Risk Level: MEDIUM** — Research phase may uncover blockers; implementation scope is moderate.

---

## 6. SUCCESS CRITERIA

### Functional Success

1. **PE updates downloaded** — Get-WindowsPatches() creates PE-specific folders with updates (if available)
2. **Boot.WIM patched** — Update-BootWIM applies PE updates without errors
3. **No main image impact** — Windows installation image continues receiving all LCU patches
4. **Build completes** — Full build (main image + boot.wim + ISO) succeeds
5. **PE verification** — Boot.WIM contains applied PE updates (verifiable with dism)

### Code Quality Success

1. **Syntax passes validation** — mcp_pylance reports no syntax errors
2. **Module imports cleanly** — `Import-Module WIMWitch-tNG` completes without warnings
3. **Function signatures preserved** — All callers work as before
4. **File encoding correct** — CRLF + UTF-8 verified
5. **No regressions** — Existing functionality unchanged

### Documentation Success

1. **Comments added** — PE download logic clearly documented in code
2. **Changelog updated** — Feature implementation recorded
3. **Research findings** — OSDSUS PE support documented for future reference

---

## 7. CONTINGENCIES

### If OSDSUS Does NOT Provide PE Updates

**Plan C Options:**

1. **Windows PE ADK Route** — Source PE updates from Microsoft's Windows PE ADK
2. **Manual Sourcing** — Document where PE updates should be placed manually
3. **Accept Limitation** — Acknowledge that offline PE patching is not feasible; document as known limitation

**Decision Point:** After Stage 1 research, if PE updates are unavailable, pivot to Plan C.

---

## 8. NEXT STEPS

### Status: AWAITING APPROVAL

**Contingency:** Plan 2 approval is CONDITIONAL on Plan 1 being approved and deployed first.

Response options:

- **"Approve Plan 2"** → Proceed with Plan 1 first; Plan 2 queued for after Plan 1 completion
- **"Defer Plan 2"** → Deploy Plan 1 only; Plan 2 becomes a future enhancement ticket
- **"Revise"** → Detail requested changes

**Note:** Plan 1 and Plan 2 are designed to be sequential, not parallel. Plan 1 removes the broken feature; Plan 2 reimplements it properly.

No implementation code will be generated until both plans are explicitly approved.
