# AppX Data Collection & Processing

**Purpose:** Automate the generation of AppX removal lists for new Windows versions using a two-step workflow.

**Author:** Eden Nelson [edennelson]
**Code Origin:** Portions created with GitHub Copilot AI assistance. Author has reviewed all code. Disclosed in interest of transparency.

---

## Overview

This tooling replaces the manual 2-3 hour process of creating AppX removal lists with a 20-30 minute automated workflow:

1. **Step 1:** Run data collection script on Windows VM (5-10 minutes)
2. **Step 2:** Process data with AI agent in VSCode (10-15 minutes)
3. **Step 3:** Review and test output (5-10 minutes)

**Files:**
- `Collect-AppxData.ps1` - Data collection script (runs on Windows VM)
- `appx-filter.json` - Exclusion rules for system-critical packages
- `.github/prompts/process-appxData.prompt.md` - AI agent instructions
- `appxData/` - Directory for raw data files (not committed to repository)

---

## Prerequisites

### For Data Collection (Step 1)

- Clean Windows reference VM or physical machine
- Windows 10 22H2 or Windows 11 23H2/24H2/25H2
- Administrator privileges
- PowerShell 5.1 or later

### For AI Processing (Step 2)

- VSCode with WimWitch-tNG workspace open
- GitHub Copilot enabled
- Raw data file from Step 1

---

## Workflow

### Step 1: Data Collection (On Windows VM)

**1.1. Deploy Clean Reference Windows**

- Install target Windows version (e.g., Windows 11 25H2)
- Complete OOBE (Out of Box Experience)
- **DO NOT:**
  - Sign in with Microsoft account (use local account)
  - Install optional updates
  - Install additional apps or features
  - Run Windows Update (beyond critical security updates)

**1.2. Copy Script to Windows VM**

```powershell
# From your development machine
Copy-Item "Collect-AppxData.ps1" -Destination "\\VM-NAME\C$\Temp\"

# Or download from repository if VM has internet
# https://github.com/YOUR_USERNAME/WimWitch-tNG/raw/main/tools/Collect-AppxData.ps1
```

**1.3. Run Data Collection**

```powershell
# On the Windows VM, open PowerShell as Administrator
cd C:\Temp
.\Collect-AppxData.ps1 -Verbose
```

**Expected Output:**
```
==================================================
  WimWitch-tNG: AppX Data Collection
  Version: 1.0
==================================================

[OK] Windows Version Detected
    Product: Windows 11 Pro
    Version: 25H2 (Build 26200.2345)
    Edition: Professional
    Architecture: AMD64

Querying provisioned packages (this may take 30-60 seconds)...
[OK] Package Extraction Complete
    Total packages found: 342

[OK] Metadata Created
[OK] Created output directory: .\appxData\

==================================================
  Data Collection Complete!
==================================================

Output File: .\appxData\appxData-Win11-25H2-Build26200-raw.psd1
Total Packages: 342
File Size: 156.23 KB

NEXT STEPS:
1. Copy this file to your development machine:
   ~/Documents/GitHub/WimWitch-tNG/tools/appxData/
```

**1.4. Copy Raw Data Back**

```powershell
# From your development machine
Copy-Item "\\VM-NAME\C$\Temp\appxData\appxData-Win11-25H2-Build26200-raw.psd1" `
          -Destination "~/Documents/GitHub/WimWitch-tNG/tools/appxData/"
```

---

### Step 2: AI Processing (In VSCode)

**2.1. Open Workspace**

```bash
cd ~/Documents/GitHub/WimWitch-tNG
code .
```

**2.2. Invoke AI Agent**

Open GitHub Copilot Chat and enter:

```
@workspace Use #file:.github/prompts/process-appxData.prompt.md to process tools/appxData/appxData-Win11-25H2-Build26200-raw.psd1
```

**2.3. AI Will:**

1. Load raw data file (342 packages)
2. Load exclusion rules from `appx-filter.json`
3. Apply filtering (exclude system-critical packages)
4. Categorize packages (Entertainment, Information, Utilities, Store_Services, Codecs_Extensions)
5. Generate `WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1`
6. Show diff vs. previous version
7. Display validation summary

**2.4. Review AI Output**

Check the generated file:
- **Location:** `WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1`
- **Format:** Matches existing appxWin*.psd1 files
- **Safety:** No system-critical packages included
- **Categories:** All packages properly categorized
- **Diff:** Review changes from previous version

---

### Step 3: Validation & Testing

**3.1. Run Pester Tests**

```powershell
./build.ps1 -Task Pester
```

**3.2. Manual Testing (Recommended)**

1. Mount Windows 11 25H2 reference image
2. Apply AppX removals using new list
3. Verify:
   - Windows boots successfully
   - Settings app works
   - Microsoft Store works
   - Search works
   - No critical errors in Event Viewer

**3.3. Commit and Create PR**

```bash
git add WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1
git commit -m "Add AppX removal list for Windows 11 25H2

