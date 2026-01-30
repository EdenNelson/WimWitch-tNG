# Plan: Automate AppX List Generation

**Purpose:** Create support tooling to automate generation of AppX removal lists (appxWin10_22H2.psd1, appxWin11_23H2.psd1, etc.)

**Context:** AppX lists must be generated from actual Windows installations, not media. This requires a separate workflow from the main module maintenance.

---

## Problem Analysis

### Current Process (Manual)

1. Deploy clean Windows reference image (VM or physical)
2. Run `Get-AppxProvisionedPackage -Online | Select-Object PackageFamilyName, DisplayName`
3. Manually analyze and **exclude** system-critical packages (runtime, security, core UI)
4. Manually create comprehensive "safe-to-remove" list in PSD1 format
5. Test that Windows still functions with all listed packages removed
6. Add to repository

**Result:** Users get comprehensive list of removable packages, select what they want via UI

**Time:** 2-3 hours per new Windows version
**Risk:**
- Accidentally excluding removable packages (reduces user options)
- Including system-critical packages (breaks Windows)
- Inconsistent categorization between versions
- Manual process prone to human error
| **WIM Mount** | ❌ Incomplete, misses provisioned packages |
| **Running Windows VM** | ✅ Complete, accurate, real config |
| **VHD Mount** | ⚠️ Complex, still incomplete vs. running OS |

**Conclusion:** Must use running Windows instance with `Get-AppxProvisionedPackage -Online`

---

## Current Filtering Strategy (From Existing Files)

### Safe to Remove (What's in the PSD1 Files)

Comprehensive list of AppX packages users CAN safely choose to remove:
- **Entertainment:** Clipchamp, Solitaire, ZuneMusic, Gaming, Xbox components
- **Information:** Bing News, Bing Weather, Bing Search
- **Utilities:** Paint, Notepad, Todos, Photos, ScreenSketch, Quick Assist
- **Store/Services:** StorePurchaseApp, Office Hub, YourPhone, Dev Home
- **Codecs:** AV1, HEVC, VP9, HEIF, MPEG2, WebMedia, WebP extensions

### Never Include (System-Critical, Always Exclude from List)

Packages that MUST NOT be in the removal list (would break Windows):

**Runtime Dependencies:**
- Microsoft.WindowsAppRuntime.*
- Microsoft.NET.Native.Runtime.*
- Microsoft.NET.Native.Framework.*
- Microsoft.VCLibs.*
- Microsoft.UI.Xaml.*
- Microsoft.WidgetsPlatformRuntime

**Security & Authentication:**
- Microsoft.AAD.BrokerPlugin
- Microsoft.SecHealthUI
- Microsoft.LockApp
- Microsoft.CredDialogHost
- Microsoft.Windows.ParentalControls
- Microsoft.BioEnrollment

**System Core:**
- Microsoft.Windows.ShellExperienceHost
- Microsoft.Windows.StartMenuExperienceHost
- Microsoft.Windows.CloudExperienceHost
- MicrosoftWindows.Client.* (CBS, Core, OOBE)
- Microsoft.Windows.ContentDeliveryManager

**Modern Apps (System-Integrated):**
- Microsoft.MicrosoftEdge*
- MSTeams
- Microsoft.OutlookForWindows

---

## Proposed Solution: Two-Step Automation

### Overview

Create a **two-step workflow** separating data collection from intelligent processing:

**Step 1: Data Collection Script (On Windows VM)**
1. Run on live Windows installation
2. Detect Windows version, build, architecture
3. Extract ALL AppX package details
4. Save raw data as PSD1 file (appxData-Win11-25H2-raw.psd1)
5. No filtering, no decisions—just data capture

**Step 2: AI Agent Processing (In VSCode)**
1. Load raw data PSD1 file
2. Apply filtering logic via AI prompt + rules
3. Categorize packages (Entertainment, Utilities, etc.)
4. Generate final appxWin11_25H2.psd1 for release
5. Human reviews AI output before committing

### Files to Create

```
WimWitch-tNG/
├── tools/
│   ├── Collect-AppxData.ps1          ← NEW: Data collection script (runs on Windows VM)
│   ├── appx-filter.json              ← NEW: Filtering rules (referenced by AI prompt)
│   └── Compare-AppxLists.ps1         ← EXISTING: Compare versions
├── .github/prompts/
│   └── process-appxData.prompt.md    ← NEW: AI agent instructions for processing raw data
```

