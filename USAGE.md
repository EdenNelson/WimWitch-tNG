# WIMWitch-tNG Usage Instructions

## How to Run WIMWitch-tNG

WIMWitch-tNG is a PowerShell **module**, not a standalone script. Follow these steps to use it correctly:

### Option 1: Import and Run (Recommended)

```powershell
# Navigate to the folder containing the WIMWitch-tNG module
cd C:\Path\To\WIMWitch-tNG

# Import the module
Import-Module .\WIMWitch-tNG\WIMWitch-tNG.psd1 -Force

# Run the tool
Invoke-WimWitchTng
```

### Option 2: Import from Module Path

If you place the WIMWitch-tNG folder in your PowerShell modules directory (e.g., `C:\Program Files\WindowsPowerShell\Modules\`), you can import it by name:

```powershell
Import-Module WIMWitch-tNG
Invoke-WimWitchTng
```

## Common Mistakes

### ❌ DO NOT dot-source individual files:
```powershell
# This will NOT work:
. .\WIMWitch-tNG\Public\WIMWitch-tNG.ps1
```

### ❌ DO NOT run the .ps1 files directly:
```powershell
# This will NOT work:
.\WIMWitch-tNG\Public\WIMWitch-tNG.ps1
```

## Why This Matters

The module consists of multiple files:
- **WIMWitch-tNG.psm1**: Main module file that loads all functions
- **Private/WWFunctions.ps1**: Internal helper functions
- **Public/WIMWitch-tNG.ps1**: Main exported function

When you import the module using `Import-Module`, PowerShell:
1. Reads the module manifest (.psd1)
2. Loads the root module (.psm1)
3. Dot-sources all Private and Public .ps1 files
4. Exports only the public functions

This ensures all dependencies are loaded in the correct order and scope.

## Parameters

The `Invoke-WimWitchTng` function supports several parameters for automation:

```powershell
Invoke-WimWitchTng -WorkingPath "D:\Scripts\WIMWitchFK" -AutoFixMount
```

See the function help for more details:
```powershell
Get-Help Invoke-WimWitchTng -Detailed
```
