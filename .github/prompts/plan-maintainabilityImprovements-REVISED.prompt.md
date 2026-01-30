# Plan: WimWitch-tNG Maintainability Improvements (REVISED)

**Project:** WimWitch-tNG
**Version:** 5.0-beta
**Date:** January 19, 2026
**Purpose:** Establish automation infrastructure, Windows evolution tracking, and maintainer playbook for community-driven, PSGallery-published PowerShell module

**Learning Goals:** Project maintenance patterns + AI orchestration for autonomous updates

---

## Executive Summary

The project has exceptional documentation (944-line AI guide, complete change tracking, 111 documented functions) but lacks automation infrastructure and maintainer processes. This plan addresses critical gaps to enable:

1. **PSGallery publishing** with quality gates
2. **Community contributions** via clear processes
3. **Windows versioning blocker solution** (recurring pain point for former maintainers)
4. **AI-assisted maintenance** playbook for future automation
5. **Code refactoring** using documentation as safety net

**Current State:**
- ✅ Comprehensive code documentation (111 functions fully documented)
- ✅ Detailed AI development guide (PROJECT_CONTEXT.md)
- ✅ Complete change tracking (CHANGELOG.md)
- ✅ Version-specific AppX data files with maintenance instructions
- ✅ Well-documented functions as foundation for future refactoring

**Critical Gaps (in priority order):**
- ❌ No CI/CD pipeline (gates PSGallery releases, prevents regressions)
- ❌ No Windows release tracking system (recurring blocker for maintainers)
- ❌ No build automation (build.ps1 referenced but missing)
- ❌ No release process documentation (needed for contributors + PSGallery)
- ❌ Module dependencies not declared in manifest
- ❌ No contribution guidelines (for community)
- ❌ No AI orchestration playbook (for autonomous maintenance)
- ⚠️ Monolithic WWFunctions.ps1 (refactoring safe due to excellent documentation)

---

## Overview: Three Phases

**Phase 1: Automation Foundation (20-25 hours)** — Enables everything else
**Phase 2: Maintainer Playbook (15-20 hours)** — Guides humans + AI contributors
**Phase 3: Code Organization (10-15 hours)** — Refactor using documentation as safety net

**Total Effort:** 45-60 hours over 6-8 weeks
**Timeline:** ~8-10 hours/week = achievable alongside learning

---

## Phase 1: Automation Foundation (20-25 hours)

### 1.1 Create Windows Version Tracking System

**Priority:** CRITICAL
**Effort:** 4-6 hours
**File:** `WINDOWS_VERSIONS.md`

**Purpose:**
Establish single source of truth for Windows version tracking. This is your insurance policy against the "Windows versioning blocker" that affected former maintainers.

**Contents:** (See original plan Section 1.1 - keep exactly as detailed)

**Key Sections:**
- Supported versions matrix (Win10 22H2, Win11 23H2/24H2/25H2)
- Update checklist (8-step process for new Windows versions)
- Known issues per version
- FOD/LP compatibility matrices

**Integration Points:**
- Link from README.md
- Reference in CONTRIBUTION.md
- Linked from RELEASE_PROCESS.md

**Success Criteria:**
- ✅ All current versions documented
- ✅ Update checklist detailed enough for human OR AI to follow
- ✅ Cross-referenced from main documentation

---

### 1.2 Fix Module Manifest Dependencies

**Priority:** CRITICAL
**Effort:** 1 hour
**File:** `WIMWitch-tNG/WIMWitch-tNG.psd1`

**Current State (Line 97):**
```powershell
# RequiredModules   = @()
```

**Change To:**
```powershell
# Required modules for core functionality
RequiredModules = @(
    @{
        ModuleName = 'OSDSUS'
        ModuleVersion = '21.0.0.0'
    }
    @{
        ModuleName = 'OSDUpdate'
        ModuleVersion = '21.0.0.0'
    }
)
```

**Add to NOTES Section:**
```powershell
.NOTES
    Required Modules:
    - OSDSUS 21.0.0.0+ (Windows Update catalog access)
    - OSDUpdate 21.0.0.0+ (Windows Update management)
```

