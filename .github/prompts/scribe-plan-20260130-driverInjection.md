# Scribe Plan: Driver Injection Performance & Method Selection

**Date:** 2026-01-30
**Topic:** Driver injection performance optimization and user choice
**Session Type:** Requirement capture (Scribe mode)

---

## Problem Statement

The current driver injection process uses a PowerShell loop to inject drivers into WIM images, which is slow. Users need a faster option without losing the ability to use the existing method when needed.

The current implementation does not stop on injection failures (it continues processing), and there is no visibility into which specific driver INF files failed during injection.

---

## User Intent

The user wants to:

1. **Add a faster driver injection method** using native DISM recursive injection (`dism.exe /Add-Driver /Recurse`)
2. **Preserve the existing PowerShell loop method** as an option
3. **Give users a choice** via a toggle/switch on the driver tab to select between:
   - PowerShell loop (current, slower, existing behavior)
   - DISM recursive (new, faster)
4. **Maintain existing failure handling behavior**: Do not stop processing when driver injection fails; continue to completion
5. **Add failure visibility**: Parse DISM logs to identify which specific INF files failed, and surface those failures to the user

---

## Constraints

### Must Preserve

- Existing PowerShell loop logic must remain intact and functional
- Current behavior: driver injection failures do not halt the process
- Existing log directory path must be reused for DISM logging (already established in code)

### Must Add

- UI toggle/switch on the driver tab to select injection method
- DISM recursive injection option using `/Recurse` flag
- DISM logging to the existing log directory with appropriate log level (`/LogLevel:3`)
- Log parsing logic to detect failures (pattern: `\[.*\]\s+Error`)
- User-facing output showing which specific INF files failed (extracted from DISM log)

### Must Avoid

- Breaking existing driver injection workflows
- Changing the "continue on failure" behavior (both methods must continue processing)
- Creating a new log directory (reuse existing)

---

## Success Criteria

We are done when:

1. The driver tab has a UI control (checkbox, radio button, or similar) to choose between "PowerShell Loop" and "DISM Recursive"
2. The existing PowerShell loop method still works as it does today
3. The new DISM recursive method:
   - Calls `dism.exe /Add-Driver /Driver:<path> /Recurse /LogPath:<existing-log-dir> /LogLevel:3`
   - Uses the existing logging directory that's already in the code
   - Does not halt on failures (matches current behavior)
   - Parses the DISM log after completion to extract failed INF files
   - Displays failures to the user (e.g., "Failed: DriverName.inf" in red or warning style)
4. If all drivers succeed, the user sees a success message (e.g., "All drivers injected successfully")
5. The user can switch between methods and both work correctly

---

## Notes

- Example DISM command structure provided by user:

  ```powershell
  dism.exe /Image:"C:\test\offline" /Add-Driver /Driver:"C:\drivers" /Recurse /LogPath:$LogLocation /LogLevel:3
  ```

- Example log parsing pattern: `Select-String -Path $LogLocation -Pattern "\[.*\]\s+Error"`
- Failure extraction should identify the specific INF file name from the log line
