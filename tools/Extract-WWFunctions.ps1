<#
.SYNOPSIS
    Extracts individual functions from monolithic WWFunctions.ps1 into separate files.

.DESCRIPTION
    Uses PowerShell AST to parse WWFunctions.ps1, identify function boundaries,
    and extract each function (with help blocks) into individual files in staging directory.
    Validates syntax of each extracted file and maintains extraction metadata.

.PARAMETER SourceFile
    Path to the monolithic WWFunctions.ps1 file.

.PARAMETER TargetDir
    Directory where extracted function files will be created.

.PARAMETER StartIndex
    Starting function index for batch extraction (1-based).

.PARAMETER Count
    Number of functions to extract in this batch.

.EXAMPLE
    .\Extract-WWFunctions.ps1 -StartIndex 1 -Count 10
    Extracts functions 1-10 from WWFunctions.ps1

.OUTPUTS
    Creates individual .ps1 files and extraction-manifest.csv
#>
[CmdletBinding()]
param(
    [string]$SourceFile = "$PSScriptRoot/../WIMWitch-tNG/Private/WWFunctions.ps1",
    [string]$TargetDir = "$PSScriptRoot/../WIMWitch-tNG/Private/Functions-Staging",
    [int]$StartIndex = 1,
    [int]$Count = 10
)

$ErrorActionPreference = 'Stop'

Write-Host "=== WWFunctions Extraction Tool ===" -ForegroundColor Cyan
Write-Host "Source: $SourceFile" -ForegroundColor Gray
Write-Host "Target: $TargetDir" -ForegroundColor Gray
Write-Host "Batch: Functions $StartIndex to $($StartIndex + $Count - 1)" -ForegroundColor Gray
Write-Host ""

# Ensure target directory exists
if (-not (Test-Path $TargetDir)) {
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
}

# Parse the source file using AST
Write-Host "[1/5] Parsing source file with AST..." -ForegroundColor Yellow
$sourceContent = [System.IO.File]::ReadAllText($SourceFile)
$ast = [System.Management.Automation.Language.Parser]::ParseInput($sourceContent, [ref]$null, [ref]$null)

# Find all function definitions
$functions = $ast.FindAll({
    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $true) | Sort-Object { $_.Extent.StartLineNumber }

Write-Host "      Found $($functions.Count) functions in source file" -ForegroundColor Green

# Calculate batch range
$endIndex = [Math]::Min($StartIndex + $Count - 1, $functions.Count)
$batchFunctions = $functions[($StartIndex - 1)..($endIndex - 1)]

Write-Host "[2/5] Extracting batch: Functions $StartIndex-$endIndex ($($batchFunctions.Count) functions)" -ForegroundColor Yellow

# Initialize manifest
$manifestPath = Join-Path $TargetDir 'extraction-manifest.csv'
$manifestExists = Test-Path $manifestPath
if (-not $manifestExists) {
    "Index,FunctionName,SourceStartLine,SourceEndLine,TargetFile,SyntaxValid,ExtractedAt" |
        Set-Content -Path $manifestPath -Encoding UTF8
}

# Extract each function
$results = @()
foreach ($func in $batchFunctions) {
    $funcIndex = [array]::IndexOf($functions, $func) + 1
    $funcName = $func.Name
    $startLine = $func.Extent.StartLineNumber
    $endLine = $func.Extent.EndLineNumber

    Write-Host "   [$funcIndex/$($functions.Count)] $funcName (lines $startLine-$endLine)" -ForegroundColor Cyan

    # Extract function text (preserve exact content)
    $lines = $sourceContent -split "`r?`n"
    $functionLines = $lines[($startLine - 1)..($endLine - 1)]

    # Look for comment-based help block immediately before the function
    $helpBlockStart = $null
    for ($i = $startLine - 2; $i -ge 0; $i--) {
        $line = $lines[$i]
        if ($line -match '^\s*<#') {
            $helpBlockStart = $i + 1  # Convert to 1-based
            break
        }
        if ($line -match '\S' -and $line -notmatch '^\s*#>') {
            # Non-comment content found, stop looking
            break
        }
    }

    # Include help block if found
    if ($helpBlockStart) {
        $helpLines = $lines[($helpBlockStart - 1)..($startLine - 2)]
        $functionContent = (@($helpLines) + @($functionLines)) -join "`r`n"
        Write-Host "      + Included help block (lines $helpBlockStart-$($startLine - 1))" -ForegroundColor Gray
    } else {
        $functionContent = $functionLines -join "`r`n"
    }

    # Ensure CRLF line endings and UTF-8 encoding
    $functionContent = $functionContent -replace "`r`n", "`n"  # Normalize to LF
    $functionContent = $functionContent -replace "`n", "`r`n"  # Convert to CRLF

    # Generate target filename
    $targetFile = Join-Path $TargetDir "$funcName.ps1"

    # Write to file with explicit UTF-8 encoding (no BOM)
    [System.IO.File]::WriteAllText($targetFile, $functionContent, [System.Text.UTF8Encoding]::new($false))

    # Validate syntax
    $syntaxValid = $false
    $syntaxErrors = $null
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $targetFile,
            [ref]$null,
            [ref]$syntaxErrors
        )
        if ($syntaxErrors.Count -eq 0) {
            $syntaxValid = $true
            Write-Host "      ✓ Syntax valid" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Syntax errors: $($syntaxErrors.Message -join '; ')" -ForegroundColor Red
        }
    } catch {
        Write-Host "      ✗ Parse failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Record in manifest
    $record = [PSCustomObject]@{
        Index           = $funcIndex
        FunctionName    = $funcName
        SourceStartLine = if ($helpBlockStart) { $helpBlockStart } else { $startLine }
        SourceEndLine   = $endLine
        TargetFile      = Split-Path -Leaf $targetFile
        SyntaxValid     = $syntaxValid
        ExtractedAt     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    $results += $record

    "$($record.Index),$($record.FunctionName),$($record.SourceStartLine),$($record.SourceEndLine),$($record.TargetFile),$($record.SyntaxValid),$($record.ExtractedAt)" |
        Add-Content -Path $manifestPath -Encoding UTF8
}

Write-Host ""
Write-Host "[3/5] Batch extraction complete" -ForegroundColor Yellow
Write-Host "      Extracted: $($results.Count) functions" -ForegroundColor Gray
Write-Host "      Valid syntax: $(($results | Where-Object SyntaxValid).Count)" -ForegroundColor Green
Write-Host "      Syntax errors: $(($results | Where-Object { -not $_.SyntaxValid }).Count)" -ForegroundColor Red

# Summary
Write-Host ""
Write-Host "[4/5] Validation Summary" -ForegroundColor Yellow
if (($results | Where-Object { -not $_.SyntaxValid }).Count -gt 0) {
    Write-Host "      ⚠️  ERRORS DETECTED - Review failed functions:" -ForegroundColor Red
    $results | Where-Object { -not $_.SyntaxValid } | ForEach-Object {
        Write-Host "         - $($_.FunctionName) (Index $($_.Index))" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "      ACTION REQUIRED: Fix syntax errors before proceeding to next batch" -ForegroundColor Yellow
} else {
    Write-Host "      ✓ All functions passed syntax validation" -ForegroundColor Green
}

Write-Host ""
Write-Host "[5/5] Manifest updated: $manifestPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "=== Batch Complete ===" -ForegroundColor Cyan
Write-Host "Next: Review extracted files in $TargetDir" -ForegroundColor Gray
Write-Host ""