**Architecture:**
- **Collect-AppxData.ps1:** Runs on Windows VM, gathers raw data, no decisions
- **process-appxData.prompt.md:** Instructions for AI agent to process raw data into final PSD1
- **appx-filter.json:** Exclusion rules referenced by AI prompt (or integrated into prompt)
- **Human oversight:** Reviews AI-generated output before committing

---

## Architecture: Two-Step Workflow

### Step 1: Data Collection (Windows VM)

**Script:** Collect-AppxData.ps1

```
Run on live Windows installation
       ↓
Detect: Version, Build, Architecture
       ↓
Extract ALL AppX packages (Get-AppxProvisionedPackage -Online)
       ↓
Capture: PackageName, DisplayName, Version, Architecture
       ↓
Save raw data → appxData-Win11-25H2-raw.psd1
```

**Output:** Raw data file with ALL packages, no filtering

### Step 2: AI Processing (VSCode)

**Prompt:** process-appxData.prompt.md

```
Load: appxData-Win11-25H2-raw.psd1
       ↓
Apply exclusion rules (never-remove list)
       ↓
Categorize packages (Entertainment, Utilities, etc.)
       ↓
Generate final appxWin11_25H2.psd1
       ↓
Human review → Commit to repository
```

**Output:** Final release-ready PSD1 file

### Single-Pass Exclusion Model

**Goal:** Generate comprehensive list = ALL packages EXCEPT system-critical

**Exclusion List (Never Include in Output):**
- System runtime dependencies (WindowsAppRuntime, VCLibs, UI.Xaml, etc.)
- Security/authentication components (SecHealthUI, LockApp, AAD.BrokerPlugin, etc.)
- Core system UI components (ShellExperienceHost, StartMenu, CloudExperience, etc.)
- Modern apps integrated with Windows (Edge, Teams, Outlook)
- Windows update/servicing components

**Result:** Everything else = safe for users to optionally remove

### Data Collection Script Design

```powershell
Collect-AppxData.ps1 [-OutputPath "./appxData/"]
```

**Parameters:**
- `OutputPath` - Where to save raw data PSD1 (default: ./tools/appxData/)
- `Verbose` - Show package detection progress

**Functionality:**
1. Auto-detect Windows version from registry
2. Extract build number, architecture, edition
3. Run `Get-AppxProvisionedPackage -Online`
4. Capture ALL packages with full metadata
5. Save as PSD1: `appxData-Win{Version}-{Build}-raw.psd1`

**No filtering, no decisions—pure data collection**

### AI Prompt File Design

**File:** `.github/prompts/process-appxData.prompt.md`

**Purpose:** Instruct AI agent how to process raw data into final PSD1

**Contents:**
1. Task description
2. Input file location
3. Exclusion rules (reference appx-filter.json OR inline)
4. Categorization guidelines
5. Output format specification
6. Safety checklist
7. Examples of good categorization

### Implementation Strategy

```powershell
function Generate-AppxList {
    param(
        [ValidateSet('Win10-22H2','Win11-23H2','Win11-24H2','Win11-25H2')]
        [string]$WindowsVersion,
        [string]$OutputPath = "../WIMWitch-tNG/Private/Assets/"
    )

    # Step 1: Validate
    # - Check running Windows version matches target
    # - Extract build number, architecture

    # Step 2: Extract ALL packages
    $allPackages = Get-AppxProvisionedPackage -Online

    # Step 3: Load exclusion list
    $excludeList = Load-ExclusionList  # System-critical packages to EXCLUDE

    # Step 4: Filter (inverse logic)
    $safeToRemovePackages = $allPackages | Where-Object {
        $pkg = $_.PackageName
        -not ($pkg -match $excludeList)
    }

    # Step 5: Categorize by type
    $categories = Categorize-Packages -Packages $safeToRemovePackages

    # Step 6: Generate PSD1
    $psd1 = @{
        WindowsVersion = '25H2'
        WindowsBuild = '10.0.26200'
        Architecture = 'arm64,x64,neutral'
        GeneratedDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TotalPackagesOnSystem = $allPackages.Count
        SystemCriticalExcluded = $excludeList.Count
        SafeToRemoveCount = $safeToRemovePackages.Count
        Categories = $categories
        Packages = $safeToRemovePackages.PackageName
    }

    Export-PowerShellDataFile -Path $outputPath -Data $psd1

    # Step 7: Generate validation report
    Write-ValidationReport -All $allPackages -SafeToRemove $safeToRemovePackages
}
```

