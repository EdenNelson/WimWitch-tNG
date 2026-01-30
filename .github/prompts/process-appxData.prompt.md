# Task: Process AppX Raw Data into Release PSD1

**Purpose:** Transform raw AppX package data collected from a Windows installation into a curated, categorized safe-to-remove list for WimWitch-tNG users.

**Context:** This is Step 2 of the two-step AppX automation workflow. Step 1 (data collection) has already run on a Windows VM and produced a raw data file with ALL packages. Your job is to apply filtering logic and create the final release-ready PSD1 file.

**Code Origin:** Portions of this prompt were generated with GitHub Copilot AI assistance. The author (Eden Nelson [edennelson]) has reviewed all content. This is disclosed in the interest of transparency.

---

## Input Files

1. **Raw Data File (Primary Input):**
   - Location: `tools/appxData/appxData-Win11-25H2-Build26200-raw.psd1` (or similar)
   - Format: PowerShell CliXml with Metadata and Packages
   - Content: ALL AppX packages from Windows (300-450 packages, unfiltered)

2. **Exclusion Rules (Filtering Configuration):**
   - Location: `tools/appx-filter.json`
   - Content: System-critical packages that MUST NOT be in removal list
   - Usage: Apply regex patterns to exclude packages

3. **Reference Files (For Comparison):**
   - Location: `WIMWitch-tNG/Private/Assets/appxWin11_*.psd1`
   - Purpose: See format, categorization, and compare changes

---

## Processing Instructions

### Step 1: Load Raw Data

```powershell
# Load the raw data file
$rawData = Import-Clixml -Path "tools/appxData/appxData-Win11-25H2-Build26200-raw.psd1"
$metadata = $rawData.Metadata
$allPackages = $rawData.Packages

Write-Output "Loaded: $($allPackages.Count) packages from $($metadata.WindowsVersion)"
```

### Step 2: Load Exclusion Rules

```powershell
# Load filtering configuration
$filterConfig = Get-Content -Path "tools/appx-filter.json" | ConvertFrom-Json
$excludePatterns = $filterConfig.neverIncludeInRemovalList

# Check for version-specific overrides
$versionKey = "Win11-$($metadata.WindowsVersion)"
if ($filterConfig.versionOverrides.$versionKey) {
    $excludePatterns += $filterConfig.versionOverrides.$versionKey.neverIncludeInRemovalList
}

Write-Output "Loaded: $($excludePatterns.Count) exclusion patterns"
```

### Step 3: Apply Filtering (Inverse Logic)

**Critical:** We want a COMPREHENSIVE list. Include ALL packages EXCEPT those matching exclusion patterns.

```powershell
$safeToRemove = @()
$excluded = @()

foreach ($package in $allPackages) {
    $packageName = $package.PackageName
    $shouldExclude = $false

    # Check against all exclusion patterns
    foreach ($pattern in $excludePatterns) {
        if ($packageName -match $pattern) {
            $shouldExclude = $true
            $excluded += [PSCustomObject]@{
                Package = $packageName
                Reason = "Matched exclusion pattern: $pattern"
            }
            break
        }
    }

    # If NOT excluded, add to safe-to-remove list
    if (-not $shouldExclude) {
        $safeToRemove += $package
    }
}

Write-Output "Safe to remove: $($safeToRemove.Count) packages"
Write-Output "Excluded (system-critical): $($excluded.Count) packages"
```

### Step 4: Categorize Packages

Use the category patterns from `appx-filter.json` as hints, plus intelligent pattern matching:

**Categories:**
- **Entertainment:** Games, media apps (Xbox, Clipchamp, Solitaire, Spotify, etc.)
- **Information:** News, weather, search, finance (Bing apps)
- **Utilities:** Productivity tools (Paint, Notepad, Photos, Calculator, Maps, Alarms, etc.)
- **Store_Services:** Microsoft Store, Office Hub, OneDrive, YourPhone, Dev Home
- **Codecs_Extensions:** Video/image codecs and extensions

**Categorization Logic:**

