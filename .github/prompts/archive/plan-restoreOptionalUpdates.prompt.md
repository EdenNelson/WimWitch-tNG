# Plan: Restore "Include Optional" Checkbox Functionality

## Problem Statement

The "Include Optional" checkbox (`$WPFUpdatesCBEnableOptional`) on the Customizations tab has **partial functionality**:

- ✅ **Works for OSDSUS catalog source**: Optional updates are downloaded when checkbox is enabled
- ❌ **Does NOT work for ConfigMgr catalog source**: All updates are downloaded regardless of checkbox state
- ❌ **No severity filtering**: ConfigMgr downloads all update severities (Critical, Important, Moderate, Low, Optional)

## Current Behavior

### OSDSUS Source (Working)
- File: [WWFunctions.ps1](../../../WIMWitch-tNG/Private/WWFunctions.ps1) - `Get-WindowsPatches` function (line ~704)
- Checkbox state is checked: `if ($WPFUpdatesCBEnableOptional.IsChecked -eq $True)`
- Optional updates downloaded to: `$global:workdir\updates\$OS\$build\Optional`
- Applied during "Make it So": `Deploy-Updates -class 'Optional'` (line ~6190)

### ConfigMgr Source (Broken)
- File: [WWFunctions.ps1](../../../WIMWitch-tNG/Private/WWFunctions.ps1) - `Invoke-MEMCMUpdatecatalog` function (line ~4955)
- **No checkbox check**: Downloads all updates without filtering by severity
- Downloads all severities: Critical, Important, Moderate, Low, **and Optional**
- No severity-based folder organization (all updates go to same path)

### Common Application Path
- Both sources apply Optional updates if checkbox is enabled
- `Deploy-Updates -class 'Optional'` runs when `$WPFUpdatesOptionalEnableCheckBox.IsChecked -eq $True`
- This means OSDSUS-downloaded optional updates are applied correctly
- ConfigMgr optional updates are also applied, but they're **mixed with other severities**

## Root Cause

ConfigMgr WMI query filters by:
- Category (Windows version)
- Supersedence status (`IsSuperseded -eq $false`)
- Display name patterns (version, architecture)
- Feature updates exclusion
- Language packs exclusion

**Missing**: Severity/Classification filtering based on `$WPFUpdatesCBEnableOptional.IsChecked`

## Desired Behavior

When using **ConfigMgr catalog source**:

1. **Checkbox UNCHECKED** (default):
   - Download only: Critical, Important, Moderate, Low updates
   - **Skip**: Optional updates, Definition updates

2. **Checkbox CHECKED**:
   - Download: Critical, Important, Moderate, Low, **AND Optional** updates
   - Still skip: Definition updates

