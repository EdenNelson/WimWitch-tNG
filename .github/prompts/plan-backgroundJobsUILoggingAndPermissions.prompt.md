# Plan: Background Jobs with UI Management, Logging Tab, and Permission Handling

**TL;DR:** Run long operations as background jobs to keep UI responsive. Disable action buttons during execution. Add a Logging tab with real-time log updates. Enhance cleanup with TrustedInstaller permission handling and support operation cancellation.

## Phase 1: Background Job Infrastructure

### 1.1 Create `Start-OperationJob` Function
- Wrapper function to execute operation in background job
- Parameters: `$OperationName`, `$ScriptBlock`, `$ArgumentList`
- Sets `$global:CurrentOperation` to track active job
- Captures job output and redirects to Update-Log
- Returns job object for monitoring
- Logs operation start with timestamp

### 1.2 Create `Monitor-OperationJob` Function
- Monitors job completion status
- Polls job state (Running/Completed/Failed)
- Handles job output collection and logging
- Detects job errors/exceptions
- Calls cleanup handlers on completion
- Updates UI state when job finishes
- Returns job result or error

### 1.3 Create `Stop-OperationJob` Function
- Gracefully stop running background job
- Parameters: `$ConfirmationRequired` (boolean)
- Shows confirmation dialog to user if enabled
- Stops job with `Stop-Job -Force`
- Triggers emergency cleanup: Dismount all images, purge staging
- Clears `$global:CurrentOperation`
- Re-enables UI buttons
- Logs cancellation with reason

### 1.4 Add Global Operation Tracking
- `$global:CurrentOperation`: Stores active job object
- `$global:OperationStartTime`: Timestamp of operation start
- `$global:OperationName`: Human-readable operation name
- Helper check function `Test-OperationRunning` returns true/false

---

## Phase 2: UI State Management

### 2.1 Create `Disable-ActionButtons` Function
- Disables all long-running action buttons:
  - MakeItSoButton
  - UpdatesDownloadNewButton
  - ImportImportButton
- Disables TabControl to prevent tab switching during operation
- Disables WIM/Update selection controls
- Sets cursor to WaitCursor
- Stores previous enabled states for restoration

### 2.2 Create `Enable-ActionButtons` Function
- Re-enables all previously disabled buttons
- Re-enables TabControl
- Re-enables selection controls
- Sets cursor back to normal Arrow
- Called when operation completes (success or failure)

### 2.3 Create `Update-OperationStatus` Function
- Parameters: `$OperationName`, `$Status` (Running/Completed/Failed/Cancelled)
- Updates UI status label with operation name and status
- Updates status label color: Blue (Running), Green (Completed), Red (Failed), Orange (Cancelled)
- Shows elapsed time
- Formats as: "Operation: [OperationName] - [Status] ([ElapsedTime])"

### 2.4 Add Status Label to XAML
- Add Label control: `OperationStatusLabel`
- Position: Below the tab control or in status bar area
- Visible only during operation (hidden at startup)
- Font: Bold, readable size
- Background color: Optional (light gray)
- Binding: Controlled by `Update-OperationStatus`

---

## Phase 3: Enhanced Permission Handling

### 3.1 Create `Remove-ItemWithOwnership` Function
- Parameters: `$Path`, `$Recurse`, `$Force`, `$ErrorAction`
- Attempts standard `Remove-Item` first
- If access denied, uses `takeown.exe` to seize ownership:
  - `takeown /F $Path /R /D Y` (recursive, force, auto-yes)
  - Then retry `Remove-Item`
- Handles both files and directories
- Logs success/failure for each operation
- Returns: $true if successful, $false if failed
- Special handling for:
  - TrustedInstaller-owned files
  - System-protected directories
  - In-use/locked files (cannot delete, log warning)

