# Plan: Simplify Windows 10 Support to 22H2 Only & Remove Version Selection Dialog

**TL;DR:** Only support Windows 10 22H2 (all 10.0.1904*.* builds). Mark older builds as unsupported with error logging. Remove the version selection dialog completely. Clean up code that enables unsupported Windows 10 versions.

## Background

Currently, WIMWitch-tNG attempts to support multiple Windows 10 versions (2004/20H2, 21H1, 21H2, 22H2) which share similar base build numbers (10.0.19041.*, 10.0.19042.*, 10.0.19043.*, 10.0.19044.*, 10.0.19045.*). This requires:
- A popup dialog (`Invoke-19041Select`) to ask users which version they have
- Registry inspection when WIM is mounted to detect the specific build
- Complex version mapping logic throughout the codebase

**Microsoft's ISO Build Number Inconsistency:**
Microsoft has released Windows 10 ISOs with inconsistent build numbers across 2004, 20H2, 21H1, 21H2, and 22H2 releases. Some ISOs labeled as "22H2" may show build 19041, 19042, 19043, or 19044 instead of the expected 19045. This inconsistency makes reliable version detection impossible without user intervention.

**New Strategy:**
- Only Windows 10 22H2 is supported (builds 10.0.1904*.*)
- All older Windows 10 versions are unsupported and logged as errors
- Users with older builds should use older versions of WIMWitch
- No dialog needed - auto-detect from build number

## Phase 1: Core Version Detection Functions

### 1.1 Update `Get-WinVersionNumber` Function
**File:** WIMWitch-tNG/Private/Functions/Utilities/Get-WinVersionNumber.ps1

**Current Behavior:**
- Detects `10.0.19045.*` as 22H2
- For `10.0.19041.*`, prompts user with dialog OR inspects registry if mounted
- Returns user selection or registry value

**New Behavior:**
- Detect ALL `10.0.1904*.*` patterns as Windows 10 22H2
  - Matches: 19040, 19041, 19042, 19043, 19044, 19045
- Log success: "Auto-detected Windows 10 22H2 from build [buildnum]"
- Detect unsupported builds and log errors:
  - `10.0.10*.*` → "Unsupported Windows 10 build"
  - `10.0.14393.*` → "Unsupported Windows 10 build 1607"
  - `10.0.15*.*` → "Unsupported Windows 10 build"
  - `10.0.16299.*` → "Unsupported Windows 10 build 1709"
  - `10.0.17134.*` → "Unsupported Windows 10 build 1803"
  - `10.0.17763.*` → "Unsupported Windows 10 build 1809"
  - `10.0.18362.*` → "Unsupported Windows 10 build 1909"
- Return 'Unsupported' for old builds (triggers abort in calling code)
- Remove entire `10.0.19041.*` detection block (lines 5778-5820)
- Remove calls to `Invoke-19041Select`
- Remove registry inspection logic for old builds (19042, 19043, 19044)
- Remove Windows Server 2022 detection (10.0.20348.* = 21H2) - no longer needed
- Keep Windows 11 detection (23H2, 24H2, 25H2)

**Code Changes:**
```powershell
Function Get-WinVersionNumber {
    $buildnum = $null
    $wimBuild = $WPFSourceWimVerTextBox.text

    # Windows 10 and 11 version detection
    switch -Regex ($wimBuild) {
        # Windows 10 - Only 22H2 supported (all 1904*.* builds)
        '10\.0\.1904\d\.\d+' {
            $buildnum = '22H2'
            Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimBuild. Note: Only Windows 10 22H2 is supported. ISO build numbers from Microsoft are inconsistent across 2004/20H2/21H1/21H2/22H2 releases, so all 10.0.1904*.* builds will be treated as 22H2." -Class Information
        }

        # Windows 11 version checks
        '10\.0\.22631\.\d+' { $buildnum = '23H2' }
        '10\.0\.26100\.\d+' { $buildnum = '24H2' }
        '10\.0\.26200\.\d+' { $buildnum = '25H2' }

        # Unsupported Windows 10 builds
        '10\.0\.10\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported. Please use an older version of WIMWitch for legacy Windows 10 builds." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.14393\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimBuild. Only Windows 10 22H2 is supported." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.1[5-8]\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported." -Class Error
            $buildnum = 'Unsupported'
        }

        Default {
            Update-Log -Data "Unknown Windows version: $wimBuild" -Class Warning
            $buildnum = 'Unknown Version'
        }
    }

    return $buildnum
}
```

