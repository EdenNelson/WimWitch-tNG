# Plan: Modularize WWFunctions.ps1 into Individual Function Files

**Date:** 2026-01-27
**Author:** Pragmatic Architect
**Status:** PLANNING (Awaiting Approval)
**Scope:** Refactor 103 private functions from monolithic `WWFunctions.ps1` into individual, organized PowerShell files.

---

## 1. ANALYSIS

### 1.1 Current State

- **File:** `WIMWitch-tNG/Private/WWFunctions.ps1`
- **Size:** 9,683 lines
- **Functions:** 103 active functions
- **Maintainability:** Monolithic structure makes navigation difficult; large file increases cognitive load
- **Loading Pattern:** Module loader (`.psm1`) dot-sources entire file; all functions imported at once
- **No breaking changes:** Modularization is a refactor only; public API remains unchanged

### 1.2 Problem Statement

The 9,683-line monolithic file violates the principle of **Separation of Concerns**:

- Difficult to locate specific functions
- Higher likelihood of merge conflicts when multiple developers work on different functions
- IDE navigation and IntelliSense performance degradation
- Function organization is implicit (scattered throughout file)
- Testing individual functions is cumbersome
- Future contributors face steep cognitive load

### 1.3 Natural Function Groupings

Functions naturally cluster into 16 logical categories:

1. **Form & UI Controls** (21 functions) - WPF form variable management, form state
2. **Administrative & Validation** (5 functions) - Privilege checks, prerequisite validation
3. **Configuration Management** (4 functions) - Config file I/O, conversion
4. **Logging & Output** (4 functions) - Log handling, verbose output, notifications
5. **WIM Operations** (4 functions) - Mount, info queries, version checks
6. **Driver Management** (3 functions) - Driver installation, injection, discovery
7. **Windows Update Management** (13 functions) - LCU, cumulative updates, patch sourcing
8. **AppX Package Management** (2 functions) - Appx removal workflows
9. **Windows Autopilot** (4 functions) - Autopilot profile handling, JSON parsing
10. **ISO & Media Creation** (5 functions) - ISO building, media staging
11. **.NET & OneDrive** (5 functions) - .NET detection/installation, OneDrive deployment
12. **Language Packs & FODs** (10 functions) - Language pack installation, Features on Demand
13. **ConfigMgr Integration** (13 functions) - SCCM/ConfigMgr image package ops
14. **Registry & Customization** (6 functions) - Registry file installation, Start Layout
15. **Boot WIM & WinRE** (2 functions) - Boot image updates, WinRE modifications
16. **Utility & Orchestration** (6 functions) - Generic helpers, main execution flow

---

## 2. ASSESSMENT

### 2.1 Why Modularization?

**Benefits:**

- **Maintainability:** Individual files are 50–300 lines; much easier to reason about
- **Collaboration:** Different developers can work on different categories without merge conflicts
- **Navigation:** IDE jumps directly to function file rather than scanning 9,683-line file
- **Testing:** Individual function files can be unit-tested in isolation (Pester)
- **Performance:** Module loader can conditionally import only needed categories (future optimization)
- **Governance:** Clear structure aligns with `STANDARDS_POWERSHELL.md` best practice

**Risks & Mitigations:**

| Risk                                             | Mitigation                                                                         |
| ------------------------------------------------ | ---------------------------------------------------------------------------------- |
| Circular dependencies between functions          | Dependency audit before splitting; validate import order                          |
| Breaking changes to callers                      | None expected; public API unchanged; all functions remain private                 |
| Increased file count complexity                  | Use subdirectory structure (`Private/Functions/`) and consistent naming           |
| Import order issues                              | Establish explicit load order in module loader (`.psm1`)                         |
| Loss of function context during migration        | Document function relationships in README or dependency map                      |

### 2.2 Comparison: Monolithic vs. Modular

