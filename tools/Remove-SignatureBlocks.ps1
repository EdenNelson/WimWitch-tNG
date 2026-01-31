<#
.SYNOPSIS
    Removes Authenticode signature blocks from PowerShell files.

.DESCRIPTION
    Strips digital signature blocks from .ps1, .psm1, and .psd1 files to facilitate
    code analysis and editing. Signature blocks are identified by the standard
    "# SIG # Begin signature block" and "# SIG # End signature block" markers.

    This is a destructive operation - files will need to be re-signed if signatures
    are required. Use -WhatIf to preview changes before execution.

.PARAMETER Path
    Root path to search for PowerShell files. Defaults to parent directory of script.

.PARAMETER Recurse
    Search subdirectories recursively. Default: $true

.PARAMETER Backup
    Create .bak backup files before modifying. Default: $false

.PARAMETER Interactive
    Process one file at a time with confirmation prompt before each file.

.PARAMETER First
    Process only the first N files (useful for testing).

.PARAMETER WhatIf
    Preview what would be changed without making modifications.

.PARAMETER Verbose
    Show detailed processing information.

.EXAMPLE
    .\Remove-SignatureBlocks.ps1
    Removes signatures from all PowerShell files in the project.

.EXAMPLE
    .\Remove-SignatureBlocks.ps1 -First 1 -WhatIf
    Test against a single file in preview mode.

.EXAMPLE
    .\Remove-SignatureBlocks.ps1 -Interactive
    Process files one at a time with confirmation prompts.

.EXAMPLE
    .\Remove-SignatureBlocks.ps1 -Backup -Verbose
    Removes signatures with backup files and detailed logging.

.EXAMPLE
    .\Remove-SignatureBlocks.ps1 -WhatIf
    Preview which files would be modified without making changes.

.NOTES
    Author: WIMWitch-tNG Project
    Purpose: Code maintenance and AI ingestion optimization
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$Path = (Split-Path -Parent $PSScriptRoot),

    [Parameter()]
    [bool]$Recurse = $true,

    [Parameter()]
    [switch]$Backup,

    [Parameter()]
    [switch]$Interactive,

    [Parameter()]
    [int]$First
)

$ErrorActionPreference = 'Stop'

# Statistics tracking
$stats = @{
    FilesScanned       = 0
    FilesWithSignature = 0
    FilesModified      = 0
    LinesRemoved       = 0
    Errors             = 0
}

Write-Host "Starting signature removal process..." -ForegroundColor Cyan
Write-Host "Root Path: $Path" -ForegroundColor Gray
Write-Host ""

# Find all PowerShell files
$findParams = @{
    Path    = $Path
    Include = @('*.ps1', '*.psm1', '*.psd1')
    File    = $true
}
if ($Recurse) {
    $findParams['Recurse'] = $true
}

$files = Get-ChildItem @findParams

# Exclude bin directory (ConfigMgr binaries with malformed signatures)
$files = $files | Where-Object { $_.FullName -notmatch '[\\/]bin[\\/]' }

# Limit to first N files if specified
if ($First -gt 0) {
    $files = $files | Select-Object -First $First
    Write-Host "Limited to first $First file(s)" -ForegroundColor Yellow
}

Write-Verbose "Found $($files.Count) PowerShell files to process"

foreach ($file in $files) {
    $stats.FilesScanned++

    try {
        # Read file content
        $content = Get-Content -Path $file.FullName -Raw

        # Check if signature block exists
        if ($content -notmatch '# SIG # Begin signature block') {
            Write-Verbose "No signature found: $($file.Name)"
            continue
        }

        $stats.FilesWithSignature++

        # Interactive mode: ask before processing
        if ($Interactive) {
            Write-Host "`nFile: " -NoNewline -ForegroundColor Cyan
            Write-Host $file.FullName
            Write-Host "Lines to remove: " -NoNewline

            # Quick count for display
            $tempLines = $content -split "`r?`n"
            $tempStart = -1
            $tempEnd = -1
            for ($i = 0; $i -lt $tempLines.Count; $i++) {
                if ($tempLines[$i] -match '^# SIG # Begin signature block$') { $tempStart = $i }
                if ($tempLines[$i] -match '^# SIG # End signature block$') { $tempEnd = $i; break }
            }
            if ($tempStart -ge 0 -and $tempEnd -ge 0) {
                Write-Host "$(($tempEnd - $tempStart) + 1)" -ForegroundColor Yellow
            }

            $response = Read-Host "Remove signature? [Y]es / [N]o / [A]ll remaining / [Q]uit"

            switch ($response.ToUpper()) {
                'N' {
                    Write-Host "Skipped.`n" -ForegroundColor Gray
                    continue
                }
                'Q' {
                    Write-Host "`nUser cancelled operation." -ForegroundColor Yellow
                    break
                }
                'A' {
                    $Interactive = $false
                    Write-Host "Processing all remaining files...`n" -ForegroundColor Cyan
                }
            }
        }

        # Find signature block boundaries
        $lines = $content -split "`r?`n"
        $sigStartIndex = -1
        $sigEndIndex = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^# SIG # Begin signature block$') {
                $sigStartIndex = $i
            }
            if ($lines[$i] -match '^# SIG # End signature block$') {
                $sigEndIndex = $i
                break
            }
        }

        if ($sigStartIndex -eq -1 -or $sigEndIndex -eq -1) {
            Write-Warning "Malformed signature block in $($file.FullName) - skipping"
            $stats.Errors++
            continue
        }

        # Calculate lines to remove
        $linesToRemove = ($sigEndIndex - $sigStartIndex) + 1

        # Extract content before signature (trim trailing whitespace)
        $cleanLines = $lines[0..($sigStartIndex - 1)]

        # Remove trailing blank lines
        while ($cleanLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($cleanLines[-1])) {
            $cleanLines = $cleanLines[0..($cleanLines.Count - 2)]
        }

        # Reconstruct content
        $newContent = ($cleanLines -join "`n") + "`n"

        # Execute modification
        if ($PSCmdlet.ShouldProcess($file.FullName, "Remove signature block ($linesToRemove lines)")) {
            # Create backup if requested
            if ($Backup) {
                $backupPath = "$($file.FullName).bak"
                Copy-Item -Path $file.FullName -Destination $backupPath -Force
                Write-Verbose "Backup created: $backupPath"
            }

            # Write cleaned content (UTF8 without BOM for cross-platform)
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8NoBom)

            $stats.FilesModified++
            $stats.LinesRemoved += $linesToRemove

            Write-Host "✓ " -ForegroundColor Green -NoNewline
            Write-Host "$($file.Name) " -NoNewline
            Write-Host "(-$linesToRemove lines)" -ForegroundColor Yellow
        }

    } catch {
        Write-Warning "Error processing $($file.FullName): $_"
        $stats.Errors++
    }
}

# Summary report
Write-Host ""
Write-Host "Signature Removal Summary" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "Files Scanned:         $($stats.FilesScanned)"
Write-Host "Files with Signatures: $($stats.FilesWithSignature)"
Write-Host "Files Modified:        $($stats.FilesModified)" -ForegroundColor Green
Write-Host "Total Lines Removed:   $($stats.LinesRemoved)" -ForegroundColor Yellow
if ($stats.Errors -gt 0) {
    Write-Host "Errors Encountered:    $($stats.Errors)" -ForegroundColor Red
}

if ($WhatIfPreference) {
    Write-Host ""
    Write-Host "WhatIf mode - no files were modified" -ForegroundColor Magenta
}