- Generated from Build 26200.2345
- 156 safe-to-remove packages
- Tested on reference installation"

git push -u origin feature/win11-25h2-support
# Create PR for review
```

---

## File Structure

```
WimWitch-tNG/
├── tools/
│   ├── Collect-AppxData.ps1          ← Data collection script
│   ├── appx-filter.json              ← Exclusion rules
│   ├── appxData/                     ← Raw data files (gitignored)
│   │   ├── appxData-Win10-22H2-Build19045-raw.psd1
│   │   ├── appxData-Win11-24H2-Build26100-raw.psd1
│   │   └── appxData-Win11-25H2-Build26200-raw.psd1
│   └── Compare-AppxLists.ps1         ← Existing comparison tool
├── .github/prompts/
│   └── process-appxData.prompt.md    ← AI agent instructions
└── WIMWitch-tNG/Private/Assets/
    ├── appxWin10_22H2.psd1           ← Final release files
    ├── appxWin11_23H2.psd1
    ├── appxWin11_24H2.psd1
    └── appxWin11_25H2.psd1           ← Generated by AI
```

---

## Troubleshooting

### Problem: Package Count Too Low

**Symptom:** Script reports <100 packages

**Causes:**
- Windows installation incomplete
- Feature updates not applied
- Optional features disabled

**Solution:**
- Complete Windows installation fully
- Run Windows Update to latest cumulative update
- Ensure all default apps installed

### Problem: AI Generates Incorrect Categories

**Symptom:** Packages miscategorized

**Solution:**
- Review `appx-filter.json` category patterns
- Update patterns to match package names
- Reprocess raw data file

### Problem: Safety Validation Fails

**Symptom:** System-critical package in output

**Solution:**
- Add pattern to `appx-filter.json` neverIncludeInRemovalList
- Reprocess raw data file
- DO NOT commit file until validation passes

### Problem: Build Script Missing

**Symptom:** `./build.ps1 -Task Pester` fails

**Solution:**
- Build script creation is part of maintainability Phase 1
- For now, manually test on reference Windows installation

---

## Maintenance

### Adding New Exclusion Patterns

When a new system-critical package is discovered:

1. Edit `tools/appx-filter.json`
2. Add regex pattern to `neverIncludeInRemovalList`
3. Document why it's system-critical
4. Reprocess existing raw data files to verify
5. Commit updated filter file

**Example:**

```json
{
  "neverIncludeInRemovalList": [
    "Microsoft\\.NewSystemPackage\\.",  // Added: Breaks Windows boot
    ...
  ]
}
```

### Version-Specific Overrides

For Windows version-specific exclusions:

```json
{
  "versionOverrides": {
    "Win11-25H2": {
      "neverIncludeInRemovalList": [
        "Microsoft\\.Windows\\.Ai\\.Copilot\\.Provider"
      ]
    }
  }
}
```

---

## Tips for Contributors

1. **Always use clean Windows installation** for data collection
2. **Keep raw data files** even after processing (useful for reprocessing)
3. **Review diff carefully** before committing new version
4. **Test on reference system** before creating PR
5. **Document unusual changes** in commit message
6. **Ask for review** if unsure about package categorization

---

## Time Estimates

| Task | Duration |
|------|----------|
| Deploy Windows VM | 30-60 minutes (one-time per version) |
| Run data collection | 5-10 minutes |
| Copy files | 1-2 minutes |
| AI processing | 2-5 minutes |
| Review output | 5-10 minutes |
| Manual testing | 30-60 minutes (optional but recommended) |
| **Total** | **45-90 minutes** (vs. 2-3 hours manual) |

**Subsequent versions:** Once VM is deployed, only 20-30 minutes per new build.

---

## Questions?

- See main project documentation: `PROJECT_CONTEXT.md`
- Review existing AppX files for format reference
- Compare with `tools/Compare-AppxLists.ps1` output
- Ask in project discussions or issues

---

**Last Updated:** 2026-01-19
**Version:** 1.0