---

## Supporting Artifact: appx-filter.json

Controls **exclusion logic** using regex patterns (what to REMOVE from the list, not add).

```json
{
  "metadata": {
    "description": "AppX exclusion rules - packages that MUST NOT be in removal list",
    "version": "1.0",
    "lastUpdated": "2026-01-19",
    "author": "WimWitch-tNG Maintainers"
  },

  "neverIncludeInRemovalList": [
    "Microsoft\\.WindowsAppRuntime\\.",
    "Microsoft\\.NET\\.Native\\.",
    "Microsoft\\.VCLibs\\.",
    "Microsoft\\.UI\\.Xaml\\.",
    "Microsoft\\.WidgetsPlatformRuntime",
    "Microsoft\\.Windows\\.ShellExperienceHost",
    "Microsoft\\.Windows\\.StartMenuExperienceHost",
    "Microsoft\\.Windows\\.CloudExperienceHost",
    "Microsoft\\.Windows\\.ContentDeliveryManager",
    "MicrosoftWindows\\.Client\\.",
    "Microsoft\\.AAD\\.BrokerPlugin",
    "Microsoft\\.SecHealthUI",
    "Microsoft\\.LockApp",
    "Microsoft\\.CredDialogHost",
    "Microsoft\\.MicrosoftEdge",
    "MSTeams",
    "Microsoft\\.OutlookForWindows"
  ],

  "categories": {
    "Entertainment": [
      "Clipchamp\\.",
      "Microsoft\\.MicrosoftSolitaireCollection",
      "Microsoft\\.ZuneMusic",
      "Microsoft\\.GamingApp",
      "Microsoft\\.Xbox"
    ],
    "Information": [
      "Microsoft\\.BingNews",
      "Microsoft\\.BingWeather",
      "Microsoft\\.BingSearch"
    ],
    "Utilities": [
      "Microsoft\\.Paint",
      "Microsoft\\.WindowsNotepad",
      "Microsoft\\.Todos",
      "Microsoft\\.Windows\\.Photos",
      "Microsoft\\.ScreenSketch",
      "Microsoft\\.QuickAssist",
      "Microsoft\\.GetHelp",
      "Microsoft\\.WindowsFeedbackHub"
    ],
    "Store_Services": [
      "Microsoft\\.StorePurchaseApp",
      "Microsoft\\.MicrosoftOfficeHub",
      "Microsoft\\.YourPhone",
      "Microsoft\\.Windows\\.DevHome"
    ],
    "Codecs_Extensions": [
      ".*VideoExtension",
      ".*ImageExtension"
    ]
  },

  "versionOverrides": {
    "Win11-25H2": {
      "neverIncludeInRemovalList": [
        "Microsoft\\.Backup"
      ]
    }
  }
}
```

---

## Workflow: How to Use This Tool

### For Maintainers (When New Windows Version Released)

**Step 1: Data Collection (On Windows VM)**

```powershell
# 1. Deploy clean reference VM
#    - Install Windows 11 25H2
#    - Complete OOBE without Microsoft account
#    - DO NOT install optional updates/features yet

# 2. Copy data collection script to VM
Copy-Item "Collect-AppxData.ps1" -Destination "C:\Temp\"

# 3. Run data collection
cd C:\Temp
.\Collect-AppxData.ps1 -Verbose

# Output: appxData-Win11-25H2-Build26200-raw.psd1
# Contains: 342 total packages (unfiltered)

# 4. Copy raw data file back to development machine
Copy-Item "appxData-Win11-25H2-Build26200-raw.psd1" `
          -Destination "~/Documents/GitHub/WimWitch-tNG/tools/appxData/"
```

**Step 2: AI Processing (In VSCode)**

```powershell
# 5. Open VSCode with WimWitch-tNG workspace
cd ~/Documents/GitHub/WimWitch-tNG
code .

# 6. Reference the AI prompt file in GitHub Copilot Chat
# Type in chat: "@workspace Use #file:process-appxData.prompt.md to process
#               tools/appxData/appxData-Win11-25H2-Build26200-raw.psd1"

# 7. AI agent will:
#    - Load raw data file
#    - Apply exclusion filters from appx-filter.json
#    - Categorize packages
#    - Generate appxWin11_25H2.psd1
#    - Show diff vs. appxWin11_24H2.psd1

