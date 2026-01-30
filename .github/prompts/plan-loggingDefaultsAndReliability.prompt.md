```prompt
# Plan: Logging Defaults and Reliability

**TL;DR:** Guarantee file logging by default, create a predictable log path under `$global:workdir\Logging`, and harden `Update-Log` so it never silently skips file output.

## Current Behavior
- `Update-Log` writes to the file path stored in `$Log`, but `$Log` is unset in normal runs, so only console output occurs (colorized). Function is located in [WIMWitch-tNG/Private/Functions/Logging/Update-Log.ps1](../../WIMWitch-tNG/Private/Functions/Logging/Update-Log.ps1).
- `Set-Logging` creates `Logging\WIMWitch-tNG.log` and other folders, but it does not set `$Log` or run automatically at startup. It also deletes the log file on each call (function starts ~L733 in the same file).
- No override parameter exists for a custom log path. Logging can fail quietly if the directory is missing or unwritable.

## Goals
- Default every session to a real log file (no manual setup required).
- Avoid deleting prior logs; prefer append or timestamped files.
- Provide an optional override for a custom log path while keeping the default safe.
- Make logging resilient: if file write fails, warn once and keep console output.

## Plan
1. **Define default log path helper**
   - Create `Get-DefaultLogPath` (or refactor `Set-Logging`) to compute a per-run file: `$global:workdir/Logging/WIMWitch-tNG_<yyyyMMdd_HHmmss>.log`.
   - Ensure the Logging directory exists; create it if missing.
   - Set `$global:Log` and `$global:ScriptLogFilePath` to this path once per run.

2. **Initialize early**
   - Call the helper at application startup (CLI entry in Public/WIMWitch-tNG.ps1 and GUI entry in `Invoke-WimWitchTng`).
   - Guard against double initialization; reuse the existing path if already set.

3. **Harden `Update-Log`**
   - If `$Log` is unset when called, lazily initialize using the helper before writing.
   - Wrap `Add-Content` in try/catch; on failure, emit a warning once and continue host output.
   - Keep colorized console output as-is; avoid duplication in case of failures.

4. **Respect custom paths**
   - Add an optional `-LogPath` (or `$global:LogOverride`) input at startup. When provided, validate directory exists or create it, then set `$Log` to that path.
   - Do not delete existing files when a custom path is supplied; append a session header instead.

5. **Preserve existing folder checks**
   - Keep the Updates/Staging/Mount/Configs directory creation currently in `Set-Logging`, but stop deleting the log file on each call. If necessary, move these folder checks to a separate init function and call it once at startup.

## Testing
- Fresh run with no Logging directory: verify directory created and log file written with session header.
- Run twice in same session: confirm no new file is created and log appends (or, if timestamping, new file per run without deletion).
- Provide custom log path: verify file creation and subsequent `Update-Log` calls append to it.
- Simulate unwritable log path: ensure a warning is emitted once, console output continues, and the session stays alive.
- Verify log entries capture both file and console output for Information/Warning/Error/Comment classes.
```