### 1.2 Update `Set-Version` Function
**File:** WIMWitch-tNG/Private/Functions/Utilities/Set-Version.ps1

**Current Behavior:**
- Maps specific build numbers to version strings
- Used during WIM import
- Returns version strings like '2004', '1909', '1809', etc.

**New Behavior:**
- Change `10.0.19041.*` → `10.0.1904*.*` (wildcard to catch all)
- Remove old version mappings (1607, 1709, 1803, 1809, 1909)
- Log errors for unsupported builds
- Return 'Unsupported' for old builds
 - Keep Windows 11 detection (23H2, 24H2, 25H2)

**Code Changes:**
```powershell
Function Set-Version($wimversion) {
    # Windows 11 versions
    if ($wimversion -like '10.0.22631.*') { $version = '23H2' }
    elseif ($wimversion -like '10.0.26100.*') { $version = '24H2' }
    elseif ($wimversion -like '10.0.26200.*') { $version = '25H2' }

    # Windows 10 - Only 22H2 supported (all 1904*.* builds)
    elseif ($wimversion -like '10.0.1904*.*') {
        $version = '22H2'
        Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimversion. Note: Only Windows 10 22H2 is supported. ISO build numbers are inconsistent, assuming 22H2." -Class Information
    }

    # Unsupported Windows 10 builds
    elseif ($wimversion -like '10.0.16299.*') {
        Update-Log -Data "Unsupported Windows 10 build 1709 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17134.*') {
        Update-Log -Data "Unsupported Windows 10 build 1803 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17763.*') {
        Update-Log -Data "Unsupported Windows 10 build 1809 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.18362.*') {
        Update-Log -Data "Unsupported Windows 10 build 1909 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.14393.*') {
        Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    else {
        Update-Log -Data "Unknown Windows version: $wimversion" -Class Warning
        $version = 'Unknown'
    }
    return $version
}
```

### 1.3 Remove `Invoke-19041Select` Function (if it exists)
**Note:** This function may have already been removed during modularization.
**Verify:** Check for any remaining calls to `Invoke-19041Select` in the codebase.

**Action:** Delete entire function and replace with comment:
```powershell
# Invoke-19041Select function removed - Windows 10 22H2 is auto-detected from build 1904*.*
# Legacy Windows 10 versions are no longer supported
```

---

## Phase 2: Remove Dialog Calls

### 2.1 Remove Dialog Call in `Import-ISO` Function
**File:** WIMWitch-tNG/Private/Functions/ISO/Import-ISO.ps1

**Current Code:**
```powershell
if ($version -eq 2004) {
    $global:Win10VerDet = $null
    Invoke-19041Select
    if ($null -eq $global:Win10VerDet) {
        Write-Host 'cancelling'
        return
    } else {
        $version = $global:Win10VerDet
        $global:Win10VerDet = $null
    }
    if ($version -eq '20H2') { $version = '2009' }
}
```

**New Code:**
```powershell
# Version 2004 and 20H2 auto-detected as 22H2 via Set-Version function
# No user prompt needed
if ($version -eq 'Unsupported') {
    Update-Log -Data "Cannot import unsupported Windows 10 build. Only Windows 10 22H2 is supported." -Class Error
    Write-Host 'Import cancelled - unsupported Windows version'
    return
}
```

### 2.2 Remove `$global:Win10VerDet` Variable Initialization
**File:** WIMWitch-tNG/Public/WIMWitch-tNG.ps1
**Line:** 436