| Aspect                 | Monolithic                              | Modular                                   |
| ---------------------- | --------------------------------------- | ----------------------------------------- |
| File Navigation        | Slow (9,683 lines)                      | Fast (grep, IDE jump-to-file)             |
| Cognitive Load         | High (single large file)                | Low (50–300 lines per file)               |
| Merge Conflict Risk    | High (all functions in one file)        | Low (different files per category)        |
| Testing Isolation      | Difficult (entire module loads)         | Easy (import specific category)           |
| Future Extensibility   | Hard (all new functions added to file)  | Easy (new files, clear directories)       |
| Documentation          | Single large help blob                  | Distributed; tailored per category       |
| Load Time              | Single dot-source (fast)                | Multiple dot-sources (negligible)        |

### 2.3 Import Overhead

**Negligible:** Dot-sourcing 103 individual files instead of 1 large file adds < 5ms to module load time. No performance penalty justifies maintaining the monolithic structure.

---

## 3. PROPOSED ARCHITECTURE

### 3.1 Directory Structure

```text
WIMWitch-tNG/
├── WIMWitch-tNG.psd1
├── WIMWitch-tNG.psm1          # Updated module loader
├── Public/
│   └── WIMWitch-tNG.ps1
└── Private/
    ├── Functions/              # NEW: Organized function subdirectories
    │   ├── UI/
    │   ├── Administrative/
    │   ├── Configuration/
    │   ├── Logging/
    │   ├── WIMOperations/
    │   ├── Drivers/
    │   ├── Updates/
    │   ├── AppX/
    │   ├── Autopilot/
    │   ├── ISO/
    │   ├── DotNetOneDrive/
    │   ├── LanguagePacksFOD/
    │   ├── ConfigMgr/
    │   ├── Registry/
    │   ├── BootWIM/
    │   └── Utilities/
    ├── Assets/
    │   ├── appxWin10_22H2.psd1
    │   ├── appxWin11_23H2.psd1
    │   ├── appxWin11_24H2.psd1
    │   └── appxWin11_25H2.psd1
    ├── README-Functions.md        # NEW: Guide to function organization
    └── WWFunctions.ps1            # DEPRECATED: Legacy file (kept for rollback)
```

### 3.2 Module Loader Changes

**Current (WIMWitch-tNG.psm1):**

```powershell
$private = @(Get-ChildItem -Path 'Private/*.ps1')
foreach ($import in $private) {
    . $import.FullName
}
```

**Updated (WIMWitch-tNG.psm1):**

```powershell
# Load public functions
$publicFunctions = @(Get-ChildItem -Path 'Public/*.ps1')
foreach ($import in $publicFunctions) {
    . $import.FullName
}

# Load private functions in ordered categories
$privateFunctionDirs = @(
    'Private/Functions/UI',
    'Private/Functions/Administrative',
    'Private/Functions/Configuration',
    'Private/Functions/Logging',
    'Private/Functions/WIMOperations',
    'Private/Functions/Drivers',
    'Private/Functions/Updates',
    'Private/Functions/AppX',
    'Private/Functions/Autopilot',
    'Private/Functions/ISO',
    'Private/Functions/DotNetOneDrive',
    'Private/Functions/LanguagePacksFOD',
    'Private/Functions/ConfigMgr',
    'Private/Functions/Registry',
    'Private/Functions/BootWIM',
    'Private/Functions/Utilities'
)

foreach ($dir in $privateFunctionDirs) {
    $functionFiles = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath $dir) -Filter '*.ps1' -ErrorAction SilentlyContinue)
    foreach ($import in $functionFiles) {
        . $import.FullName
    }
}

Export-ModuleMember -Function 'Invoke-WimWitchTng'
```

**Rationale:**

- Explicit load order prevents circular dependency issues
- Categories load in logical sequence: UI → Admin → Config → Logging → Core Ops → Integrations → Utilities
- Backward compatible: public API unchanged

---

## 3.2 Extraction Methodology

**Problem:** Manually extracting 103 functions from a 9,683-line monolithic file is error-prone. **Solution:** Use automated extraction with per-function validation.

### Extraction Process (Per Category)

