# Plan: Remove Invoke-DadJoke Function (Dead Code)

**Date:** 2026-01-30
**Type:** Code Cleanup
**Priority:** Low
**Status:** Draft - Awaiting Approval

---

## 1. PROBLEM STATEMENT

### Primary Issue

The `Invoke-DadJoke` function exists in the codebase but is **never called** anywhere. It's dead code that adds unnecessary complexity and an external API dependency.

### Evidence

**Function Location:**

- `WIMWitch-tNG/Private/Functions/Administrative/Invoke-DadJoke.ps1`

**Function Code:**

```powershell
Function Invoke-DadJoke {
    $header = @{accept = 'Application/json' }
    $joke = Invoke-RestMethod -Uri 'https://icanhazdadjoke.com' -Method Get -Headers $header
    return $joke.joke
}
```

**Usage Analysis:**

- Grep search across all `.ps1` files: **0 calls** to `Invoke-DadJoke`
- Function is defined but never invoked
- No UI elements reference it
- No event handlers call it
- Listed in documentation as "Easter egg" but not actually wired up

### Impact

- **Code Bloat:** Unnecessary function adds to maintenance burden
- **External Dependency:** Requires internet access to icanhazdadjoke.com API (unused)
- **Confusion:** Developers may wonder if/how it's used
- **Documentation Debt:** Listed in README-Functions.md as active feature

---

## 2. ROOT CAUSE ANALYSIS

The function was likely created as a fun Easter egg or testing utility but was never integrated into the application. After modularization, it survived as an orphaned function.

---

## 3. SOLUTION DESIGN

### Strategy: Complete Removal

**Principle:** Remove dead code to reduce complexity and maintenance burden.

### Files to Modify

1. **Delete Function File:**
   - `WIMWitch-tNG/Private/Functions/Administrative/Invoke-DadJoke.ps1` → DELETE

2. **Update Documentation:**
   - `WIMWitch-tNG/Private/README-Functions.md` → Remove entry from Administrative functions table

---

## 4. IMPLEMENTATION PLAN

### Stage 1: Remove Function File

**Action:**

```bash
rm WIMWitch-tNG/Private/Functions/Administrative/Invoke-DadJoke.ps1
```

**Verification:**

- Confirm file deleted
- No git history needed (file can be restored from git if ever needed)

### Stage 2: Update Documentation

**File:** `WIMWitch-tNG/Private/README-Functions.md`

**Change:** Remove this line from the Administrative Functions table:

```markdown
| `Invoke-DadJoke` | Display humorous messages (Easter egg) |
```

### Stage 3: Verification

**Tests:**

1. Verify module still loads without errors:

   ```powershell
   Import-Module ./WIMWitch-tNG/WIMWitch-tNG.psd1 -Force -Verbose
   ```

2. Confirm no references to `Invoke-DadJoke` remain:

   ```bash
   grep -r "Invoke-DadJoke" WIMWitch-tNG/
   grep -r "DadJoke" WIMWitch-tNG/ --exclude="*.deprecated*"
   ```

3. Run basic smoke test to ensure nothing broke

---

## 5. ROLLBACK PLAN

If removal causes unexpected issues (highly unlikely given no usage):

```bash
git checkout WIMWitch-tNG/Private/Functions/Administrative/Invoke-DadJoke.ps1
git checkout WIMWitch-tNG/Private/README-Functions.md
```

---

## 6. ESTIMATED EFFORT

- **Complexity:** Trivial
- **Time:** 5 minutes
- **Risk:** Negligible (dead code removal)
- **Testing:** 10 minutes

**Total:** 15 minutes

---

## 7. BENEFITS

- ✅ Reduces code complexity
- ✅ Removes unused external API dependency
- ✅ Cleans up documentation
- ✅ No behavioral change (function was never called)
- ✅ Easier codebase navigation

---

## 8. ACCEPTANCE CRITERIA

- [ ] `Invoke-DadJoke.ps1` file deleted
- [ ] README-Functions.md updated (entry removed)
- [ ] Module imports successfully
- [ ] No references to `Invoke-DadJoke` remain in active codebase
- [ ] No errors during smoke test

---

## APPROVAL REQUESTED

**Recommendation:** Approve for immediate implementation.

**Rationale:** Simple dead code removal with zero risk. Function is unused and adds no value.