**Current Code:**
```powershell
$global:Win10VerDet = ''
```

**Action:** Delete this line (variable no longer used)

---

## Phase 3: Clean Up Old Version String References

### 3.1 Version String Replacements in WWFunctions.ps1

**Line 863:** Build number remapping
```powershell
# OLD:
if ($buildnum -eq '2009') { $buildnum = '20H2' }

# NEW: Remove this line (2009/20H2 are obsolete, now auto-detected as 22H2)
```

**Line 917:** Version validation check
```powershell
# OLD:
if (($os -eq 'Windows 10') -and (($buildnum -eq '2004') -or ($buildnum -eq '2009') -or ($buildnum -eq '20H2') -or ($buildnum -eq '21H1') -or ($buildnum -eq '21H2') -or ($buildnum -eq '22H2'))) {

# NEW:
if (($os -eq 'Windows 10') -and ($buildnum -eq '22H2')) {
```

**Line 2078:** Version remapping
```powershell
# OLD:
if ($version -eq '20H2') { $version = '2009' }

# NEW: Remove this line (handled by Set-Version)
```

**Line 2286:** Build number normalization
```powershell
# OLD:
if ($buildnum -eq '20H2') { $Buildnum = '2009' }

# NEW: Remove this line
```

**Line 2510:** Version normalization for LP/FOD
```powershell
# OLD:
if (($Winver -eq '2009') -or ($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '21H2') -or ($winver -eq '22H2')) { $winver = '2004' }

# NEW:
if ($Winver -eq '22H2') { $winver = '2004' }
```

**Lines 4257, 4298, 4329:** FOD version mapping
```powershell
# OLD:
if (($WinOS -eq 'Windows 10') -and (($winver -eq '20H2') -or ($winver -eq '21H1') -or ($winver -eq '2009') -or ($winver -eq '21H2') -or ($winver -eq '22H2'))) { $winver = '2004' }

# NEW:
if (($WinOS -eq 'Windows 10') -and ($winver -eq '22H2')) { $winver = '2004' }
```

**Lines 4849, 4851:** Update name filtering
```powershell
# OLD:
if (($UpdateName -like '* 1903 *') -or ($UpdateName -like '* 1909 *') -or ($UpdateName -like '* 2004 *') -or ($UpdateName -like '* 20H2 *') -or ($UpdateName -like '* 21H1 *') -or ($UpdateName -like '* 21H2 *') -or ($UpdateName -like '* 22H2 *'))

# NEW:
if ($UpdateName -like '* 22H2 *')
```

**Line 5006:** Version check
```powershell
# OLD:
if (($prod -eq 'Windows 10') -and (($ver -ge '1903') -or ($ver -eq '20H2') -or ($ver -eq '21H1') -or ($ver -eq '21H2')))

# NEW:
if (($prod -eq 'Windows 10') -and ($ver -eq '22H2'))
```

### 3.2 Remove Old Build Date Logic (Line 876)
```powershell
# OLD:
if ($windowsver.CreatedTime -gt $vardate) { $buildnum = 1909 }

# NEW: Remove entire line (1909 detection obsolete)
```

### 3.3 Remove Old FOD Arrays (Lines 4234-4238, 4356, 4383, 4421)

**Arrays to Remove:**
- `$Win10_1909_FODs` - Remove entire array definition
- `$Win10_1903_FODs` - Remove entire array definition
- `$Win10_1809_FODs` - Remove entire array definition

**Arrays to Keep:**
- `$Win10_1809_server_FODs` - Keep (Windows Server 2019)
- `$Win10_2004_FODs` - Keep (used by 22H2)

**Version Mapping Logic to Remove:**
```powershell
# Lines 4356, 4383, 4421:
# OLD:
if ($Winver -eq '1903') { $winver = '1909' }

# NEW: Remove (only 22H2 supported)
```

