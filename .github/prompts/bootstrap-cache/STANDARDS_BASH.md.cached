# AI CODING STANDARDS: BASH (STRICT)

**SCOPE:** Applies to *.sh files and shell automation.

## 1. BASH STANDARDS

### 1.1 The "Safety Net" Header

Every Bash script MUST start with strict mode directives:

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
```

### 1.2 Logic & Syntax

- **Expansion:** Always quote variables (`"${VAR}"`) and use curly braces (`"${FILE_PATH}"`).
- **Conditionals:** Prefer `[[ ... ]]` over `[ ... ]`.
- **Output:** Use `printf` instead of `echo` for portability.

### 1.3 Cleanup

Use `trap` to ensure temporary artifacts are removed on EXIT.