# 8. Review AI output
#    - Check no system-critical packages in list
#    - Verify categorization makes sense
#    - Validate new packages are appropriate
```

**Step 3: Validation & Testing**

```powershell
# 9. Test generated file with Pester
./build.ps1 -Task Pester

# 10. Manual validation on test VM
#     - Mount Windows 11 25H2 reference image
#     - Use DISM to apply AppX removal with new list
#     - Verify Windows still boots and functions
#     - Check Settings, Store, Search all work

# 11. Commit and create PR
git add WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1
git commit -m "Add AppX removal list for Windows 11 25H2"
git push -u origin feature/win11-25h2-support
# Create PR for code review before merge
```

### AI Agent Workflow (What Happens in Step 2)

When you reference the prompt in GitHub Copilot Chat, the AI will:

1. **Load raw data:** Read `appxData-Win11-25H2-Build26200-raw.psd1`
2. **Load exclusion rules:** Read `tools/appx-filter.json`
3. **Apply filtering:** Exclude system-critical packages
4. **Categorize:** Sort remaining packages into categories
5. **Generate PSD1:** Create `appxWin11_25H2.psd1` in standard format
6. **Create diff report:** Compare to previous version
7. **Safety check:** Verify no system-critical packages in output
8. **Present for review:** Show output + diff for human validation
#    - Review packages marked for removal
#    - Verify no system packages in removal list
#    - Check SAFETY VALIDATION: PASSED in report

# 5. Test removal (manual)
#    - Mount Windows 11 25H2 reference image
#    - Use DISM to apply AppX removal with new list
#    - Verify Windows still boots and functions
#    - Check Settings, Store, Search all work

# 6. Run automated tests
./build.ps1 -Task Pester
# Must pass: validates PSD1 format, no duplicates, no neverRemove violations

# 7. Commit and create PR
git add ../WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1
git commit -m "Add AppX removal list for Windows 11 25H2"
git push -u origin feature/win11-25h2-support
# Create PR for code review before merge
```

### Review Report Example

```
AppX List Generation Report: Windows 11 25H2
=============================================
Generated: 2026-01-19 14:32:15
Running Windows: 11 25H2 (10.0.26200.2345) arm64

VALIDATION STATUS: ✅ PASSED
  - No neverRemove violations
  - All patterns matched successfully
  - Cross-version compatibility verified

Package Statistics:
  Total packages on system: 342
  Safe to remove: 156
  System-critical (excluded): 186

Categorization:
  Entertainment: 18 packages
  Information: 3 packages
  Utilities: 32 packages
  Store/Services: 15 packages
  Codecs/Extensions: 88 packages

Changes from Windows 11 24H2:
  ✓ New packages (7):
    - Microsoft.Backup_1.0.0.0_arm64__8wekyb3d8bbwe
    - [6 more new packages]
  ✗ Removed packages (2):
    - [packages no longer in 25H2]
  ↻ Modified versions (23):
    - Microsoft.Paint: 11.2302.20.0 → 11.2511.291.0
    - [22 more version updates]

OUTPUT:
  ✓ appxWin11_25H2.psd1 created
  ✓ Test with: ./build.ps1 -Task Pester

NEXT STEPS:
  1. Review packages in appxWin11_25H2-review.txt
  2. Test removal on reference system
  3. Run Pester tests
  4. Create PR for review
```

---

## Implementation Phases

### Phase 1: Data Collection Script (3-4 hours)

**Files to Create:**
- `tools/Collect-AppxData.ps1` (data collection script)
- `tools/appxData/` (directory for raw data files)

**Features:**
1. Auto-detect Windows version, build, architecture
2. Extract ALL AppX packages (no filtering)
3. Capture full package metadata
4. Save as PSD1 with metadata header
5. Simple, focused script—just data collection

**Success Criteria:**
- ✅ Script runs on Windows 10/11 without errors
- ✅ Detects version correctly (22H2, 23H2, 24H2, 25H2)
- ✅ Captures all packages from Get-AppxProvisionedPackage
- ✅ Saves readable PSD1 file
- ✅ No filtering logic—pure data capture

### Phase 2: AI Prompt File (2-3 hours)

**Files to Create:**
- `.github/prompts/process-appxData.prompt.md` (AI instructions)
- `tools/appx-filter.json` (exclusion rules, if not integrated in prompt)

**Features:**
1. Clear task description for AI agent
2. Step-by-step processing instructions
3. Exclusion rules (inline or reference to JSON)
4. Categorization guidelines with examples
5. Output format specification
6. Safety validation checklist