### 3.2 Enhance `Invoke-ApplicationCleanup` Function
- Update Mount directory cleanup to use `Remove-ItemWithOwnership`
- Update Staging directory cleanup to use `Remove-ItemWithOwnership`
- Add detailed logging for each file/folder removed
- Add pre-cleanup check for locked files:
  - Use `Handle.exe` (if available) or check file handles
  - Log which processes hold locks
  - Suggest closing those processes or retry later
- Improve error recovery: attempt multiple cleanup passes if needed
- Add cleanup verification: confirm items actually deleted
- Log cleanup statistics (items removed, items failed, total size freed)

### 3.3 Update Cleanup Error Handling
- Distinguish between:
  - Permission errors (solvable via ownership change)
  - In-use errors (need process termination)
  - Other errors (log and continue)
- Add logging levels: INFO (success), WARNING (skipped), ERROR (failed)
- Provide user feedback on partial cleanup failures

---

## Phase 4: Logging Tab with Real-Time Updates

### 4.1 Add TextBox Control to XAML
- Control name: `LoggingTextBox`
- Type: MultiLine TextBox
- Properties:
  - `IsReadOnly="True"` (prevent user editing)
  - `VerticalScrollBarVisibility="Auto"` (auto scroll)
  - `HorizontalScrollBarVisibility="Auto"`
  - `Background="Black"`
  - `Foreground="White"`
  - `FontFamily="Courier New"` (monospace for alignment)
  - `FontSize="10"`
  - `TextWrapping="Wrap"`
- Add to TabControl as new "Captain's Log" tab
- Position: After existing tabs (e.g., Sources, Updates, Make It So, ConfigMgr, Custom, etc.)
- Tab Header: "Captain's Log" (user-facing tab label)

### 4.2 Create `Update-LogDisplay` Function
- Parameters: `$Message`, `$Class` (Information/Warning/Error/Comment)
- Appends message to `$WPFLoggingTextBox.Text`
- Format: Same as file log - `[Timestamp] [Class] - [Message]`
- Color coding in TextBox (if possible with RichTextBox, else plain text):
  - Information: Gray text
  - Warning: Yellow text
  - Error: Red text
  - Comment: Green text
- Auto-scrolls to bottom after new message
- Limits display to last 5000 lines (prevents memory issues with long-running operations)
- Clear old lines when exceeding limit (remove oldest first)

### 4.3 Modify `Update-Log` Function
- Current behavior: Write to file + Write-Host (console output)
- Add: Call `Update-LogDisplay` to update TextBox
- Ensure Update-LogDisplay runs on UI thread (use `$form.Dispatcher.Invoke()` if needed)
- Handle case where TextBox doesn't exist (early startup before GUI initialized)
- Non-blocking: If TextBox update fails, log still goes to file/console, continue execution

### 4.4 Clear Log on Startup
- Add option to clear log display on application start (optional checkbox)
- Or always show last 1000 lines on startup (preserve recent history)
- Add "Clear Log" button to Captain's Log tab for user convenience

---

## Phase 5: Wrap Action Button Handlers

### 5.1 Modify "Make It So" Button Handler (MakeItSoButton)
- Current: Direct call to `Invoke-MakeItSo` (synchronous, blocks UI)
- New flow:
  1. Check if operation already running: `if (Test-OperationRunning) { Show-MessageBox "Operation in progress..."; return }`
  2. Validate inputs (existing validation stays same)
  3. Disable UI: `Disable-ActionButtons`
  4. Update status: `Update-OperationStatus "Make It So" "Running"`
  5. Start job: `Start-OperationJob -OperationName "Make It So" -ScriptBlock { Invoke-MakeItSo @params }`
  6. Monitor job: `Monitor-OperationJob` (polls until completion)
  7. Handle result (success/failure)
  8. Update status: `Update-OperationStatus "Make It So" "Completed"` or "Failed"
  9. Re-enable UI: `Enable-ActionButtons`

### 5.2 Modify "Download Updates" Button Handler (UpdatesDownloadNewButton)
- Same flow as above but with:
  - Function: `Update-PatchSource`
  - Operation name: "Download Updates"
  - Parameters: Catalog source (OSDSUS/ConfigMgr), selected update categories

