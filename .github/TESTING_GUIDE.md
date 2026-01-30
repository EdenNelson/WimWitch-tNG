# Testing Guide: Verbose Logging & Settings Persistence

## Quick Start: Test with Verbose Output

### Step 1: Start the Script with Verbose Flag
```powershell
cd /Users/nelson/Documents/GitHub/WimWitch-tNG
.\WIMWitch-tNG\Public\WIMWitch-tNG.ps1 -Verbose
```

Or load and run from PowerShell:
```powershell
Import-Module ./WIMWitch-tNG/WIMWitch-tNG.psm1
Invoke-WimWitchTng -Verbose
```

### Step 2: Configure Customization Tab Settings
Navigate to **"Pause + Scripts"** tab and set:
1. Check **"Pause After Mount"** checkbox
2. Check **"Pause Before Dismount"** checkbox
3. Check **"Run Script"** checkbox
4. Set **"Script Timing"** to any option
5. Enter **"Script File"** path (e.g., `C:\Scripts\MyScript.ps1`)
6. Enter **"Parameters"** (e.g., `-Param1 Value1`)

### Step 3: Configure Make It So Tab Settings
Navigate to **"Make It So"** tab and set:
1. Check **"Create ISO"** checkbox
2. Enter **"ISO File Name"** (e.g., `Win11_Custom.iso`)
3. Click **"Select"** button and choose output path
4. Check **"Upgrade Package Path"** checkbox
5. Enter **"Upgrade Package Path"** (e.g., `C:\upgrade\custom`)

### Step 4: Save Configuration
1. Click **"Save"** button
2. Enter a config name (e.g., `MyTestConfig`)
3. Check console output for **[SAVE]** log messages

**Expected Output in Console/Log:**
```
[SAVE] Starting configuration save for: MyTestConfig
[SAVE] Customization Tab (Pause + Scripts) Settings:  PauseAfterMount=True | PauseBeforeDM=True | RunScript=True | ScriptFile=C:\Scripts\MyScript.ps1 | ScriptTiming=BeforeWindowsInstallation
[SAVE] Make It So Tab - Dynamic/Boot/NoWIM Settings:  ApplyDynamic=False | UpdateBootWIM=False | DoNotCreateWIM=False
[SAVE] ISO Creation Settings:  CreateISO=True | Filename=Win11_Custom.iso | Path=C:\output\path
[SAVE] Upgrade Package Settings:  Enabled=True | Path=C:\upgrade\custom
file saved
```

### Step 5: Clear/Reset Form
1. Clear all the values you just entered in both tabs
2. Verify the form is now empty

### Step 6: Load Configuration
1. Click **"Load"** button
2. Select the config file you just saved (e.g., `MyTestConfig.psd1`)
3. Check console output for **[LOAD]** log messages

**Expected Output in Console/Log:**
```
[LOAD] Starting configuration load from: C:\workdir\Configs\MyTestConfig.psd1
[LOAD] Using PowerShell Data File (.psd1) format
[LOAD] Customization Tab (Pause + Scripts) Restored:  PauseAfterMount=True | PauseBeforeDM=True | RunScript=True | ScriptFile=C:\Scripts\MyScript.ps1 | ScriptTiming=BeforeWindowsInstallation
[LOAD] ISO Creation Settings Restored:  CreateISO=True | Filename=Win11_Custom.iso | Path=C:\output\path
[LOAD] Upgrade Package Settings Restored:  Enabled=True | Path=C:\upgrade\custom
[LOAD] Configuration file loaded successfully - all settings restored
Config file loaded successfully
```

### Step 7: Verify UI Restoration
Verify that ALL values you saved are now displayed in the form:
- ✅ Customization tab shows all pause/script values
- ✅ Make It So tab shows ISO settings (enabled, filename, path)
- ✅ Make It So tab shows Upgrade Package settings (enabled, path)

## Log File Location

View the detailed log file:
```
$global:workdir\logging\WIMWitch-tNG.log
```

Or in PowerShell:
```powershell
Get-Content "$($PROFILE)\..\workdir\logging\WIMWitch-tNG.log" -Tail 100
```

## Troubleshooting: If Settings Don't Persist

### Check 1: Is verbose logging enabled?
- Look for `[SAVE]` and `[LOAD]` messages in console
- If not present, ensure script was called with `-Verbose` parameter

### Check 2: Were control names saved correctly?
- In save output, look for the actual values you entered
- Example: `CreateISO=True` means the ISO checkbox was checked
- Example: `Filename=Win11_Custom.iso` means filename was captured

### Check 3: Were settings restored correctly?
- In load output, same values should appear
- If values are different or missing, check control name mappings

### Check 4: Does the .psd1 file exist and contain data?
```powershell
Get-Content "$global:workdir\Configs\MyTestConfig.psd1"
```

Should show all settings in PowerShell hashtable format:
```powershell
@{
    'CreateISO'            = $true
    'ISOFileName'          = 'Win11_Custom.iso'
    'ISOFilePath'          = 'C:\output\path'
    'UpgradePackageCB'     = $true
    'UpgradePackPath'      = 'C:\upgrade\custom'
    'PauseAfterMount'      = $true
    'PauseBeforeDM'        = $true
    'RunScript'            = $true
    'ScriptFile'           = 'C:\Scripts\MyScript.ps1'
    'ScriptTiming'         = 'BeforeWindowsInstallation'
    # ... etc ...
}
```

## Additional Testing Scenarios

### Test with Legacy XML Files
If you have old `.xml` config files:
1. Place an old `.xml` file in `$global:workdir\Configs\`
2. Load it with `-Verbose`
3. Verify you see: `[LOAD] Using legacy XML format - file will be upgraded to .psd1 on next save`
4. Save the config
5. Verify new `.psd1` file is created and old `.xml` remains

### Test Partial Settings
Try saving with only some fields filled:
1. Set ONLY ISO settings (skip Upgrade Package)
2. Save and verify in log that ISO has values, Upgrade Package is empty
3. Load and verify UI shows only ISO settings

### Test with Multiple Configs
Create and test loading different config files:
1. `Config1.psd1` - ISO only
2. `Config2.psd1` - Upgrade Package only
3. `Config3.psd1` - Both ISO and Upgrade Package
4. Load each and verify correct settings appear

## Success Criteria

✅ **Test passes if:**
1. Script runs without errors with `-Verbose` parameter
2. [SAVE] messages appear when saving configuration
3. All field values appear in save messages (ISO filename, paths, checkboxes, etc.)
4. [LOAD] messages appear when loading configuration
5. All previously saved values appear in load messages
6. UI populates correctly after load - no fields are blank that should have values
7. Both .psd1 and .xml formats are supported for loading
8. Legacy .xml files can be loaded and upgraded to .psd1 format