3. **Folder Organization** (optional enhancement):
   - Organize by severity similar to OSDSUS structure:
     - `\updates\Windows 11\24H2\Critical\`
     - `\updates\Windows 11\24H2\Important\`
     - `\updates\Windows 11\24H2\Optional\`

## Implementation Plan

### Phase 1: Add Severity Filtering to ConfigMgr Query

**Location**: `Invoke-MEMCMUpdatecatalog` function (around line 5020)

**Current Code**:
```powershell
foreach ($update in $updates) {
    if ((($update.localizeddisplayname -notlike 'Feature update*') -and
         ($update.localizeddisplayname -notlike 'Upgrade to Windows 11*')) -and
         ($update.localizeddisplayname -notlike '*Language Pack*') -and
         ($update.localizeddisplayname -notlike '*editions),*')) {

        Update-Log -Data 'Checking the following update:' -Class Information
        Update-Log -data $update.localizeddisplayname -Class Information
        Invoke-MSUpdateItemDownload -FilePath "$global:workdir\updates\$Prod\$ver\" -UpdateName $update.LocalizedDisplayName
    }
}
```

**Updated Code**:
```powershell
foreach ($update in $updates) {
    # Existing exclusions
    if ((($update.localizeddisplayname -notlike 'Feature update*') -and
         ($update.localizeddisplayname -notlike 'Upgrade to Windows 11*')) -and
         ($update.localizeddisplayname -notlike '*Language Pack*') -and
         ($update.localizeddisplayname -notlike '*editions),*')) {

        # NEW: Filter by severity/classification
        # Get the severity type from WMI object
        $severity = $update.SeverityName

        # Skip optional updates if checkbox is not enabled
        if (($severity -eq 'Optional') -and ($WPFUpdatesCBEnableOptional.IsChecked -ne $True)) {
            Update-Log -Data "Skipping optional update (checkbox disabled): $($update.LocalizedDisplayName)" -Class Information
            continue
        }

        # Skip definition updates (always)
        if ($severity -eq 'Definition Updates') {
            Update-Log -Data "Skipping definition update: $($update.LocalizedDisplayName)" -Class Information
            continue
        }

        Update-Log -Data "Checking update [$severity]: $($update.LocalizedDisplayName)" -Class Information
        Invoke-MSUpdateItemDownload -FilePath "$global:workdir\updates\$Prod\$ver\" -UpdateName $update.LocalizedDisplayName
    }
}
```

**Rationale**:
- Uses `SMS_SoftwareUpdate.SeverityName` property from ConfigMgr WMI
- Filters optional updates based on checkbox state
- Always excludes definition updates (virus definitions, not applicable to image servicing)
- Logs severity type for troubleshooting
- Matches OSDSUS behavior for consistency

### Phase 2: Validate SMS_SoftwareUpdate Properties (Research Phase)

**Action**: Verify the correct property name for severity classification

**ConfigMgr WMI Class**: `SMS_SoftwareUpdate` (root\SMS\Site_<SiteCode>)

**Possible Properties** (need verification):
- `SeverityName` - Human-readable severity (e.g., "Critical", "Important", "Optional")
- `Severity` - Numeric severity code
- `LocalizedCategoryInstanceNames` - Array of categories (may include severity)
- `UpdateClassification` - Classification GUID or name

**Research Method**:
```powershell
# Query a known optional update to inspect properties
$testUpdate = Get-WmiObject -Namespace "root\SMS\Site_XXX" -Class SMS_SoftwareUpdate `
    -ComputerName "SiteServer" `
    -Filter "LocalizedDisplayName like '%Optional%'" `
    | Select-Object -First 1

# Inspect all properties
$testUpdate | Get-Member -MemberType Property
$testUpdate | Format-List *
```

**Expected Properties to Check**:
1. `SeverityName` or `Severity`
2. `UpdateClassificationName` or similar
3. Relationship to `SMS_UpdateClassification` WMI class

### Phase 3: Testing Plan

**Test Scenarios**:

1. **ConfigMgr Source - Optional Checkbox UNCHECKED**
   - Expected: Only Critical/Important/Moderate/Low updates downloaded
   - Expected: Optional updates skipped with log message
   - Verify: No "Optional" updates in download folder

2. **ConfigMgr Source - Optional Checkbox CHECKED**
   - Expected: All update severities downloaded (including Optional)
   - Verify: Optional updates present in download folder

3. **OSDSUS Source - Regression Test**
   - Expected: Existing functionality unchanged
   - Optional checkbox controls Optional download as before

4. **Mixed Scenario**
   - ConfigMgr optional checkbox OFF → Download updates
   - Switch to OSDSUS → Optional checkbox still OFF
   - Verify: OSDSUS optional updates not downloaded

5. **Apply Updates - Optional Checkbox States**
   - ConfigMgr downloaded with optional OFF → Optional folder empty
   - Apply updates → `Deploy-Updates -class 'Optional'` should skip (no files)
   - ConfigMgr downloaded with optional ON → Optional folder populated
   - Apply updates → Optional updates applied successfully

### Phase 4: Optional Enhancement - Severity-Based Folder Structure

**Goal**: Organize ConfigMgr updates by severity like OSDSUS does

**Current Structure**:
```
\updates\Windows 11\24H2\
    ├── <Update files all mixed together>
```