**Success Criteria:**
- ✅ AI agent can process raw data without human intervention
- ✅ Generated PSD1 matches format of existing files
- ✅ No system-critical packages in output
- ✅ Categorization consistent with existing files
- ✅ Human review can validate in <5 minutes

### Phase 3: Testing & Documentation (2-3 hours)

**Testing:**
1. **Data Collection Testing:**
   - Run Collect-AppxData.ps1 on Windows 10 22H2 VM
   - Run on Windows 11 24H2 VM
   - Run on Windows 11 25H2 VM
   - Verify all produce valid PSD1 files
   - Verify package counts are reasonable (300-400)

2. **AI Processing Testing:**
   - Process existing version raw data (Win11-24H2)
   - Compare AI output to existing appxWin11_24H2.psd1
   - Verify categorization matches
   - Verify no system-critical packages in output
   - Process new version raw data (Win11-25H2)
   - Validate output looks correct

**Documentation:**
- Create `tools/COLLECT_APPX_DATA_README.md`
  - How to run data collection script
  - How to use AI prompt for processing
  - Safety mechanisms explained
  - Troubleshooting guide
  - Step-by-step workflow

**Success Criteria:**
- ✅ Data collection works on all supported Windows versions
- ✅ AI agent consistently produces correct output
- ✅ Documentation clear for non-technical maintainers
- ✅ No edge cases missed
- ✅ Process takes <30 minutes total (vs. 2-3 hours manual)

### Phase 4: CI/CD Integration (2-3 hours, Future)

**Not in initial release, add when stable:**
1. GitHub Actions validates any new AppX files
2. CI fails if duplicates detected
3. CI fails if neverRemove violations found
4. CI passes if format correct + Pester tests pass

**Success Criteria:**
- ✅ CI gates prevent malformed AppX files
- ✅ CI catches safety violations early
- ✅ No invalid files merged to main

### Phase 5: FOD Generation Tool (6-10 hours, Future)

**Similar pattern to AppX:**
- Extract Features on Demand from running Windows
- Apply filtering rules (never-remove similar list)
- Generate fodWin*.psd1 files
- Same safety + validation approach

---

## Timeline & Effort Summary

| Phase | Hours | Timeline |
|-------|-------|----------|
| Phase 1: Data collection script | 3-4 | Week 1 |
| Phase 2: AI prompt file | 2-3 | Week 1 |
| Phase 3: Testing & docs | 2-3 | Week 2 |
| Phase 4: CI/CD integration | 2-3 | Future (after stable) |
| Phase 5: FOD generation tool | 4-6 | Future (after AppX proven) |
| **Total (Phases 1-3)** | **7-10 hours** | **2 weeks** |
| **Total (All Phases)** | **13-19 hours** | **4-6 weeks** |

---

## Integration with Maintainability Plan

This two-step automation tool is **complementary** to the main maintainability plan:

- **NOT part of Phases 1-3** of maintainability plan (those handle core automation)
- **Complements Phase 2** of main plan (supports Windows version contributions)
- Can run **parallel** to main plan or **after** Phase 1 completes
- Reduces Windows version addition time from **2-3 hours → 20-30 minutes**

### How It Enables Community

1. **Lowers barrier:** Contributors can run simple data collection script on reference VM
2. **Safety:** AI applies exclusion rules consistently, human reviews output
3. **Transparency:** Raw data files + AI prompt make process auditable
4. **Consistency:** All AppX files follow same pattern + format (AI ensures this)
5. **Verification:** Pester tests validate before PR submission
6. **Learning tool:** Contributors see how AI processes data, can improve prompt over time

### Advantages of Two-Step Approach

1. **Simplicity:** Data collection script is ~50 lines (easy to maintain)
2. **Flexibility:** Can reprocess raw data without re-running on Windows
3. **Auditability:** Raw data files preserved in repository (can verify AI decisions)
4. **Improvability:** Refine AI prompt without touching Windows script
5. **Collaboration:** Contributors provide raw data, maintainers review AI output
6. **AI Learning:** As AI improves, same raw data can produce better results

---

## Key Design Decisions

### 1. Two-Step Architecture (Critical)

**Decision: Separate data collection from intelligent processing**

**Step 1 - Data Collection (Windows VM):**
- Simple PowerShell script
- No filtering, no decisions
- Just gathers raw AppX package data
- Outputs raw PSD1 file