1. **Parse the source file using PowerShell AST:**

   ```powershell
   $sourceFile = 'WIMWitch-tNG/Private/WWFunctions.ps1'
   $content = Get-Content -Path $sourceFile -Raw
   $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
   ```

2. **Identify function boundaries by AST token position:**
   - Extract function name, extent (start/end lines), and help blocks
   - Map each function to its target category subdirectory

3. **Extract function + help block to individual file:**
   - Preserve comment-based help verbatim
   - Ensure CRLF line endings (`.Replace('`n', "`r`n")`)
   - Validate UTF-8 encoding

4. **Immediate syntax validation (per function):**

   ```powershell
   Test-ModuleManifest -Path $extractedFile -ErrorAction Stop
   # OR: [System.Management.Automation.PSParser]::Tokenize((Get-Content ...)) -ErrorAction Stop
   ```

5. **Document extraction metadata in validation manifest:**
   - Source file line range
   - Target file path
   - Function name
   - Syntax validation result (✓ Pass / ✗ Fail)
   - Help block status
   - Line count match (source vs. target)

### Batching Strategy

Extract and validate **1–10 functions per batch** (by category), then:

1. Pause for review
2. Update progress tracker
3. Proceed to next batch

**Checkpoint Criteria:** All functions in batch pass syntax validation before proceeding.

**Rollback Trigger:** If any function fails syntax validation:

- Stop extraction
- Investigate root cause (typically misaligned function boundary or malformed help block)
- Document issue in plan notes
- Refine extraction script
- Resume with corrected methodology

---

## 4. PRE-IMPLEMENTATION: BRANCH CREATION

### Step 0: Create Feature Branch

Before any extraction or reorganization work begins, create a dedicated feature branch for this refactoring:

```bash
git checkout -b refactor/wwfunctions-modularization
git push -u origin refactor/wwfunctions-modularization
```

**Rationale:**

- Isolates all 103 function extractions from `main`
- Allows PR review of the entire refactoring before merge
- Enables rollback to `main` if critical issues arise
- Provides a clear git history trail for the refactoring work

**Commit this plan to the branch:**

```bash
git add .github/prompts/plan-20260127-wwfunctions-modularization.md
git commit -m "docs: plan for WWFunctions modularization (Stage 0-2)"
```

---

## 5. IMPLEMENTATION STAGES

### Stage 0: Extract & Intermediate Validation

Checkpoint: All Functions Extracted, Dependency Chain Validated

**Duration:** ~2–3 hours (extraction + validation)

**Objective:** Extract all 103 functions as individual files and validate that dependencies are satisfied using the original load order.

**Steps:**

1. **Create temporary extraction directory** (`Private/Functions-Staging/`) for raw extracted files (no subdirectories yet)

2. **Extract all functions** using AST-based methodology (§3.2):
   - Extract in **exact line-order they appear in WWFunctions.ps1**
   - Document source line range for each function
   - Preserve all help blocks and formatting
   - Each file: CRLF line endings, UTF-8 encoding

3. **Batch validation (1–10 functions per batch):**
   - Validate each extracted file (syntax, help blocks intact)
   - Update Progress Tracker (§8)
   - **Pause for review between batches**

4. **Create temporary loader** (`Private/Functions-Staging.psm1`):

   ```powershell
   # Load private functions in ORIGINAL LINE ORDER from WWFunctions.ps1
   # This order is proven to work; all dependencies are satisfied

   $functionFiles = @(
       'Private/Functions-Staging/Function-001.ps1',  # [function name] - source line X
       'Private/Functions-Staging/Function-002.ps1',  # [function name] - source line Y
       # ... all 103 functions in original sequence
   )

   foreach ($file in $functionFiles) {
       . (Join-Path -Path $PSScriptRoot -ChildPath $file)
   }

   Export-ModuleMember -Function 'Invoke-WimWitchTng'
   ```

5. **Test module import with temporary loader:**
   ```powershell
   # Temporarily swap the .psm1 to use Functions-Staging loader
   Copy-Item WIMWitch-tNG.psm1 WIMWitch-tNG.psm1.backup
   Copy-Item WIMWitch-tNG/Private/Functions-Staging.psm1 WIMWitch-tNG.psm1
   Import-Module WIMWitch-tNG.psd1 -Verbose -Force
   # Expected result: All 103 functions loaded, no "function not found" errors
   ```

**Success Criteria:**

- All 103 functions extracted into individual files (in original order)
- Each file passes PowerShell syntax validation
- Temporary loader created with original line-order sequence
- `Import-Module` succeeds with temporary loader (all functions available, no errors)
- Function calls internal to module work correctly (no "command not found" errors)

**Checkpoint Exit:** Do not proceed to Stage 1 until all criteria pass. If module import fails, investigate the missing function and refine extraction before proceeding.

---

### Stage 1: Reorganize & Finalize

Checkpoint: Functions Organized into Categories, Final Loader Validated

**Duration:** ~2–3 hours (reorganization + validation)

**Objective:** Move extracted functions into logical category subdirectories, create category-aware loader, and finalize structure.

**Steps:**

1. **Create subdirectory structure** under `Private/Functions/` (16 subdirectories per §3.1)

2. **Move extracted functions** from `Private/Functions-Staging/` to category subdirectories:
   - Example: `Private/Functions/UI/`, `Private/Functions/Administrative/`, etc.
   - Preserve filenames and content

3. **Create final loader** (`WIMWitch-tNG.psm1`):
   - Use category-based load order (§3.1)
   - Maintain dependency ordering validated in Stage 0
   - Example structure:

   ```powershell
   # Load private functions in logical categories
   # Load order respects dependencies proven in Stage 0

   $privateFunctionDirs = @(
       'Private/Functions/UI',
       'Private/Functions/Administrative',
       'Private/Functions/Configuration',
       # ... (remaining 13 categories)
   )

   foreach ($dir in $privateFunctionDirs) {
       $functionFiles = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath $dir) -Filter '*.ps1' -ErrorAction SilentlyContinue)
       foreach ($file in $functionFiles) {
           . $file.FullName
       }
   }

   Export-ModuleMember -Function 'Invoke-WimWitchTng'
   ```

4. **Create README-Functions.md** documenting the new structure and category organization

5. **Test module import with final loader:**
   ```powershell
   Remove-Module WIMWitch-tNG -Force -ErrorAction SilentlyContinue
   Import-Module WIMWitch-tNG.psd1 -Verbose
   # Expected result: All 103 functions loaded, no errors
   ```

6. **Clean up temporary files:**
   - Remove `Private/Functions-Staging/` directory
   - Remove `Private/Functions-Staging.psm1`
   - Archive original `WWFunctions.ps1` (if not already archived)

**Success Criteria:**

- All 103 functions extracted into individual files
- Each file passes PowerShell syntax validation
- `Import-Module` reports success with both temporary and final loaders
- All function help blocks intact
- README-Functions.md created and links all files
- No "function not found" or "command not found" errors during import or execution

**Checkpoint Exit:** Do not proceed to Stage 2 until all criteria pass.

---

### Stage 2: Integration Testing

Checkpoint: Module Loads with Final Loader, Public API Functional

**Duration:** ~1–2 hours

1. **Run module tests:**
   - Load module: `Import-Module WIMWitch-tNG -Force`
   - List functions: `Get-Command -Module WIMWitch-tNG -CommandType Function | Measure-Object`
   - Verify count = 1 (only `Invoke-WimWitchTng` exported)
2. **Verify dependency resolution:**
   - Pick 5 internal functions (from different categories)
   - Call them directly: `& { Import-Module WIMWitch-tNG; Get-FormVariables | Measure-Object }`
   - Verify output and no "function not found" errors
3. **Validate public entry point:**
   - `Invoke-WimWitchTng -demomode` (or `-UpdatePoShModules`, etc.)
   - Verify GUI launches (or automation flow runs)
   - Check for internal function call failures

**Success Criteria:**

- Module imports with zero errors
- All 103 private functions available to module
- No "function not found" errors when called
- `Invoke-WimWitchTng` public function executes without regression
- Logging functions work as expected

**Checkpoint Exit:** Do not proceed until all criteria pass.

---

### Stage 3: Cleanup & Deprecation

Checkpoint: Legacy File Retired

**Duration:** ~30 minutes

1. **Backup original file:**
   - Rename `Private/WWFunctions.ps1` → `Private/WWFunctions.ps1.deprecated-20260127`
   - Commit to git with message: "docs: Archive original WWFunctions.ps1 monolithic file (deprecated)"
2. **Add deprecation notice** (if keeping for reference): Comment block at top of `.deprecated` file explaining the refactor
3. **Update .gitignore** (if necessary) to prevent re-inclusion of monolithic file
4. **Document the refactor** in CHANGELOG.md:
   - Date of refactor
   - High-level summary: "Modularized 103 private functions from monolithic WWFunctions.ps1 into organized subdirectories for improved maintainability"
   - Reference to new README-Functions.md

**Success Criteria:**

- Original file archived (`.deprecated`)
- No import errors after archiving
- CHANGELOG.md updated
- README-Functions.md completed

**Checkpoint Exit:** Refactor complete.

---

### Stage 4: Documentation & Knowledge Base

Checkpoint: Handoff Ready

**Duration:** ~1 hour

1. **Create README-Functions.md** with:
   - Directory structure overview
   - Function category descriptions
   - Quick-reference index (function name → file path)
   - Dependency map (which functions call which)
   - Contributing guidelines for future function additions
2. **Update PROJECT_CONTEXT.md** (if necessary):
   - Update file structure diagram to reflect new layout
   - Update "Private/WWFunctions.ps1" section with link to new README-Functions.md
3. **Add inline comments** to module loader (`.psm1`) explaining load order and rationale

**Success Criteria:**

- README-Functions.md complete with all function categories
- Dependency map documented
- PROJECT_CONTEXT.md updated
- All comments added to module loader

---

## 5. ROLLBACK STRATEGY

If significant issues arise during Stage 1–2:

1. **Restore monolithic file:** `git checkout HEAD~1 Private/WWFunctions.ps1`
2. **Revert module loader:** `git checkout HEAD~1 WIMWitch-tNG.psm1`
3. **Clean up partial extraction:** `rm -r Private/Functions/`
4. **Re-test:** `Import-Module WIMWitch-tNG -Force`

**Post-Rollback:** Investigate root cause (typically circular dependencies or conditional function loading) and revise plan.

---

## 6. SUCCESS CRITERIA (Overall)

- All 103 functions extracted into individual `.ps1` files
- Each file has proper CRLF line endings and UTF-8 encoding
- Module loader updated; explicit load order defined
- `Import-Module WIMWitch-tNG` succeeds with zero errors
- All 103 private functions accessible (not exported)
- Public API (`Invoke-WimWitchTng`) works identically to pre-refactor
- README-Functions.md created and maintained
- Original monolithic file archived and deprecated
- CHANGELOG.md updated
- All Markdown files pass CommonMark lint
- All PowerShell files pass PSScriptAnalyzer (custom rules per STANDARDS_POWERSHELL.md)

---

## 7. RISK MITIGATION TABLE

| Risk                                             | Severity | Mitigation                                                    | Owner           |
| ------------------------------------------------ | -------- | ------------------------------------------------------------- | --------------- |
| Circular dependencies between functions          | High     | Dependency audit; test load order                             | Architect       |
| Functions with conditional loading              | Medium   | Scan source file for non-standard patterns; document          | Architect       |
| CRLF/encoding inconsistency on macOS            | Medium   | Explicit line-ending conversion per STANDARDS                 | Architect       |
| Missing function in extracted set                | Low      | Count functions at source and target                          | Architect       |
| Module import regression                         | Medium   | Comprehensive test (Stage 2) before cleanup                   | QA              |
| Documentation lag                                | Low      | README created in parallel; updated before merge              | Documentation   |

---

## 8. PROGRESS TRACKER

| # | Category | Functions | Status | Extracted | Validated | Notes |
|---|----------|-----------|--------|-----------|-----------|-------|
| 1 | Form & UI Controls | 21 | ⏳ NOT STARTED | 0/21 | 0/21 | — |
| 2 | Administrative & Validation | 5 | ⏳ NOT STARTED | 0/5 | 0/5 | — |
| 3 | Configuration Management | 4 | ⏳ NOT STARTED | 0/4 | 0/4 | — |
| 4 | Logging & Output | 4 | ⏳ NOT STARTED | 0/4 | 0/4 | — |
| 5 | WIM Operations | 4 | ⏳ NOT STARTED | 0/4 | 0/4 | — |
| 6 | Driver Management | 3 | ⏳ NOT STARTED | 0/3 | 0/3 | — |
| 7 | Windows Update Management | 13 | ⏳ NOT STARTED | 0/13 | 0/13 | — |
| 8 | AppX Package Management | 2 | ⏳ NOT STARTED | 0/2 | 0/2 | — |
| 9 | Windows Autopilot | 4 | ⏳ NOT STARTED | 0/4 | 0/4 | — |
| 10 | ISO & Media Creation | 5 | ⏳ NOT STARTED | 0/5 | 0/5 | — |
| 11 | .NET & OneDrive | 5 | ⏳ NOT STARTED | 0/5 | 0/5 | — |
| 12 | Language Packs & FODs | 10 | ⏳ NOT STARTED | 0/10 | 0/10 | — |
| 13 | ConfigMgr Integration | 13 | ⏳ NOT STARTED | 0/13 | 0/13 | — |
| 14 | Registry & Customization | 6 | ⏳ NOT STARTED | 0/6 | 0/6 | — |
| 15 | Boot WIM & WinRE | 2 | ⏳ NOT STARTED | 0/2 | 0/2 | — |
| 16 | Utility & Orchestration | 6 | ⏳ NOT STARTED | 0/6 | 0/6 | — |
| | **TOTALS** | **103** | | **0/103** | **0/103** | |

**Status Legend:**

- ⏳ NOT STARTED – Awaiting extraction
- 🔄 IN PROGRESS – Currently extracting/validating
- ✅ COMPLETE – All functions extracted & validated
- ⚠️ ISSUES – Syntax or validation failures (see Notes)

---

## 9. NEXT STEPS

1. **Review this plan** for completeness and feasibility
2. **Approve or request changes** (max 2 clarifications per governance)
3. **Upon approval:** Begin Stage 0, Batch 1 (Extract & validate functions 1–10 in original line order)

**Stage 0, Batch 1 Entry Point (Upon Approval):**

```powershell
# Stage 0: Extract & Intermediate Validation
# Batch 1: Extract functions 1–10 from WWFunctions.ps1 (in original line order)
# - Use extraction methodology (§3.2)
# - Validate each file (syntax, help blocks)
# - Update Progress Tracker
# - Pause for review before Batch 2
#
# Once all 103 functions extracted in original order:
# - Create temporary loader (Private/Functions-Staging.psm1) with original-order dot-sourcing
# - Test: Import-Module with temporary loader
# - If successful → Proceed to Stage 1
# - If fails → Debug and investigate missing dependencies
```

**Questions for clarification (if any):**

1. Should the deprecated `WWFunctions.ps1` remain in the repo (for git history), or should it be deleted after archiving?
2. Are there any internal-only function categories that should be marked with a `[System.ComponentModel.EditorBrowsableAttribute('Never')]` attribute to discourage external use?

---

## APPROVAL RECORD

**Status:** ⏳ AWAITING APPROVAL

- User reviewed Analysis, Assessment, and Stages
- User approved plan
- Approval timestamp: _______________
- Approved by: _______________
- Notes/Changes: _______________

(Once approved, proceed to Stage 1 implementation.)