```powershell
function Get-PackageCategory {
    param(
        [string]$PackageName
    )

    # Check against category patterns from filter config
    foreach ($category in $filterConfig.categoryPatterns.PSObject.Properties) {
        foreach ($pattern in $category.Value.patterns) {
            if ($PackageName -match $pattern) {
                return $category.Name
            }
        }
    }

    # Fallback categorization by package name patterns
    if ($PackageName -match 'Xbox|Gaming|Game|Solitaire|Clipchamp|Zune|Spotify') {
        return 'Entertainment'
    } elseif ($PackageName -match 'Bing|News|Weather|Finance|Sports') {
        return 'Information'
    } elseif ($PackageName -match 'Paint|Notepad|Photo|Calculator|Map|Alarm|Sound|Camera|People|Feedback|QuickAssist|GetHelp') {
        return 'Utilities'
    } elseif ($PackageName -match 'Store|Office|OneDrive|YourPhone|DevHome|DesktopApp') {
        return 'Store_Services'
    } elseif ($PackageName -match 'VideoExtension|ImageExtension|Codec|HEVC|AV1|VP9|WebP|HEIF|MPEG2') {
        return 'Codecs_Extensions'
    } else {
        return 'Utilities'  # Default fallback
    }
}

# Apply categorization
$categorized = @{
    Entertainment = @()
    Information = @()
    Utilities = @()
    Store_Services = @()
    Codecs_Extensions = @()
}

foreach ($package in $safeToRemove) {
    $category = Get-PackageCategory -PackageName $package.PackageName
    $categorized[$category] += $package.PackageName
}

# Sort each category alphabetically
foreach ($category in $categorized.Keys) {
    $categorized[$category] = $categorized[$category] | Sort-Object
}
```

### Step 5: Generate Output PSD1

**Format:** Match existing `appxWin*.psd1` files exactly.

**Output File:** `WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1`

**Header Comment:**
```powershell
@"
<#
    AppX Package Removal List for Windows 11 25H2 (Build $($metadata.BuildNumber))

    Generated: $($metadata.CollectionDate)
    Source: $($metadata.ProductName) ($($metadata.EditionID))
    Architecture: $($metadata.Architecture)
    Total Packages: $($safeToRemove.Count)

    This list contains AppX packages that users can safely choose to remove.
    These packages are presented in the WimWitch UI, and users select which to remove.

    Categories:
    - Entertainment: $($categorized.Entertainment.Count) packages
    - Information: $($categorized.Information.Count) packages
    - Utilities: $($categorized.Utilities.Count) packages
    - Store/Services: $($categorized.Store_Services.Count) packages
    - Codecs/Extensions: $($categorized.Codecs_Extensions.Count) packages

    TESTING CHECKLIST:
    - [ ] No system-critical packages in this list
    - [ ] All categories populated
    - [ ] Compared to previous version (appxWin11_24H2.psd1)
    - [ ] Tested removal on reference Windows installation
    - [ ] Windows still boots and functions after removal
    - [ ] Settings, Store, Search all work

    Maintainer: Review this file carefully before committing.
#>
"@
```

**PSD1 Body:**
```powershell
@{
    Entertainment = @(
        # [Each package on separate line, sorted alphabetically]
    )
    Information = @(
        # [Each package on separate line, sorted alphabetically]
    )
    Utilities = @(
        # [Each package on separate line, sorted alphabetically]
    )
    Store_Services = @(
        # [Each package on separate line, sorted alphabetically]
    )
    Codecs_Extensions = @(
        # [Each package on separate line, sorted alphabetically]
    )
}
```

### Step 6: Safety Validation

Before saving, perform safety checks:

```powershell
# 1. Verify NO system-critical packages in output
$violations = @()
foreach ($category in $categorized.Keys) {
    foreach ($package in $categorized[$category]) {
        foreach ($pattern in $excludePatterns) {
            if ($package -match $pattern) {
                $violations += "VIOLATION: $package matches exclusion pattern: $pattern"
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Error -Message "SAFETY VIOLATION DETECTED!"
    $violations | ForEach-Object -Process { Write-Error -Message $_ }
    throw "Cannot proceed - system-critical packages found in output"
}

# 2. Verify total count is reasonable
if ($safeToRemove.Count -lt 100 -or $safeToRemove.Count -gt 400) {
    Write-Warning -Message "Package count unusual: $($safeToRemove.Count). Expected 150-350."
}

# 3. Check all categories are populated
$emptyCategories = $categorized.Keys | Where-Object -FilterScript { $categorized[$_].Count -eq 0 }
if ($emptyCategories) {
    Write-Warning -Message "Empty categories detected: $($emptyCategories -join ', ')"
}

Write-Output "[OK] Safety validation passed"
```

### Step 7: Generate Diff Report

Compare to previous version to show what changed:

