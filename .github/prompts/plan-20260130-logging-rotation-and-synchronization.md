# Plan: Implement Log Rotation Scheme & Fix File Lock Issues

**Date:** 2026-01-30
**Type:** Bug Fix + Enhancement
**Priority:** High
**Status:** Draft - Awaiting Approval

---

## 1. PROBLEM STATEMENT

### Current Issues

#### Issue A: File Lock Contention

Three errors observed during runtime:

1. **Set-Logging creates duplicate file:**
   ```
   New-Item : The file 'D:\Scripts\WIMWitchFK\logging\WIMWitch-tNG.log' already exists.
   At Set-Logging.ps1:5
   ```

2. **Concurrent write failures:**
   ```
   Add-Content : The process cannot access the file 'D:\Scripts\WIMWitchFK\logging\WIMWitch-tNG.log'
   because it is being used by another process.
   At Update-Log.ps1:37
   ```

3. **Root causes:**
   - Filename mismatch: Code checks for `WIMWitch.Log` but creates `WIMWitch-tNG.log`
   - `New-Item` doesn't use `-Force` flag, fails if file exists
   - `New-Item` keeps file handle open briefly, blocking `Update-Log` writes
   - No retry logic for transient lock failures

#### Issue B: Log Rotation Not Implemented

- Log file is **blanked/removed** at start of each run
- No historical logs preserved for debugging
- Hard to troubleshoot issues from previous runs
- Single log file gets overwritten with each execution

### User Impact

- Script fails with "file in use" errors mid-run
- No audit trail of previous runs
- Cannot compare logs across multiple runs
- Debugging problematic runs requires re-running code

---

## 2. ROOT CAUSE ANALYSIS

### Set-Logging.ps1 Issues

**Line 2:** Checks wrong filename
```powershell
if (!(Test-Path -Path "$global:workdir\logging\WIMWitch.Log" -PathType Leaf)) {
    # Note: checks for "WIMWitch.Log" but creates "WIMWitch-tNG.log"
```

**Line 5:** Creates file without `-Force`
```powershell
New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***'
# Will fail if file already exists from previous interrupted run
```

**Line 6:** Removes and recreates, causing brief lock window
```powershell
Remove-Item -Path "$global:workdir\logging\WIMWitch-tNG.log"
New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log" ...
# File handle from New-Item may still be open when Update-Log tries to write
```

### Update-Log.ps1 Issues

**Line 37:** No retry logic for file locks
```powershell
if ($Log) {
    Add-Content -Path $Log -Value $LogString
    # No error handling if file is temporarily locked
}
```

### Design Flaw

The current approach assumes:
- One process writing to the log
- Sequential write operations with no contention
- No background jobs or parallel execution

Reality:
- Multiple background jobs may write simultaneously
- File can be locked briefly during Set-Logging operations
- No mechanism to handle transient lock failures

---

## 3. SOLUTION DESIGN

### Strategy: Log Rotation + Thread-Safe Logging

**Principles:**
1. Keep last 5 runs of logs for historical reference
2. Rotate logs at **start of run** (not blanking)
3. Use file-lock-safe write method with retry logic
4. Support concurrent writes from background jobs

### Component A: Log Rotation at Startup

**Function:** `Initialize-LogRotation` (new)

**Logic:**
```
When Set-Logging is called:
1. Check if current log exists (WIMWitch-tNG.log)
2. If exists, rename to timestamped archive (WIMWitch-tNG-YYYYMMDD-HHMMSS.log)
3. Archive old logs to archive/ subdirectory
4. Keep only 5 most recent archives
5. Delete logs older than 5 runs
6. Create fresh WIMWitch-tNG.log for current run
```

**Archive Structure:**
```
logging/
  ├── WIMWitch-tNG.log                          (current run)
  └── archive/
      ├── WIMWitch-tNG-20260130-085300.log      (5 runs ago)
      ├── WIMWitch-tNG-20260130-084200.log      (4 runs ago)
      ├── WIMWitch-tNG-20260130-083100.log      (3 runs ago)
      ├── WIMWitch-tNG-20260130-082000.log      (2 runs ago)
      └── WIMWitch-tNG-20260130-080900.log      (1 run ago)
```

### Component B: Thread-Safe Log Writing

**Function:** Enhanced `Update-Log` with retry logic

**Implementation:**
- Replace `Add-Content` with `[System.IO.File]::AppendAllText()` (more lock-friendly)
- Add exponential backoff retry: 3 attempts with 100ms-500ms delays
- Skip write if file permanently locked (prevents crash, logs to console)
- Use file access mode: `FileShare.ReadWrite` to allow concurrent reads

**Pseudo-code:**
```powershell
$maxRetries = 3
$retryDelay = 100

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        [System.IO.File]::AppendAllText($Log, $LogString + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        return  # Success
    }
    catch {
        if ($attempt -lt $maxRetries) {
            Start-Sleep -Milliseconds $retryDelay
            $retryDelay *= 2  # Exponential backoff
        }
        else {
            # Final attempt failed - log to console only
            Write-Host "Warning: Could not write to log file (locked). Message: $LogString"
        }
    }
}
```

### Component C: Fix Set-Logging Initialization

**Changes:**
1. Fix filename check (WIMWitch.Log → WIMWitch-tNG.log)
2. Use `-Force` flag on `New-Item`
3. Call new `Initialize-LogRotation` function
4. Create fresh log file with initial message

---

## 4. IMPLEMENTATION PLAN

### Stage 1: Create Log Rotation Function

**File:** `WIMWitch-tNG/Private/Functions/Logging/Initialize-LogRotation.ps1` (NEW)

**Responsibilities:**
- Check if current log exists
- Rename current log to timestamped archive
- Move archive to `logging/archive/` subdirectory
- Count existing archives
- Delete oldest archives if count > 5
- Create `archive/` subdirectory if needed

