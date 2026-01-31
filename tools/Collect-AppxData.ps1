<#
.SYNOPSIS
    Collects AppX package data from a live Windows installation.

.DESCRIPTION
    This script runs on a live Windows installation to gather comprehensive AppX package data.
    It detects the Windows version, build number, and architecture, then extracts all
    provisioned AppX packages. The raw data is saved as a PSD1 file for later processing
    by an AI agent in VSCode.

.PARAMETER OutputPath
    Directory where the raw data PSD1 file will be saved.
    Default: ./appxData/

.PARAMETER Verbose
    Shows detailed progress during package detection.

.EXAMPLE
    .\Collect-AppxData.ps1 -Verbose
    Collects AppX data with verbose output, saves to ./appxData/

.EXAMPLE
    .\Collect-AppxData.ps1 -OutputPath "C:\AppxBackup\"
    Collects AppX data and saves to specified directory

.NOTES
    Author: Eden Nelson [edennelson]
    Version: 1.0
    Date: 2026-01-19

    This script performs NO filtering or categorization.
    It simply collects raw data for AI processing in VSCode.

    Code Origin:
    Portions of this script were generated with assistance from GitHub Copilot AI.
    The author has reviewed and tested all code.
    This is disclosed in the interest of transparency.
    The author does not make claims regarding potential infringement or plagiarism.

    Requirements:
    - Must run on live Windows installation
    - Requires administrative privileges
    - Windows 10 22H2 or Windows 11 supported

.LINK
    https://github.com/edennelson/WimWitch-tNG
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\appxData\"
)

#Requires -RunAsAdministrator

# Script metadata
$scriptVersion = "1.0"
$scriptName = "Collect-AppxData.ps1"

Write-Output "=================================================="
Write-Output "  WimWitch-tNG: AppX Data Collection"
Write-Output "  Version: $scriptVersion"
Write-Output "=================================================="
Write-Output ""

# Step 1: Detect Windows environment
Write-Verbose -Message "Step 1: Detecting Windows environment..."
try {
    $osInfo = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop

    $buildNumber = $osInfo.CurrentBuild
    $ubr = $osInfo.UBR
    $displayVersion = $osInfo.DisplayVersion
    $productName = $osInfo.ProductName
    $editionID = $osInfo.EditionID
    $architecture = $env:PROCESSOR_ARCHITECTURE

    # Determine Windows version label
    $windowsVersion = if ($productName -match "Windows 10") {
        "Win10-$displayVersion"
    } elseif ($productName -match "Windows 11") {
        "Win11-$displayVersion"
    } else {
        "Windows-Unknown"
    }

    Write-Output "[OK] Windows Version Detected"
    Write-Output "    Product: $productName"
    Write-Output "    Version: $displayVersion (Build $buildNumber.$ubr)"
    Write-Output "    Edition: $editionID"
    Write-Output "    Architecture: $architecture"
    Write-Output ""

} catch {
    Write-Error -Message "Failed to detect Windows version: $_"
    exit 1
}

# Step 2: Extract ALL AppX packages
Write-Verbose -Message "Step 2: Extracting AppX packages from system..."
Write-Output "Querying provisioned packages (this may take 30-60 seconds)..."

try {
    $packages = Get-AppxProvisionedPackage -Online -ErrorAction Stop | Select-Object -Property `
        DisplayName,
        PackageName,
        Version,
        Architecture,
        @{Name='PublisherId';Expression={$_.PublisherId}},
        @{Name='ResourceId';Expression={$_.ResourceId}}

    Write-Output "[OK] Package Extraction Complete"
    Write-Output "    Total packages found: $($packages.Count)"
    Write-Output ""

    if ($packages.Count -lt 100) {
        Write-Error -Message "Package count seems low ($($packages.Count)). Expected 300-450 packages."
        Write-Error -Message "This may indicate an incomplete Windows installation."
        $continue = Read-Host -Prompt "Continue anyway? (Y/N)"
        if ($continue -ne 'Y') {
            Write-Output "Aborted by user."
            exit 1
        }
    }

} catch {
    Write-Error -Message "Failed to extract AppX packages: $_"
    exit 1
}

# Step 3: Build metadata
Write-Verbose -Message "Step 3: Building metadata..."

$metadata = @{
    WindowsVersion = $displayVersion
    ProductName = $productName
    EditionID = $editionID
    BuildNumber = "$buildNumber.$ubr"
    Architecture = $architecture
    CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CollectionDateUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    TotalPackages = $packages.Count
    Collector = "$scriptName v$scriptVersion"
    ComputerName = $env:COMPUTERNAME
}

Write-Output "[OK] Metadata Created"

# Step 4: Prepare output directory
Write-Verbose -Message "Step 4: Preparing output directory..."

if (-not (Test-Path -Path $OutputPath)) {
    try {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Output "[OK] Created output directory: $OutputPath"
    } catch {
        Write-Error -Message "Failed to create output directory: $_"
        exit 1
    }
} else {
    Write-Output "[OK] Output directory exists: $OutputPath"
}

# Step 5: Save raw data (NO FILTERING)
Write-Verbose -Message "Step 5: Saving raw data..."

$outputFileName = "appxData-$windowsVersion-Build$buildNumber-raw.psd1"
$outputFilePath = Join-Path -Path $OutputPath -ChildPath $outputFileName

try {
    $dataObject = @{
        Metadata = $metadata
        Packages = $packages
    }

    # Export as CliXml for easy re-import in PowerShell/VSCode
    $dataObject | Export-Clixml -Path $outputFilePath -Force -ErrorAction Stop

    Write-Output ""
    Write-Output "=================================================="
    Write-Output "  Data Collection Complete!"
    Write-Output "=================================================="
    Write-Output ""
    Write-Output "Output File: $outputFilePath"
    Write-Output "Total Packages: $($packages.Count)"
    Write-Output "File Size: $([math]::Round((Get-Item -Path $outputFilePath).Length / 1KB, 2)) KB"
    Write-Output ""
    Write-Output "NEXT STEPS:"
    Write-Output "1. Copy this file to your development machine:"
    Write-Output "   ~/Documents/GitHub/WimWitch-tNG/tools/appxData/"
    Write-Output ""
    Write-Output "2. Open VSCode with WimWitch-tNG workspace"
    Write-Output ""
    Write-Output "3. Reference the AI prompt in GitHub Copilot Chat:"
    Write-Output "   '@workspace Use #file:.github/prompts/process-appxData.prompt.md"
    Write-Output "   to process tools/appxData/$outputFileName'"
    Write-Output ""

} catch {
    Write-Error -Message "Failed to save raw data: $_"
    exit 1
}

# Optional: Display package summary
if ($VerbosePreference -eq 'Continue') {
    Write-Output ""
    Write-Output "Package Summary (Top Publishers):"
    $packages | Group-Object -Property {($_.PackageName -split '_')[0]} |
        Sort-Object -Property Count -Descending |
        Select-Object -First 10 |
        ForEach-Object -Process {
            Write-Output "  $($_.Name): $($_.Count) packages"
        }
}

Write-Output ""
Write-Output "Data collection successful."