```powershell
# Determine previous version file
$currentVersion = $metadata.WindowsVersion  # e.g., "25H2"
$previousVersion = "24H2"  # Adjust based on version
$previousFile = "WIMWitch-tNG/Private/Assets/appxWin11_$previousVersion.psd1"

if (Test-Path -Path $previousFile) {
    $previousData = Import-PowerShellDataFile -Path $previousFile
    $previousPackages = @()
    foreach ($category in $previousData.Keys) {
        $previousPackages += $previousData[$category]
    }

    $currentPackages = @()
    foreach ($category in $categorized.Keys) {
        $currentPackages += $categorized[$category]
    }

    $addedPackages = $currentPackages | Where-Object -FilterScript { $_ -notin $previousPackages }
    $removedPackages = $previousPackages | Where-Object -FilterScript { $_ -notin $currentPackages }

    Write-Output ""
    Write-Output "===== Changes from Windows 11 $previousVersion ====="
    Write-Output ""
    Write-Output "New packages in $currentVersion ($($addedPackages.Count)):"
    $addedPackages | ForEach-Object -Process { Write-Output "  + $_" }
    Write-Output ""
    Write-Output "Removed packages from $previousVersion ($($removedPackages.Count)):"
    $removedPackages | ForEach-Object -Process { Write-Output "  - $_" }
    Write-Output ""
}
```

---

## Output Requirements

**Create the following files:**

1. **Primary Output:**
   - File: `WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1`
   - Format: PowerShell data file with header comment + hashtable
   - Categories: Entertainment, Information, Utilities, Store_Services, Codecs_Extensions
   - Sorted: Alphabetically within each category

2. **Diff Report (Display to User):**
   - Show packages added vs. previous version
   - Show packages removed vs. previous version
   - Highlight any surprising changes

3. **Validation Summary (Display to User):**
   - Total packages in raw data
   - Total packages excluded (system-critical)
   - Total packages in safe-to-remove list
   - Safety validation result (PASS/FAIL)
   - Category breakdown

---

## Expected Output Format Example

**File: WIMWitch-tNG/Private/Assets/appxWin11_25H2.psd1**

```powershell
<#
    AppX Package Removal List for Windows 11 25H2 (Build 26200.2345)

    Generated: 2026-01-19 14:32:15
    Source: Windows 11 Pro (Professional)
    Architecture: AMD64
    Total Packages: 156

    [Additional header content...]
#>

@{
    Entertainment = @(
        'Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt'
        'Microsoft.GamingApp_2021.427.138.0_x64__8wekyb3d8bbwe'
        'Microsoft.MicrosoftSolitaireCollection_4.12.3172.0_x64__8wekyb3d8bbwe'
        'Microsoft.Xbox.TCUI_1.24.10001.0_x64__8wekyb3d8bbwe'
        'Microsoft.XboxGameOverlay_1.54.4001.0_x64__8wekyb3d8bbwe'
        'Microsoft.XboxGamingOverlay_5.721.12263.0_x64__8wekyb3d8bbwe'
        'Microsoft.XboxIdentityProvider_12.83.12263.0_x64__8wekyb3d8bbwe'
        'Microsoft.XboxSpeechToTextOverlay_1.21.13002.0_x64__8wekyb3d8bbwe'
        'Microsoft.ZuneMusic_11.2202.46.0_x64__8wekyb3d8bbwe'
    )

    Information = @(
        'Microsoft.BingNews_4.2.27001.0_x64__8wekyb3d8bbwe'
        'Microsoft.BingWeather_4.53.33420.0_x64__8wekyb3d8bbwe'
    )

    # [Additional categories...]
}
```

---

## Human Review Checklist

After generating the file, present this checklist to the maintainer:

- [ ] **Safety:** No system-critical packages in output (cross-check against exclusion list)
- [ ] **Format:** File matches existing appxWin*.psd1 format
- [ ] **Categories:** All packages properly categorized
- [ ] **Sorting:** Alphabetical within each category
- [ ] **Diff:** Reviewed changes from previous version (new/removed packages make sense)
- [ ] **Count:** Package count reasonable (150-350 typical)
- [ ] **Header:** Complete metadata (version, build, date, counts)
- [ ] **Testing:** Plan to test on reference Windows installation before committing

---

## Common Pitfalls to Avoid

1. **DO NOT** include packages matching `neverIncludeInRemovalList` patterns
2. **DO NOT** filter aggressively—we want a comprehensive list
3. **DO NOT** guess at categorization—use patterns and existing files as reference
4. **DO NOT** forget to sort alphabetically within categories
5. **DO NOT** skip the safety validation step
6. **DO** preserve the exact PSD1 format from existing files
7. **DO** show diff report to help human reviewer
8. **DO** highlight any unusual changes (new system packages, unexpected removals)

---

## Success Criteria

✓ Output file created in correct location
✓ Format matches existing appxWin*.psd1 files exactly
✓ NO system-critical packages in output (safety validation passed)
✓ All packages categorized (no uncategorized packages)
✓ Alphabetically sorted within categories
✓ Diff report shows changes vs. previous version
✓ Header comment complete with metadata
✓ Human reviewer has all information needed to validate output

**When complete, present the output file location and ask maintainer to review before committing.**

---

**End of AI Prompt: process-appxData.prompt.md**