**Success Criteria:**
- ✅ Module fails gracefully if dependencies not installed
- ✅ Clear error message directs users to install required modules

---

### 1.3 Create build.ps1 Automation Script

**Priority:** CRITICAL (tasks.json references it)
**Effort:** 3-4 hours
**File:** `build.ps1` (root directory)

**Purpose:**
Implement build automation referenced in `.vscode/tasks.json` but currently missing.

**Functions needed:**
- `Clean` - Remove build artifacts
- `Test` - Run Pester + PSScriptAnalyzer
- `Analyze` - Run PSScriptAnalyzer only
- `Pester` - Run Pester tests only
- `Build` - Create distributable module
- `Publish` - Publish to PSGallery

**Key requirement:** All tasks from `.vscode/tasks.json` must work.

**Success Criteria:**
- ✅ `./build.ps1 -Task Clean` removes build artifacts
- ✅ `./build.ps1 -Task Test` runs Pester + Analyzer, exits 1 if failures
- ✅ `./build.ps1 -Task Build` creates BuildOutput/WIMWitch-tNG
- ✅ `./build.ps1 -Task Publish` works with $env:PSGALLERY_API_KEY

---

### 1.4 Implement CI/CD Pipeline

**Priority:** CRITICAL
**Effort:** 8-12 hours
**Files to Create:**
- `.github/workflows/ci.yml` - Run tests on every commit/PR
- `.github/workflows/release.yml` - Auto-publish on version tags

**Requirements:**
- **CI workflow** triggers on: push to main/develop, all PRs
  - Installs dependencies (Pester, PSScriptAnalyzer, OSDSUS, OSDUpdate)
  - Runs PSScriptAnalyzer (exit 1 if issues)
  - Runs Pester tests (exit 1 if failures)
  - Validates AppX/FOD files (no duplicates, correct format)
  - Uploads test results as artifact

- **Release workflow** triggers on: `git tag v*`
  - Runs full test suite
  - Creates GitHub Release with changelog
  - Publishes to PSGallery (if not -beta tag)

**Success Criteria:**
- ✅ CI runs on every push/PR
- ✅ Tests must pass before merge (branch protection)
- ✅ Releases auto-publish to PSGallery
- ✅ Release workflow has safety checks

---

### 1.5 Create Basic Pester Tests

**Priority:** CRITICAL
**Effort:** 2-3 hours
**Files to Create:**
- `tests/Module.Tests.ps1` - Module structure tests
- `tests/AppX.Tests.ps1` - AppX file format validation
- `.markdownlint.json` - Markdown linting config

**Minimum Coverage:**
- Module imports successfully
- All AppX files load without errors
- AppX files have no duplicate packages
- AppX files have proper documentation headers
- Function exports are available

**Success Criteria:**
- ✅ `./build.ps1 -Task Pester` passes all tests
- ✅ Tests catch malformed AppX files
- ✅ CI runs tests automatically
- ✅ CI fails if tests fail (gate for PRs)

---

## Phase 2: Maintainer Playbook (15-20 hours)

These documents are the "spec" that guides human contributors and AI agents in maintaining this project. They solve the Windows versioning blocker and enable community contributions.

### 2.1 Create RELEASE_PROCESS.md

**Priority:** CRITICAL
**Effort:** 3-4 hours
**File:** `RELEASE_PROCESS.md`

**Purpose:**
Clear, step-by-step process for releasing updates to PSGallery. Answers: "How do I cut a release?"

**Sections:**
1. Release types (patch, minor, major)
2. Release checklist (version bumps, changelog, testing, tagging)
3. Version numbering (current: 5.0-beta → future: YYYY.M.D format)
4. PSGallery workflow (automatic on tag, manual trigger available)
5. Rollback procedure (if critical bugs found)
6. Special case: Adding new Windows version (links to WINDOWS_VERSIONS.md)
7. Notes for AI-assisted releases (how to delegate to agents)

**Key Point:** Steps must be executable by humans OR AI agents.

**Success Criteria:**
- ✅ Process is clear enough for both humans and AI
- ✅ Version numbering explained (date-based format)
- ✅ Windows version support changes are documented
- ✅ Rollback procedure exists