### 5.3 Modify "Import ISO" Button Handler (ImportImportButton)
- Same flow as above but with:
  - Function: `Import-ISO`
  - Operation name: "Import ISO"
  - Parameters: ISO path, extraction options

### 5.4 Error Handling in Button Handlers
- Wrap entire flow in try-catch
- On exception:
  - Log error details
  - Update status: "Failed"
  - Show error dialog to user
  - Ensure UI re-enabled even on exception
- Non-fatal errors (e.g., validation failure) show message but don't disable UI

---

## Phase 6: Cancel Operation Functionality

### 6.1 Add Cancel Button to UI
- Control name: `CancelOperationButton`
- Position: Near OperationStatusLabel (visible during operation only)
- Label: "Cancel Operation"
- Icon: Stop/X symbol (optional)
- Visibility: Hidden by default, shown when operation running
- Properties: Bold, red background (visual warning)

### 6.2 Connect Cancel Button Handler
- On click:
  1. Show confirmation dialog: "Are you sure you want to cancel the current operation? This will dismount any mounted images and purge staging directory."
  2. If user confirms:
     - Call `Stop-OperationJob -ConfirmationRequired $false` (already confirmed)
     - Show "Operation cancelled" message
     - Wait 2 seconds for cleanup
     - Re-enable UI
  3. If user cancels:
     - Do nothing, operation continues

### 6.3 Cleanup on Cancellation
- `Stop-OperationJob` should:
  - Kill background job process
  - Call `Dismount-WindowsImage` for all mounted images (with -Discard flag)
  - Call `Remove-ItemWithOwnership` to purge $workdir\Staging and $workdir\Mount
  - Log "Operation cancelled by user - cleanup initiated"
  - Log each cleanup action (dismount, file removal)
  - Ensure UI button states correct after cleanup

### 6.4 UI Updates During Cancellation
- Disable Cancel button immediately (prevent double-clicks)
- Show "Cleaning up..." message in status label
- Show progress indicator (spinner/animated ellipsis) during cleanup
- Update to "Cancelled" status when cleanup complete

---

## Phase 7: Job Output and Logging Integration

### 7.1 Configure Job Output Capture
- Background jobs capture `Write-Host` and `Write-Output` by default
- Each Update-Log call should output to:
  1. **File**: Via `Add-Content` to $global:Log (existing)
  2. **Console**: Via `Write-Host` with color (existing)
  3. **TextBox**: Via new `Update-LogDisplay` (new)
- Ensure job output redirected back to Update-Log or captured and re-logged

### 7.2 Handle Job Error Output
- Capture $PSItem from job errors
- Format as: `[Timestamp] Error - [Function]: [ErrorMessage]`
- Include line number and stack trace for debugging
- Log to all three destinations (file, console, TextBox)

### 7.3 Progress Updates from Job
- Jobs should periodically call `Update-Log -Data "Progress: [Details]" -Class Information`
- Examples: "Mounting WIM (1/5)...", "Applying LCU update (18 of 45)..."
- Ensures UI stays updated on long operations
- Time estimate updates if possible

---

## Dependency & Function Interaction Map

```
Button Handler (MakeItSoButton.Add_Click)
  ↓
Test-OperationRunning [Check if job already running]
  ↓
Disable-ActionButtons [Disable UI controls]
  ↓
Update-OperationStatus "Running" [Update display]
  ↓
Start-OperationJob [Launch background job]
  ├→ Invoke-MakeItSo [Actual operation in background]
  │   └→ Update-Log [Logs during operation]
  │       └→ Update-LogDisplay [Updates TextBox in real-time]
  │           └→ $WPFLoggingTextBox [UI TextBox receives updates]
  ↓
Monitor-OperationJob [Poll job status]
  └→ On completion: Enable-ActionButtons, Update-OperationStatus "Completed"
      └→ Remove-ItemWithOwnership [If cleanup needed]
          └→ Update-Log [Log cleanup results]
              └→ Update-LogDisplay [Display cleanup progress]

CancelOperationButton.Add_Click
  ↓
Stop-OperationJob [Kill job, trigger cleanup]
  └→ Dismount-WindowsImage [Unmount images]
  └→ Remove-ItemWithOwnership [Purge staging/mount]
      └→ Update-Log [Log cleanup actions]
          └→ Update-LogDisplay [Display cleanup progress]
  ↓
Enable-ActionButtons [Re-enable UI]
  ↓
Update-OperationStatus "Cancelled" [Update display]
```

