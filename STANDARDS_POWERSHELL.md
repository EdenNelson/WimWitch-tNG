# AI Coding Standards

Authoritative rules for AI-generated changes in this repository. Apply these instructions as primary constraints for all automation, code generation, and edits.

## Scope

- Applies to PowerShell scripts/modules (\*.ps1, \*.psm1, \*.psd1) and related Markdown guidance produced by AI.
- Inherit and respect existing project standards documented in PROJECT_CONTEXT.md and Powershell.instructions.md.

## General Principles

- Prefer correctness, clarity, and idempotence over brevity.
- Keep outputs concise; avoid re-quoting large prior sections—link or summarize instead.
- Do not modify digital signature blocks.

## File Encoding and Line Endings (CRITICAL — macOS/Linux → Windows Compatibility)

**MANDATORY:** All PowerShell files (\*.ps1, \*.psm1, \*.psd1) **MUST** be Windows-compatible when created or modified on macOS/Linux systems.

### Core Requirements

- **Line Endings:** Use CRLF (`\r\n`, Windows-style), NOT LF (`\n`, Unix-style).
- **Encoding:** UTF-8 without BOM (Byte Order Mark) is preferred; UTF-8 with BOM is acceptable.
- **Path Separators:** Must use backslash (`\`) for hardcoded Windows paths; avoid forward slash (`/`) in hardcoded paths. (Use `Join-Path` instead; see "Path Construction Details".)
- **File Permissions:** Ensure no executable bit (`+x`) is set on `.ps1` files (not applicable to Windows execution, but prevents confusion).
- **EOL and BOM Detection:** In VS Code, verify the status bar (bottom right) shows `CRLF` and `UTF-8` (not `UTF-8 with BOM` unless required).

### Rationale

PowerShell scripts execute on Windows servers and require **strict Windows file format** for proper execution in automated orchestration (DSC, Desired State Configuration; Group Policy startup/shutdown scripts; CI/CD pipelines; remote PowerShell execution via WinRM).

### Enforcement for AI Agents

**If you are an AI agent running on macOS or Linux:**

1. **After generating or modifying a PowerShell file**, explicitly convert line endings to CRLF before finalizing the response or saving the file.
2. **Do not assume** the consumer's system will auto-convert. You are responsible.
3. **If you attempt to detect or fix issues** (e.g., running `dos2unix`, `unix2dos`, or similar commands):
   - **Check your current operating system first** using `$PSVersionTable.Platform` or equivalent platform-detection in your script.
   - **If running on Windows:** Stop immediately. The governance rule should have already been applied by the macOS/Linux agent that created the file. Do not re-process.
   - **If running on macOS/Linux:** Proceed with conversion using platform-appropriate tools.

**If you are an AI agent running on Windows:**

- You must still conform to CRLF and UTF-8 encoding, but the file system will typically enforce this automatically.
- Do not run Unix-style line-ending conversion tools. If the file already has CRLF, leave it as-is.
- If you encounter a PowerShell file with LF line endings on a Windows system, this indicates the file was created by a non-compliant macOS/Linux agent and should be rejected or escalated for re-generation on the correct platform.

### Detection in VS Code

- Status bar (bottom right) shows `CRLF` for line endings and `UTF-8` for encoding.
- If it shows `LF`, click on the status bar and select "CRLF" to convert.
- Save the file after conversion.

## Logging and Messaging

- **Primary Logging:** Use `Write-Verbose` for all diagnostic, status, and debugging messages. This allows logging to be toggled on/off via `-Verbose`.
- **Custom Logging:** If a wrapper function like `Write-Log` is present in the context, prefer it over native cmdlets for standardized logging.
- **Interactive Output:** Use `Write-Host` only if the script is explicitly designed for interactive use (user watching the screen). Avoid it entirely in automation/headless scripts.
- **Pipeline Data:** Reserve `Write-Output` exclusively for returning actual data objects to the pipeline. Never use it for status messages (e.g., "Starting process...").
- **Information Stream:** Avoid `Write-Information` unless specifically targeting the information stream for an advanced harness; prefer `Write-Verbose` for general visibility.

## Cmdlet and Parameter Usage

- Use full cmdlet names and explicit parameter names (no aliases, no positional use); avoid positional parameters and prefer explicit forms such as -Path, -Property, -FilterScript, and -Process.
- Include [CmdletBinding()] and typed parameters for functions; use approved verbs (Get/Set/New/Remove/Test/Invoke/Update/Install/Import/Select/Deploy).
- Build paths with Join-Path; avoid string concatenation for paths.
- When processing collections, prefer `foreach` loops for performance with high-volume data; use `ForEach-Object` when streaming through pipelines to save memory or preserve pipeline semantics.

### Parameter Usage Examples

- Bad: `Get-Content $file`; Good: `Get-Content -Path $file`
- Bad: `gci $path`; Good: `Get-ChildItem -Path $path`
- Bad: `Select-Object Name, Size`; Good: `Select-Object -Property Name, Size`
- Bad: `Where-Object { $_.Count -gt 5 }`; Good: `Where-Object -FilterScript { $_.Count -gt 5 }`
- Bad: `ForEach-Object { Write-Output $_ }`; Good: `ForEach-Object -Process { Write-Information -Message $_ }`

### Path Construction Details

- Always use `Join-Path` for building file paths; never use string concatenation (`"$dir\$file"` or `"$dir/$file"`).
- Use `-ChildPath` explicitly: `Join-Path -Path $base -ChildPath "subfolder\file.ps1"`
- Use `Join-Path` in command parameters: `Get-ChildItem -Path (Join-Path -Path $dir -ChildPath $childdir) -Filter "*.ps1"`
- Reason: `Join-Path` handles path separators correctly across platforms (Windows `\`, Unix `/`) and prevents cross-platform failures.

### Function Parameters

- Always declare parameter types: Bad: `param($Name)`; Good: `param([string]$Name)`
- Always use `[CmdletBinding()]` for advanced functions.
- Always use full parameter declarations with `[Parameter()]` attributes:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\default\"
)
```

- Use `[Parameter(Mandatory = $false)]` explicitly for optional parameters.
- Use `[Parameter(Mandatory = $true)]` for required parameters.

### Loop Constructs

- Prefer `foreach` for high-volume data and performance-sensitive loops: Good: `foreach ($item in $items) { Do-Something -Item $item }`
- Use `ForEach-Object` when streaming in pipelines to save memory or preserve pipeline semantics: Good: `$items | ForEach-Object -Process { Do-Something -Item $_ }`
- Always use `-Process` with `ForEach-Object`: Bad: `ForEach-Object { ... }`; Good: `ForEach-Object -Process { ... }`
- Always use `-FilterScript` with `Where-Object`: Bad: `Where-Object { ... }`; Good: `Where-Object -FilterScript { ... }`

## Error Handling

- Use `-ErrorAction Stop` where failures should halt execution.
- Use `try/catch` with `throw` for fatal initialization errors or critical dependencies (Script Terminating).
- Inside `process` blocks or loops, catch errors and use `Write-Error` to record failures without crashing the entire batch (Non-Terminating), unless data integrity is compromised.
- Always use `[CmdletBinding()]` with `-ErrorAction Stop`:

```powershell
[CmdletBinding()]
param()

try {
    $result = Get-Item -Path $path -ErrorAction Stop
} catch {
  Write-Error -Message "Failed: $_"
  throw
}
```

- Always catch exceptions explicitly: Bad: `try { ... } catch { ... }`; Good: `try { ... } catch { Write-Error -Message "..."; throw }`

## Comment-Based Help

- Provide SYNOPSIS, DESCRIPTION, PARAMETER entries (one per parameter), EXAMPLEs, NOTES (author and AI disclosure), OUTPUTS, and LINK when applicable.

## Naming and Style

- Verb-Noun for functions; camelCase for locals; PascalCase for config keys and script filenames.
- Use 4 spaces for indentation (Standard PSScriptAnalyzer compliance).
- Organize with #region / #endregion when it improves readability.
- Region-based structure: in linear scripts (without formal begin/process/end blocks), explicitly demarcate phases with #region Begin (or Setup), #region Process (or Logic/Main), and #region End (or Cleanup) to preserve architectural parity with advanced functions; nesting regions is allowed when it improves clarity.

## Script Structure Decision Tree

- **Default:** Use a linear script structure for sequential, single-pass automation tasks.
- **Trigger - Refactor to Functions:** You **must** refactor linear code into named functions (with `[CmdletBinding()]`) if *any* of the following conditions are met:
  1. **Repetition:** Any logic block is repeated more than once (DRY Principle).
  2. **Complexity:** The script exceeds ~25 lines of logical processing (excluding help/params).
  3. **Scope Isolation:** Variables are being overwritten or "leaked" between unrelated steps.
  4. **Testability:** The user requests Unit Tests (Pester), which require functional units.
- **Pattern for Refactoring:**
  - **Internal Helper:** If the reuse is local only, define a `function Get-LocalHelper { ... }` at the top of the script and call it in the main body.
  - **Controller Script:** If the entire script is complex, wrap the core logic in a `Main` function or distinct functions (e.g., `Get-Data`, `Process-Data`) and invoke them at the bottom.
  - Escalate to begin/process/end blocks if any trigger is true:
  - Resource lifecycle: persistent connections (SQL, HTTP, TCP) or temp files needing explicit cleanup.
  - Heavy initialization: load static data once to avoid per-item reloads.
  - Aggregation: batch-level counters or summary reporting (for example, total errors).
  - Complexity: core logic exceeds ~20 lines or has distinct phases (Validation → Execution → Reporting).
- Block responsibilities when used:
  - begin: initialize connections, load static data, define batch variables (for example, $Total = 0).
  - process: execute core logic for the current item.
  - end: close connections, dispose resources, emit final summaries.

## External Executables

- Prefer `Start-Process` with `-ArgumentList` (passed as an array) over the call operator `&`.
- Construct `System.Diagnostics.ProcessStartInfo` objects when advanced stream redirection is required.

## Dynamic Names

- Derive names at runtime when possible (for example, use $MyInvocation.MyCommand.Name instead of hard-coded script names in messages).

## AI Context Management

- Keep outputs concise and within the effective context window; avoid restating large prior sections—link or summarize instead.
- Do not overflow the available context window; summarize or reference prior material instead of re-quoting it.

## Enforcement

- If these rules cannot be satisfied due to missing context, pause and request the needed details before proceeding.
- These rules supersede default style or training-data conventions for generated content in this project.