**FOD Selection Logic to Remove:**
```powershell
# Lines 4236-4238:
# OLD:
If ($Winver -eq '1809') {
    if ($WinOS -eq 'Windows 10') { $items = ($Win10_1809_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
    if ($WinOS -eq 'Windows Server') { $items = ($Win10_1809_server_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
}

# NEW: Keep Server logic only, remove Windows 10 1809
If ($Winver -eq '1809') {
    if ($WinOS -eq 'Windows Server') { $items = ($Win10_1809_server_FODs | Out-GridView -Title 'Select Features On Demand' -PassThru) }
}
```

### 3.4 Remove Special SSU Handling for 19041 (Lines 6003, 6014, 6019, 6030, 6055)

**SSU Prerequisite Check:**
```powershell
# OLD:
if ((Test-Path "$global:workdir\updates\Windows 10\2XXX_prereq\SSU-19041.985-x64.cab") -eq $false) {
    # ... download logic ...
}

# NEW: Remove entire block (special 19041 SSU handling obsolete for 22H2)
```

---

## Phase 4: Clean Up UI Checkbox References

### 4.1 Update Windows 10 Checkbox Handler
**File:** WIMWitch-tNG/Public/WIMWitch-tNG.ps1
**Lines:** 823-832

**Current Code:**
```powershell
$WPFUpdatesW10Main.Add_Click( {
    If ($WPFUpdatesW10Main.IsChecked -eq $true) {
        $WPFUpdatesW10_1903.IsEnabled = $True
        $WPFUpdatesW10_1809.IsEnabled = $True
        $WPFUpdatesW10_1803.IsEnabled = $True
        $WPFUpdatesW10_22H2.IsEnabled = $True
    } else {
        $WPFUpdatesW10_22H2.IsEnabled = $False
    }
})
```

**New Code:**
```powershell
$WPFUpdatesW10Main.Add_Click( {
    If ($WPFUpdatesW10Main.IsChecked -eq $true) {
        $WPFUpdatesW10_22H2.IsEnabled = $True
    } else {
        $WPFUpdatesW10_22H2.IsEnabled = $False
    }
})
```

**Note:** References to `$WPFUpdatesW10_1903`, `$WPFUpdatesW10_1809`, `$WPFUpdatesW10_1803` removed. These controls don't exist in current XAML but are referenced in code.

---

## Phase 5: Add Abort Logic for Unsupported Builds

### 5.1 Add Validation in Main Processing Functions

When `Get-WinVersionNumber` or `Set-Version` returns 'Unsupported', abort the operation and show clear message.

**Example in Invoke-MakeItSo or other main functions:**
```powershell
$winVersion = Get-WinVersionNumber
if ($winVersion -eq 'Unsupported' -or $winVersion -eq 'Unknown Version') {
    Update-Log -Data "Cannot proceed with unsupported or unknown Windows version." -Class Error
    [System.Windows.MessageBox]::Show(
        "This Windows build is not supported.`n`nOnly Windows 10 22H2 (build 19045) and Windows 11 (23H2, 24H2, 25H2) are supported.`n`nPlease use an older version of WIMWitch for legacy Windows 10 builds.",
        "Unsupported Windows Version",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    return
}
```

### 5.2 Update Import-ISO Validation

Already covered in Phase 2.1 - add abort logic when version is 'Unsupported'.

---

## Phase 6: Testing & Validation

### 6.1 Test Scenarios

1. **Windows 10 22H2 (Build 19045):**
   - ✓ Auto-detected as 22H2
   - ✓ No dialog shown
   - ✓ Logs "Auto-detected Windows 10 22H2 from build 10.0.19045.xxxx"
   - ✓ Operation proceeds normally

2. **Windows 10 22H2 (Build 19044, 19043, 19042, 19041):**
   - ✓ Auto-detected as 22H2
   - ✓ No dialog shown
   - ✓ Logs "Auto-detected Windows 10 22H2 from build 10.0.1904x.xxxx"
   - ✓ Operation proceeds normally