**Step 2 - AI Processing (VSCode):**
- AI agent reads raw data
- Applies filtering logic via prompt
- Makes categorization decisions
- Generates final release PSD1
- Human reviews before commit

**Benefits:**
- Keeps Windows script simple (easier to maintain)
- Leverages AI for intelligent categorization
- Human oversight at decision point (not data collection)
- Can reprocess raw data without re-running on Windows
- AI can learn/improve over time

### 2. Running Windows Required (For Data Collection)

**Decision: Yes, running Windows instance required for Step 1**
- Cannot extract provisioned packages from media/WIM
- Must use `Get-AppxProvisionedPackage -Online`
- Maintainer must deploy reference VM
- But only for data collection (Step 1)

### 3. AI Prompt vs. Complex Script

**Decision: Use AI prompt for filtering/categorization (Step 2)**
- More flexible than hardcoded script logic
- Can adapt to edge cases naturally
- Human can review/adjust AI decisions
- Easier to update rules (edit prompt vs. code)
- Leverages strengths of AI (pattern recognition, categorization)

### 4. Initial Release Scope

**Decision: Two-step workflow (Phases 1-3 only)**
- Data collection script (Phase 1)
- AI prompt for processing (Phase 2)
- Testing & documentation (Phase 3)
- FOD generation deferred to Phase 5 (after proven stable)
- CI/CD integration deferred to Phase 4
- Manual maintainer workflow initially

**Total effort: 7-10 hours vs. 11-15 hours for single-script approach**

---

## Future Enhancements (Not in Initial Plan)

1. **Remote Windows Support** - Connect to reference VM via PowerShell remoting (collect data without copying script)
2. **Enhanced AI Categorization** - Learn from maintainer decisions over time, improve pattern recognition
3. **Automated PR Creation** - AI agent creates PR directly with generated file
4. **Interactive Review Mode** - AI presents packages one category at a time for human approval
5. **FOD Generation Tool** - Similar two-step approach for Features on Demand
6. **Language Pack Support** - Generate LANGUAGE_PACKS.md entries
7. **Multi-Version Batch Processing** - Process multiple raw data files at once

---

## File Flow Summary

**What files exist where:**

1. **On Windows VM (temporary):**
   - `Collect-AppxData.ps1` (copied to VM, run once)
   - `appxData-Win11-25H2-Build26200-raw.psd1` (generated, copied back)

2. **In repository - tools/:**
   - `Collect-AppxData.ps1` (source for data collection)
   - `appx-filter.json` (exclusion rules for AI)
   - `appxData/` (directory for raw data files)
     - `appxData-Win10-22H2-Build19045-raw.psd1`
     - `appxData-Win11-24H2-Build26100-raw.psd1`
     - `appxData-Win11-25H2-Build26200-raw.psd1`
   - `Compare-AppxLists.ps1` (existing tool)

3. **In repository - .github/prompts/:**
   - `process-appxData.prompt.md` (AI instructions for processing raw data)

4. **In repository - WIMWitch-tNG/Private/Assets/:**
   - `appxWin10_22H2.psd1` (final release file, generated by AI)
   - `appxWin11_23H2.psd1` (final release file)
   - `appxWin11_24H2.psd1` (final release file)
   - `appxWin11_25H2.psd1` (final release file, NEW from AI processing)

**Key distinction:**
- Raw data files (`appxData-*.psd1`) = ALL packages from Windows, no filtering
- Release files (`appxWin*.psd1`) = Filtered safe-to-remove packages for users

---

## Safety Checklist

**Step 1: Data Collection (Collect-AppxData.ps1)**

- [ ] Running Windows version detected correctly
- [ ] Build number extracted and recorded
- [ ] Architecture detected (AMD64, ARM64, neutral)
- [ ] All packages captured from Get-AppxProvisionedPackage
- [ ] Total package count reasonable (300-450 typical)
- [ ] Raw PSD1 file created successfully
- [ ] Metadata header complete

**Step 2: AI Processing (AI Agent + process-appxData.prompt.md)**

- [ ] Raw data file loaded successfully
- [ ] Exclusion rules applied from appx-filter.json
- [ ] NO system-critical packages in final output
- [ ] All packages properly categorized
- [ ] Categories match existing file structure
- [ ] PSD1 format matches existing files
- [ ] Header includes timestamp, version, build, architecture
- [ ] Diff report shows changes vs. previous version
- [ ] Human reviews output before committing

---

**End of Plan: Automate AppX List Generation (Two-Step Architecture)**