**Tests:**
- [ ] First run (no existing log) → creates clean log
- [ ] Second run (log exists) → archives previous, creates clean log
- [ ] Multiple runs → maintains only 5 archives, deletes oldest
- [ ] Edge case: archive directory missing → creates it

### Stage 2: Enhance Update-Log with Retry Logic

**File:** `WIMWitch-tNG/Private/Functions/Logging/Update-Log.ps1` (MODIFIED)

**Changes:**
- Replace `Add-Content` with `[System.IO.File]::AppendAllText()`
- Add try-catch with exponential backoff retry (3 attempts)
- Log retry failures to console (don't crash script)
- Preserve existing color-coded console output

**Tests:**
- [ ] Normal write succeeds on first attempt
- [ ] Transient lock handled gracefully with retry
- [ ] Permanent lock logs warning and continues
- [ ] Concurrent writes from multiple jobs succeed
- [ ] Console output still color-coded

### Stage 3: Fix Set-Logging Initialization

**File:** `WIMWitch-tNG/Private/Functions/Logging/Set-Logging.ps1` (MODIFIED)

**Changes:**
- Line 2: Fix filename check: `WIMWitch.Log` → `WIMWitch-tNG.log`
- Line 5: Add `-Force` flag to `New-Item`
- Line 5-8: Replace remove/recreate logic with call to `Initialize-LogRotation`
- Simplify to: Call `Initialize-LogRotation`, then create fresh log

**Before:**
```powershell
if (!(Test-Path -Path "$global:workdir\logging\WIMWitch.Log" -PathType Leaf)) {
    New-Item -ItemType Directory -Force -Path "$global:workdir\Logging" | Out-Null
    New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
} Else {
    Remove-Item -Path "$global:workdir\logging\WIMWitch-tNG.log"
    New-Item -Path "$global:workdir\logging" -Name 'WIMWitch-tNG.log' -ItemType 'file' -Value '***Logging Started***' | Out-Null
}
```

**After:**
```powershell
# Ensure logging directory exists
New-Item -ItemType Directory -Force -Path "$global:workdir\Logging" | Out-Null

# Rotate existing logs
Initialize-LogRotation -LogDirectory "$global:workdir\Logging" -MaxArchives 5

# Create fresh log for current run
$LogContent = "$(Get-Date) Information  -  ***Logging Started***"
[System.IO.File]::WriteAllText("$global:workdir\logging\WIMWitch-tNG.log", $LogContent)
```

### Stage 4: Verification & Testing

**Manual Tests:**
- [ ] Run script 6+ times, verify only 5 archives kept
- [ ] Check archive naming format (YYYYMMDD-HHMMSS)
- [ ] Open current log in CMTrace, verify no lock contention
- [ ] Trigger background jobs, verify concurrent writes succeed
- [ ] Force lock condition (open log in notepad), verify graceful degradation

**Automated Tests:**
- [ ] Unit test `Initialize-LogRotation` with mock files
- [ ] Unit test `Update-Log` retry logic with locked file simulation
- [ ] Integration test full run with concurrent logging

---

## 5. FILES AFFECTED

### New Files
- `WIMWitch-tNG/Private/Functions/Logging/Initialize-LogRotation.ps1` (~50 lines)

### Modified Files
- `WIMWitch-tNG/Private/Functions/Logging/Update-Log.ps1` (~10 lines changed)
- `WIMWitch-tNG/Private/Functions/Logging/Set-Logging.ps1` (~15 lines changed)

### Total Impact
- Lines Added: ~75
- Lines Modified: ~25
- Lines Deleted: ~15
- Net Change: +35 lines

---

## 6. EXPECTED OUTCOMES

### Before
- ❌ File lock errors during concurrent logging
- ❌ No historical logs for debugging
- ❌ Log file blanked at each run
- ❌ Hard to compare behavior across runs

### After
- ✅ Thread-safe logging with retry logic
- ✅ Last 5 runs preserved for historical reference
- ✅ Fresh log for each run (easy to identify current vs archived)
- ✅ Can compare logs across multiple runs
- ✅ File lock errors handled gracefully
- ✅ CMTrace can monitor without contention

---

## 7. RISKS & MITIGATIONS

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Archive disk space grows | Medium | Only keep 5 archives (~5-50MB typical) |
| Clock skew on filename | Low | Use `Get-Date` consistently, falls back to counter if needed |
| Race condition on rotation | Low | Use atomic file operations, retry on conflict |
| Performance overhead | Low | File appends are ~1ms, retry backoff is exponential |

---

## 8. EFFORT ESTIMATE

- **Complexity:** Medium
- **Implementation Time:** 3-4 hours (code + testing)
- **Testing Time:** 2-3 hours (multiple runs, concurrent jobs)
- **Total:** 5-7 hours

**Risk Level:** Low (isolated to logging functions, no core logic affected)

---

## ACCEPTANCE CRITERIA

- [ ] `Initialize-LogRotation` function created and tested
- [ ] `Update-Log` uses `[System.IO.File]::AppendAllText()` with retry logic
- [ ] `Set-Logging` calls rotation function on startup
- [ ] Filename check corrected (WIMWitch.Log → WIMWitch-tNG.log)
- [ ] No "file in use" errors during concurrent logging
- [ ] Last 5 run logs preserved in `logging/archive/`
- [ ] CMTrace can open current log without contention
- [ ] Manual testing with 6+ consecutive runs passes
- [ ] All existing logging features preserved

---

## APPROVAL REQUESTED

**Recommendation:** Approve for implementation.

**Rationale:** Solves real production errors while adding valuable debugging capability (historical logs). Low risk, isolated changes, significant UX improvement.