**Proposed Structure**:
```
\updates\Windows 11\24H2\
    ├── Critical\
    ├── Important\
    ├── Moderate\
    ├── Optional\      (only if checkbox enabled)
    └── Low\
```

**Implementation**:
```powershell
# Modify Invoke-MSUpdateItemDownload call
$severityFolder = switch ($severity) {
    'Critical' { 'Critical' }
    'Important' { 'Important' }
    'Moderate' { 'Moderate' }
    'Low' { 'Low' }
    'Optional' { 'Optional' }
    default { 'Other' }
}

Invoke-MSUpdateItemDownload -FilePath "$global:workdir\updates\$Prod\$ver\$severityFolder\" -UpdateName $update.LocalizedDisplayName
```

**Consideration**: This would require updating `Deploy-Updates` to search subfolders, or separate deployment calls per severity. May be scope creep for this fix.

## Files Modified

- `WIMWitch-tNG/Private/WWFunctions.ps1` - `Invoke-MEMCMUpdatecatalog` function

## Dependencies

- ConfigMgr WMI access to `SMS_SoftwareUpdate` class
- Property name verification (Phase 2 research)
- `$WPFUpdatesCBEnableOptional` checkbox state available in function scope (already is)

## Backward Compatibility

**Breaking Change**: ConfigMgr users will no longer download Optional updates by default

**Mitigation**:
- Document the change clearly in release notes
- Default checkbox state should match previous behavior (check if it defaults to ON or OFF)
- If defaulted to OFF, users who want optional updates must check the box

**Current Default State**: Need to verify checkbox default in XAML

## Success Criteria

- [ ] ConfigMgr optional updates **skipped** when checkbox is **unchecked**
- [ ] ConfigMgr optional updates **downloaded** when checkbox is **checked**
- [ ] OSDSUS optional functionality **unchanged** (regression test passes)
- [ ] Checkbox state correctly saved/loaded in configuration files (already working)
- [ ] Clear logging indicates when optional updates are skipped
- [ ] No performance degradation in update query/download
- [ ] Definition updates always skipped (not applicable to offline servicing)

## Testing Checklist

- [ ] Phase 2: Identify correct severity property name from ConfigMgr WMI
- [ ] Phase 1: Implement severity filtering logic
- [ ] Test: ConfigMgr with checkbox OFF → Optional updates skipped
- [ ] Test: ConfigMgr with checkbox ON → Optional updates downloaded
- [ ] Test: OSDSUS with checkbox OFF → Optional updates skipped (existing)
- [ ] Test: OSDSUS with checkbox ON → Optional updates downloaded (existing)
- [ ] Test: Save configuration with checkbox state → Load → State preserved
- [ ] Test: Apply updates with optional checkbox OFF → No optional applied
- [ ] Test: Apply updates with optional checkbox ON → Optional applied
- [ ] Verify: Definition updates never downloaded (both sources)

## Notes

- **Property Research Critical**: Must verify exact WMI property name before implementation
- ConfigMgr `SMS_SoftwareUpdate` class may use different property names than expected
- Alternative approach: Use `LocalizedCategoryInstanceNames` array if severity property unavailable
- Consider logging all available properties of first update for documentation
- OSDSUS uses `UpdateGroup` property (from OSD module), ConfigMgr uses native WMI properties

## Alternative: Category-Based Filtering

If `SeverityName` property doesn't exist, use category filtering:

```powershell
# Check if update belongs to optional category
$categories = $update.LocalizedCategoryInstanceNames
$isOptional = $categories -contains 'Optional Updates' -or
              $categories -contains 'Feature Packs' -or
              $update.LocalizedDisplayName -like '*Optional*'

if ($isOptional -and ($WPFUpdatesCBEnableOptional.IsChecked -ne $True)) {
    Update-Log -Data "Skipping optional update: $($update.LocalizedDisplayName)" -Class Information
    continue
}
```

## Implementation Status

- **Phase 1**: Pending (awaiting Phase 2 research)
- **Phase 2**: Ready to execute (WMI property research)
- **Phase 3**: Pending (testing after implementation)
- **Phase 4**: Optional (future enhancement)