3. **Windows 10 1909 (Build 18362):**
   - ✓ Detected as unsupported
   - ✓ Logs error: "Unsupported Windows 10 build 1909 detected"
   - ✓ Operation aborted with clear message to use older WIMWitch version

4. **Windows 10 1809, 1803, 1709, 1607:**
   - ✓ Detected as unsupported
   - ✓ Logs error with specific build number
   - ✓ Operation aborted

5. **Windows 11 23H2, 24H2, 25H2:**
   - ✓ Auto-detected correctly
   - ✓ No changes to Windows 11 behavior
   - ✓ Operations proceed normally

### 6.2 Verification Checklist

- [ ] Module imports successfully: `Import-Module './WIMWitch-tNG/WIMWitch-tNG.psm1' -Force`
- [ ] No syntax errors in modified functions
- [ ] All old version string references removed or updated
- [ ] `Invoke-19041Select` function and all calls removed
- [ ] `$global:Win10VerDet` variable removed
- [ ] Old FOD arrays removed (1909, 1903, 1809 for Win10)
- [ ] Update checkbox handler cleaned up
- [ ] Unsupported build detection logs errors correctly
- [ ] Windows 11 detection unchanged and working
- [ ] Logging clearly states ISO build numbers are inconsistent and 22H2 is assumed for all 1904*.* builds

---

## Summary of Changes

### Files Modified:
1. **WIMWitch-tNG/Private/Functions/Utilities/** (Get-WinVersionNumber.ps1, Set-Version.ps1)
2. **WIMWitch-tNG/Private/Functions/ISO/Import-ISO.ps1**
3. **WIMWitch-tNG/Private/Assets/** (appxWin10_22H2.psd1)
4. **WIMWitch-tNG/Public/WIMWitch-tNG.ps1** (XAML cleanup)
2. **WIMWitch-tNG/Public/WIMWitch-tNG.ps1** (Minor cleanup, ~3 changes)

### Functions Modified:
- `Get-WinVersionNumber` - Simplified to auto-detect 22H2, remove dialog
- `Set-Version` - Remove old version mappings, add error logging
- `Invoke-19041Select` - DELETED
- `Import-ISO` - Remove dialog call, add abort logic
- Update checkbox handler - Remove old checkbox references
- Various functions with version string checks - Updated to 22H2 only

### Functions Removed:
- `Invoke-19041Select` - Entire function deleted

### Variables Removed:
- `$global:Win10VerDet` - No longer needed

### Arrays Removed:
- `$Win10_1909_FODs`
- `$Win10_1903_FODs`
- `$Win10_1809_FODs` (Windows 10 version only, keep Server 2019)

### Key Behavioral Changes:
- **Before:** User prompted with dialog for builds 10.0.19041.*
- **After:** All builds 10.0.1904*.* auto-detected as Windows 10 22H2
- **Before:** Supports Windows 10 2004, 20H2, 21H1, 21H2, 22H2
- **After:** Only supports Windows 10 22H2
- **Before:** Old builds proceed with limited functionality
- **After:** Old builds logged as errors and operation aborted

### User-Facing Impact:
- Users with Windows 10 22H2: No changes, better experience (no dialog)
- Users with Windows 10 ISOs with inconsistent build numbers (1904*.*): Auto-detected as 22H2 with clear logging explanation
- Users with older Windows 10: Clear error message directing them to use older WIMWitch version
- Users with Windows 11: No changes

---

## Implementation Order

1. Update `Get-WinVersionNumber` function
2. Update `Set-Version` function
3. Remove `Invoke-19041Select` function
4. Remove dialog calls in `Import-ISO` and elsewhere
5. Remove `$global:Win10VerDet` variable initialization
6. Clean up version string references throughout codebase
7. Remove old FOD arrays
8. Update checkbox handler
9. Add abort logic for unsupported builds
10. Test all scenarios
11. Verify module imports successfully
