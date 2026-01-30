# AppX Raw Data Files

This directory stores raw data files collected from Windows installations. These files contain unfiltered AppX package data used by the AI processing workflow.

**Files in this directory:**
- `appxData-Win{Version}-Build{Number}-raw.psd1` - Raw package data from Windows installations

**Note:** These files are typically **NOT committed** to the repository (see `.gitignore`). They are intermediate data files used during the processing workflow.

## Keeping Raw Data Files (Optional)

If you want to preserve raw data files for future reprocessing or analysis:

1. Store them in a separate backup location
2. Or, commit specific files by forcing git add:
   ```bash
   git add -f tools/appxData/appxData-Win11-25H2-Build26200-raw.psd1
   ```

## Workflow

1. **Collect:** Run `Collect-AppxData.ps1` on Windows VM → generates raw data file here
2. **Copy:** Transfer raw data file to development machine
3. **Process:** AI agent reads raw data → generates final PSD1 in `WIMWitch-tNG/Private/Assets/`
4. **Clean:** Optionally delete raw data file after processing (or keep for reprocessing)

## File Size

Raw data files are typically 100-200 KB each. If collecting multiple Windows versions, expect:
- Win10 22H2: ~120 KB
- Win11 23H2: ~150 KB
- Win11 24H2: ~160 KB
- Win11 25H2: ~170 KB

**Total for all versions:** ~600 KB (minimal storage impact)

---

See `../README-AppxDataCollection.md` for complete workflow documentation.
