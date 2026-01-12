Plan: Fork + PSD1 Assets + Rename

Create the WIMWitch-tNG fork, convert AppX asset lists to PSD1, and update project naming and references while keeping functionality intact.

Steps

1. Rename project directory and files: move WimWitchFK/ → WIMWitch-tNG/; rename WimWitchFK.psd1 → WIMWitch-tNG.psd1, WimWitchFK.psm1 → WIMWitch-tNG.psm1, and Public/WIMWitchFK.ps1 → Public/WIMWitch-tNG.ps1. Ensure FunctionsToExport and RootModule match new names.

2. Convert Assets to PSD1: for each file in WIMWitch-tNG/Private/Assets/ (e.g., appxWin10_22H2.txt, appxWin11_23H2.txt), create appxWin*_*.psd1 with minimal schema: @{ Packages = @('line1', 'line2', ...) } copied from the existing .txt lines.

3. Verify ingestion code: confirm Select-Appx builds .psd1 paths and uses Import-PowerShellDataFile with $appxData.Packages. Validate OS/build mapping via Get-WindowsType() and Get-WinVersionNumber() so filenames align.

4. Update branding references: replace remaining “WIMWitchFK” strings in UI/logs (e.g., closing text and workdir selection). Update ReleaseNotes and URLs in the manifest to point to the new repo.

5. Test end-to-end: import the module, launch the GUI via WIMWitch-tNG, pick AppX entries from PSD1 lists across a few builds (Win10 22H2, Win11 23H2), verify selections propagate to Invoke-MakeItSo and removal via Remove-Appx, and confirm logging and config save/load.

Further Considerations

1. PSD1 schema: stick to minimal Packages array now; add metadata like OS, Build, Updated later without code changes.
2. Backward compatibility: optionally keep .txt during transition with a fallback loader, or fully migrate now since ingestion targets .psd1.
3. Function naming: main entry stays WIMWitch-tNG per manifest; consider Start-WIMWitchTNG later for Verb-Noun style if publishing.