---

### 2.2 Create CONTRIBUTION.md

**Priority:** CRITICAL
**Effort:** 2-3 hours
**File:** `CONTRIBUTION.md`

**Purpose:**
Guide for community contributors (or AI agents). Answers: "How do I contribute?"

**Sections:**
1. Welcome message
2. Types of contributions (bugs, Windows versions, code quality, docs)
3. **Windows version support** - Most common contribution
   - Reference WINDOWS_VERSIONS.md checklist
   - Step-by-step (create AppX/FOD files, update code, test, PR)
4. Development setup (dependencies)
5. PR checklist (tests pass, no linting errors, docs updated)
6. Questions/issues (reference docs, open discussions)

**Key Point:** Windows version addition should be self-serve using WINDOWS_VERSIONS.md checklist.

**Success Criteria:**
- ✅ Clear on-ramp for new contributors
- ✅ Windows version support process is self-serve (reference WINDOWS_VERSIONS.md)
- ✅ Usable by both humans and AI agents
- ✅ PR requirements documented

---

### 2.3 Create DEPRECATION_POLICY.md

**Priority:** HIGH
**Effort:** 2-3 hours
**File:** `DEPRECATION_POLICY.md`

**Purpose:**
Communicate how features are deprecated, giving users/contributors confidence about code stability.

**Sections:**
1. Principles (stability first, long notice, clear communication)
2. Deprecation lifecycle (Announcement → Warning → Removal)
3. Examples (Windows version deprecation, function deprecation)
4. For contributors (discuss first, follow phases, provide migration path)

**Success Criteria:**
- ✅ Contributors understand what can/can't change
- ✅ Users have migration path for breaking changes
- ✅ Prevents accidental breaking changes

---

### 2.4 Update COMPATIBILITY_MATRIX.md

**Priority:** HIGH
**Effort:** 4-6 hours
**File:** `COMPATIBILITY_MATRIX.md`

**Purpose:**
Comprehensive compatibility reference for users and contributors.