---

## Implementation Order

1. **Create core functions first** (non-UI dependent):
   - Start-OperationJob
   - Monitor-OperationJob
   - Stop-OperationJob
   - Remove-ItemWithOwnership
   - Update-LogDisplay
   - Test-OperationRunning

2. **Update Update-Log** to call Update-LogDisplay

3. **Create UI management functions**:
   - Disable-ActionButtons
   - Enable-ActionButtons
   - Update-OperationStatus

4. **Enhance Invoke-ApplicationCleanup** to use Remove-ItemWithOwnership

5. **Add XAML controls**:
   - OperationStatusLabel
   - LoggingTextBox (Logging tab)
   - CancelOperationButton

6. **Update button handlers** to use new job infrastructure:
   - MakeItSoButton
   - UpdatesDownloadNewButton
   - ImportImportButton

7. **Connect Cancel button handler**

8. **Test** all scenarios:
   - Normal operation completion
   - Operation cancellation with cleanup
   - Permission-denied file deletion
   - Long operations with log streaming
   - UI responsiveness during background jobs

---

## Error Handling Strategy

### During Operation
- Background job exceptions caught in Monitor-OperationJob
- Logged with full details (message, stack trace)
- Displayed in logging tab and console
- Operation marked as "Failed"
- UI re-enabled for user to retry

### During Cleanup
- Permission errors trigger ownership change attempt
- In-use errors logged with suggestion to close process
- Partial cleanup failures don't block UI re-enable
- Full cleanup failure logs warning but continues

### UI Errors
- TextBox update failures don't block operations
- File logging always succeeds even if TextBox fails
- Graceful fallback: if TextBox unavailable, logs still go to file/console

---

## Testing Scenarios

1. ✓ Successful operation (Make It So) completes, UI responsive, logs display
2. ✓ Prevent second operation start while first running
3. ✓ Cancel operation mid-execution → proper cleanup (dismount, purge staging)
4. ✓ Long operation (2+ hours) maintains UI responsiveness
5. ✓ Log TextBox displays entries in real-time with color coding
6. ✓ Log TextBox scrolls to latest entries
7. ✓ Log limits to 5000 lines (clears oldest)
8. ✓ TrustedInstaller file deletion works via takeown
9. ✓ Permission denied errors handled gracefully
10. ✓ Multiple tabs accessible during operation? (Should be disabled - only cancel button accessible)
11. ✓ Application close during operation → cleanup triggered
12. ✓ Job output properly captured and logged
13. ✓ Error in background job displayed in TextBox with red color

---

## Notes & Considerations

- **Single Operation At A Time**: Design prevents queuing - only one operation at a time
- **Staging/Mount Conflict**: Mount and Staging can't be reused until prior operation cleanup completes
- **Log File Size**: Can grow very large for long operations (Make It So generates 1000s of log entries) - consider periodic archival
- **Takeown Performance**: `takeown /R` can be slow on large directory trees - may need progress indication
- **Job Isolation**: Each operation runs in separate PowerShell job - no shared state with UI thread
- **UI Responsiveness**: XAML forms should remain responsive to clicks/tabs but actions/buttons disabled
- **Module Dependencies**: Background jobs inherit module context - ensure OSDSUS/OSDUpdate modules available in job
