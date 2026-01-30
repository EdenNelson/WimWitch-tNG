# Plan: Fix five small WIMWitch UI and download bugs

Fix eight independent bugs: (1) WIM file picker defaults to Desktop, (2) child checkboxes appear enabled but unresponsive after config load until parent toggled, (3) ConfigMgr package settings files save duplicate Distribution Points, (4) OneDrive x86 downloads to wrong directory, (5) OneDrive doesn't respect Windows version for architecture selection, (6) OneDrive downloads unneeded architectures, (7) Copy-OneDrive applies wrong architecture installer and fails on missing files, (8) Mount path inconsistency — uses hardcoded path instead of working directory.

## Steps

1. Update [Select-SourceWIM](../../WIMWitch-tNG/Private/Functions/WIMOperations/Select-SourceWIM.ps1) `InitialDirectory` property to use `$global:workdir\Imports\Wims` with directory validation before use.

2. Fix [Reset-MISCheckBox](../../WIMWitch-tNG/Private/Functions/UI/Reset-MISCheckBox.ps1) to properly enable/disable dependent controls: add `else` branches setting `IsEnabled = $False` when parent unchecked, ensure `IsEnabled = $True` when parent checked (affects JSON, Drivers, AppX, Custom Script, App Association, Registry child controls).

3. Fix [Save-Configuration](../../WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1) to deduplicate `CMDPList` before writing ConfigMgr package settings files (e.g., use `Select-Object -Unique` on the DP list prior to saving).

4. Fix [Get-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Get-OneDrive.ps1) function:
   - Change x86 download path from `\updates\OneDrive` to `\updates\OneDrive\x86`
   - Add Windows version detection to skip x86 for Windows 11
   - Add ARM64 download for Windows 11: `https://go.microsoft.com/fwlink/?linkid=2282608` to `\updates\OneDrive\arm64`
   - Validate all architecture directories exist before download

5. Update [Copy-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Copy-OneDrive.ps1) to handle x86/x64/ARM64 using same logic with different source paths based on WIM architecture being serviced.

6. Download only the OneDrive installer(s) matching the OS/architecture being serviced during the run, skipping unneeded architectures (e.g., Win10: x86+x64; Win11: x64+ARM64).

7. Fix [Copy-OneDrive](../../WIMWitch-tNG/Private/Functions/DotNetOneDrive/Copy-OneDrive.ps1) function to apply only the correct OneDrive architecture:
   - Add silent file existence check before attempting ACL modifications (test path, skip if not found)
   - Detect WIM architecture being serviced (x64, ARM64, x86) to determine which installer to copy
   - For Windows 11 images: only copy x64 or ARM64 OneDrive (never x86)
   - For Windows 10 images: copy appropriate architecture (x86 to SysWOW64, x64 to System32)

8. Fix mount path derivation to ensure it uses `$global:workdir\Mount` instead of hardcoded path:
   - Audit all functions using `$mountpath` variable to verify it's set from `$WPFMISMountTextBox.text` or derived from working directory
   - Ensure mount path remains consistent throughout the run (all paths should be under `$global:workdir`)
   - Update any hardcoded references to legacy `D:\Scripts\WIMWitch\Mount` paths

## Implementation Notes

- All OneDrive architectures share the same download/copy logic; only the needed architectures for the current WIM are downloaded (Win10: x86+x64, Win11: x64+ARM64)
- Directory validation ensures paths exist before operations
- Deduplication is applied on save to ensure ConfigMgr package files contain unique Distribution Points

