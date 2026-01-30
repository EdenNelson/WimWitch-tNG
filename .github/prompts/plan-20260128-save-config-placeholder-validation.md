# PLAN: Prevent Saving Config with Placeholder Filename

**Date:** January 28, 2026
**Status:** Pending Approval
**Scope:** Bug fix; non-breaking (prevents data loss)
**Priority:** Medium (user experience issue)

---

## Problem Statement

The save configuration dialog has a TextBox with placeholder helper text: **"Name for saved configuration..."**

**Bug:** If a user clicks "Save" without changing the filename, the config is saved with the literal placeholder text as the filename.

**Impact:**

- User thinks config is saved, but filename is not meaningful
- Multiple users may overwrite the same `Name for saved configuration....psd1` file
- User confusion about what was actually saved
- Accidental data loss if user saves over the placeholder name repeatedly

---

## Current Code

**XAML (line 288 in WIMWitch-tNG.ps1):**

```xml
<TextBox x:Name="SLSaveFileName" Text="Name for saved configuration..." ... />
```

**Event Handler (line 729):**

```powershell
$WPFSLSaveButton.Add_click( { Save-Configuration -filename $WPFSLSaveFileName.text })
```

**Save Function (line 2293 in WWFunctions.ps1):**

- Currently accepts any filename value
- No validation to check if it matches the placeholder text
- Simply saves whatever filename is provided

---

## Analysis & Assessment

### Root Cause

The save button handler passes the TextBox value directly to `Save-Configuration` without validating that:

1. The user actually entered a custom filename
2. The filename isn't the placeholder text

### Why This Happens

- No input validation at the button handler level
- No "clear on focus" behavior for the TextBox placeholder
- No validation check in `Save-Configuration` function

### Options Considered

#### Option A (Preferred): Validate & Reject Placeholder

- Add validation in `Save-Configuration` function
- Check if filename matches placeholder text: `"Name for saved configuration..."`
- If match detected:
  - Log a warning to the user
  - Do NOT save the file
  - Provide feedback to user in log (message shown in GUI log window)
- Clear error handling so user knows what went wrong

#### Option B: Clear on Focus + Placeholder

- Modify TextBox behavior to clear placeholder on user focus
- User must type something (cannot accidentally use placeholder)
- Requires XAML/code-behind changes; more invasive

#### Option C: Auto-generate Filename

- If placeholder detected, auto-generate meaningful filename (e.g., timestamp-based)
- Hides the problem rather than fixing it
- Not user-friendly; user has no control

**Selected:** Option A (validate & reject)

- Simplest
- Explicit feedback to user
- Low risk
- User maintains control

---

## Plan

### STAGE 1: Add Placeholder Validation

**Objective:** Prevent saving with placeholder filename

**Location:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`

**Changes:**

1. Define the placeholder text as a constant at function start: `$placeholderText = "Name for saved configuration..."`
2. Add validation check before any save logic:
   - If `$filename` (after trimming) equals the placeholder text, log warning and return early
   - Do NOT create any files
   - Provide clear error message to user

**Code Pattern:**

```powershell
$placeholderText = "Name for saved configuration..."

if ($filename.Trim() -eq $placeholderText) {
    Update-Log -Data "ERROR: Please provide a custom configuration name. Do not use the placeholder text." -Class Error
    return
}

# Continue with normal save logic
```

**Deliverable:** Modified `Save-Configuration` function with placeholder validation

**Checkpoint:** Validation added before all save paths (both CM and non-CM)

---

### STAGE 2: Validation & Testing

**Objective:** Verify placeholder rejection works

**Tests:**

1. Code review: Validation logic is correct
2. Syntax check: No PowerShell errors
3. Edge cases:
   - Exact placeholder match → rejected ✓
   - Placeholder with leading/trailing spaces → rejected ✓
   - Similar but different name (e.g., "Name for saved config") → allowed ✓
   - Custom name with "saved configuration" as substring → allowed ✓
4. Log output: Warning message appears in log for user

**Checkpoint:** All tests pass, log message is clear and actionable

---

## Consent Gate

**Breaking Change?** No

- Prevents accidental saves that users didn't intend anyway
- Improves user experience by preventing data loss
- No impact on valid use cases

**User Action Required?** Yes, but it's clear:

- If user sees "Please provide a custom configuration name" in log
- User types a real name in the field
- User clicks Save again
- No friction beyond the initial error message

**Approval Requested:** ✓ Proceed with Option A (validate & reject placeholder)

---

## References

- **File:** `WIMWitch-tNG/Private/Functions/UI/Save-Configuration.ps1`
- **Function:** `Save-Configuration`
- **XAML:** `WIMWitch-tNG/Public/WIMWitch-tNG.ps1` (line 288, SLSaveFileName TextBox)
- **Event Handler:** `WIMWitch-tNG/Public/WIMWitch-tNG.ps1` (line 729, SLSaveButton click)
- **Related:** `Update-Log` function (used for user warnings)
- **Standards:** STANDARDS_POWERSHELL.md, PROJECT_CONTEXT.md

---

## Persistence & Recovery

If session crashes during implementation:

1. Read this plan artifact: `.github/prompts/plan-20260128-save-config-placeholder-validation.md`
2. Current stage: Check which checkpoint was completed
3. Resume from next incomplete stage
4. All changes isolated to one function (low complexity)

---

**Prepared by:** Pragmatic Architect
**Awaiting approval to proceed with Stage 1**