**Sections:**
1. PowerShell versions (5.1, 7.x support status)
2. Windows versions (Win10 22H2, Win11 23H2/24H2/25H2)
3. Architecture (x64, x86, ARM64)
4. Module dependencies (required + optional)
5. Known issues per version
6. Feature compatibility (driver injection, updates, AppX removal)
7. Testing matrix (what's tested vs pending)
8. Upgrade paths (4.0.1 → 5.0-beta)
9. End of life schedule

**Key Point:** Users read this to know if version X works on their system.

**Success Criteria:**
- ✅ Matrix covers all major dimensions
- ✅ Known issues documented per version
- ✅ Upgrade paths defined
- ✅ Testing status tracked

---

## Phase 3: Code Organization (10-15 hours)

### 3.1 Refactor WWFunctions.ps1 into Category-Based Modules

**Priority:** MEDIUM (after Phase 1 & 2, but BEFORE first public release)
**Effort:** 10-15 hours
**Rationale:** Excellent documentation makes refactoring safe. Improves maintainability, enables smaller PRs, improves AI autonomy.

**Current State:**
Monolithic `WWFunctions.ps1` (9,666 lines, 105 functions)

**Target Structure:**
```
WIMWitch-tNG/Private/
├── Core/
│   ├── Core-Initialization.ps1
│   ├── Core-Orchestration.ps1
│   └── Core-Logging.ps1
├── Windows/
│   ├── Windows-Detection.ps1
│   ├── Windows-Version.ps1
│   └── Windows-Updates.ps1
├── Image/
│   ├── Image-AppX.ps1
│   ├── Image-Drivers.ps1
│   ├── Image-Features.ps1
│   └── Image-Registry.ps1
├── Integration/
│   ├── Integration-ConfigMgr.ps1
│   └── Integration-Autopilot.ps1
├── UI/
│   ├── UI-XAML.ps1
│   └── UI-Dialogs.ps1
├── Utilities/
│   ├── Utilities-Validation.ps1
│   └── Utilities-Conversion.ps1
└── [Existing Assets folder]
```

**Process:**
1. Use existing documentation (every function already documented) as safety net
2. Organize by functional category (17-18 categories)
3. Create category directories + files
4. Move functions using find/replace (safe because docs identify them)
5. Update imports in WIMWitch-tNG.psm1 (dot-source category files)
6. Test: `./build.ps1 -Task Test` (must pass with 0 failures)
7. Commit by category for clear history

**AI Opportunity:**
This is **ideal for AI-assisted execution:**
- You: "Move all AppX-related functions to Image-AppX.ps1"
- AI reads documentation, identifies functions, creates file, updates imports
- You: Review + approve
- Tests validate correctness

**Safety Net:**
- Every function already has full documentation
- Pester tests catch if anything breaks
- No code logic changes, only organization
- Easy rollback if needed

**Success Criteria:**
- ✅ All 105 functions present in new structure
- ✅ `./build.ps1 -Task Test` passes with 0 failures
- ✅ No code changes, only organization
- ✅ File size limits (no file >500 lines)
- ✅ Category logic is clear to future maintainers
- ✅ Imports in .psm1 updated correctly

**Not Included:**
- XAML extraction (keep in code for now, can extract later if needed)

---

## Additional Guidance: AI Orchestration Playbook

Since you're learning AI agent orchestration, here's how to use this project as a learning vehicle:

### Pattern 1: Structured Task Automation (Windows Version Addition)

**What an AI agent can do autonomously:**
```
Prompt: "Add Windows 11 26H2 support.
Reference WINDOWS_VERSIONS.md update checklist.
- Create appxWin11_26H2.psd1
- Create fodWin11_26H2.psd1
- Update functions in WWFunctions.ps1
- Update WINDOWS_VERSIONS.md
- Update COMPATIBILITY_MATRIX.md
- Run tests
- Create PR"
```

**Why this works:**
- WINDOWS_VERSIONS.md has exact checklist
- AppX files have standardized format + documentation
- Tests validate correctness automatically
- Clear success criteria (PR passes CI)

**Your role:** Review PR before merging

### Pattern 2: Release Automation

**What an AI agent can do autonomously:**
```
Prompt: "Release version 2026.1.1.
Reference RELEASE_PROCESS.md.
- Update version numbers in [files]
- Update CHANGELOG.md with [notes]
- Run tests
- Create PR"
```

**Why this works:**
- RELEASE_PROCESS.md documents exact steps
- Version numbering is mechanical
- Tests validate automatically
- You review before tagging

**Your role:** Verify changelog + tag release (triggers automatic publish)

### Pattern 3: Documentation-Guided Refactoring (WWFunctions.ps1)

**What an AI agent can do with safety:**
```
Prompt: "Refactor WWFunctions.ps1 into category-based files.
Reference the categories in the maintainability plan.
- Create Windows-Detection.ps1
- Move Windows detection functions there
- Update WIMWitch-tNG.psm1 imports
- Run tests to verify nothing broke"
```

**Why this works:**
- Every function already documented with purpose
- Category structure defined in this plan
- Tests catch if anything breaks
- Clear success = all tests pass

**Your role:** Review file organization + refactoring quality

### Key Learning Points

1. **Documentation is your spec** - Good docs enable AI autonomy
2. **Testing is your safety net** - Automated tests catch mistakes
3. **Clear success criteria** - "Tests pass" = done, not vague
4. **Human review remains critical** - AI handles mechanics, you handle decisions
5. **Checklists are executable** - WINDOWS_VERSIONS.md checklist can be automated

---

## Implementation Timeline

### Weeks 1-2: Automation Foundation (Highest ROI first)
- ✅ 1.2 Fix module manifest dependencies (1 hour)
- ✅ 1.3 Create build.ps1 (3-4 hours)
- ✅ 1.1 Create WINDOWS_VERSIONS.md (4-6 hours)
- ✅ 1.4 Implement CI/CD (.github/workflows) (8-12 hours)
- ✅ 1.5 Create basic Pester tests (2-3 hours)

**Deliverable:** Ready to publish to PSGallery with quality gates

### Weeks 3-4: Maintainer Playbook (Enable contributors)
- ✅ 2.1 Create RELEASE_PROCESS.md (3-4 hours)
- ✅ 2.2 Create CONTRIBUTION.md (2-3 hours)
- ✅ 2.3 Create DEPRECATION_POLICY.md (2-3 hours)
- ✅ 2.4 Update COMPATIBILITY_MATRIX.md (4-6 hours)

**Deliverable:** Clear playbook for human + AI contributors

### Weeks 5-8: Code Organization (Leverage documentation)
- ✅ 3.1 Refactor WWFunctions.ps1 into categories (10-15 hours)

**Deliverable:** Maintainable, modular code structure

### After Release v1 to PSGallery
- Gather community feedback
- Adjust based on actual usage patterns

---

## Success Criteria

**Phase 1 Complete (Ready for PSGallery) When:**
- ✅ `./build.ps1 -Task Test` passes with 0 failures
- ✅ CI/CD pipeline runs on all PRs + commits
- ✅ build.ps1 working with Clean, Test, Analyze, Build, Publish tasks
- ✅ Module dependencies (OSDSUS, OSDUpdate) declared in manifest
- ✅ WINDOWS_VERSIONS.md established with update checklist
- ✅ Pester tests validate critical data structures
- ✅ GitHub Actions workflows (ci.yml, release.yml) functional

**Phase 2 Complete (Enable Community) When:**
- ✅ RELEASE_PROCESS.md executable by humans and AI
- ✅ CONTRIBUTION.md on-ramps new contributors
- ✅ DEPRECATION_POLICY.md documents feature lifecycle
- ✅ COMPATIBILITY_MATRIX.md tracks all versions
- ✅ All docs cross-referenced from README.md

**Phase 3 Complete (Refactored) When:**
- ✅ WWFunctions.ps1 split into category-based modules
- ✅ All 105 functions present in new structure
- ✅ `./build.ps1 -Task Test` passes with 0 failures
- ✅ No code logic changed, only organization
- ✅ File sizes reasonable (<500 lines per file)

**Project Maintainability Achieved When:**
- ✅ New Windows versions can be added by AI agent with human review
- ✅ CI/CD catches breaking changes automatically
- ✅ Documentation drives both humans and AI decisions
- ✅ Community contributions follow clear playbook
- ✅ Refactored code easier to maintain and enhance

---

## Estimated Total Effort

| Phase | Hours | Timeline |
|-------|-------|----------|
| Phase 1: Automation Foundation | 20-25 | Weeks 1-2 |
| Phase 2: Maintainer Playbook | 15-20 | Weeks 3-4 |
| Phase 3: Code Organization | 10-15 | Weeks 5-8 |
| **Total** | **45-60 hours** | **6-8 weeks @ 8-10 hrs/week** |

**Flexible approach:** Can publish to PSGallery after Phase 1 completes. Phases 2-3 can happen after release based on feedback.

---

## Next Steps

1. **Confirm Phase 1 priority** - Start with automation foundation
2. **Set PSGallery milestone** - Target first public release after Phase 1
3. **Plan Phase 3 refactoring** - Use excellent documentation as safety net for WWFunctions.ps1 split
4. **AI learning opportunity** - Document which tasks you'll delegate to AI agents
5. **Consider release schedule** - Plan when to cut 5.0-beta → 2026.1.1 release

---

## Key Insights for Your Learning

**On Project Maintenance:**
- Windows versioning IS the blocker → WINDOWS_VERSIONS.md checklist is your insurance policy
- Documentation BEFORE refactoring makes large changes safe
- Clear processes enable delegation (to humans and AI)
- Community contributions thrive with explicit playbooks

**On AI Orchestration:**
- Good documentation = good specs for AI agents
- Tests are your safety net for autonomous work
- Checklists are executable playbooks
- AI handles mechanics; you review decisions
- Structured tasks (Windows versions) are ideal for automation
- Complex decisions (breaking changes) need human judgment

**On This Project Specifically:**
- You've already done the hard part (excellent documentation)
- Phase 1 (automation) gives you confidence gates
- Phase 2 (playbooks) enables community + AI contributions
- Phase 3 (refactoring) is actually low-risk because of your docs

---

**End of Revised Plan**
