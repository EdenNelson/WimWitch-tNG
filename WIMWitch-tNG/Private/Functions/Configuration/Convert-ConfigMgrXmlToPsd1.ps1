Function Convert-ConfigMgrXmlToPsd1 {
    [CmdletBinding()]
    param(
        [switch]$RemoveLegacy
    )

    # Check if ConfigMgr configs folder exists
    $ConfigPath = "$global:workdir\configs"
    if (-not (Test-Path -Path $ConfigPath)) {
        Update-Log -Data 'ConfigMgr configs folder not found, skipping XML to PSD1 conversion' -Class Information
        return
    }

    # Look for any legacy XML files in the configs folder
    $LegacyXmlFiles = @(Get-ChildItem -Path $ConfigPath -Filter '*.xml' -ErrorAction SilentlyContinue)

    if ($LegacyXmlFiles.Count -gt 0) {
        Update-Log -Data "Found $($LegacyXmlFiles.Count) legacy ConfigMgr XML file(s) to convert" -Class Information

        foreach ($XmlFile in $LegacyXmlFiles) {
            try {
                # Import the CLIXML file (deserialize to hashtable)
                $ConfigData = Import-Clixml -Path $XmlFile.FullName -ErrorAction Stop

                # Convert hashtable to PSD1 format
                $PSD1FileName = [System.IO.Path]::ChangeExtension($XmlFile.FullName, '.psd1')

                # Build PSD1 content with proper formatting
                $PSD1Lines = @("@{")
                $PSD1Lines += "    # Converted from legacy XML: $($XmlFile.Name)"

                foreach ($key in $ConfigData.Keys | Sort-Object) {
                    $value = $ConfigData[$key]
                    $formattedValue = if ($null -eq $value) {
                        '$null'
                    } elseif ($value -is [bool]) {
                        if ($value) { '$true' } else { '$false' }
                    } elseif ($value -is [int]) {
                        $value
                    } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                        # Handle arrays and collections (including ItemCollection)
                        $items = @($value | ForEach-Object {
                            if ($_ -is [string]) {
                                "'$($_ -replace "'", "''")'"
                            } else {
                                "'$($_.ToString() -replace "'", "''")'"
                            }
                        })
                        if ($items.Count -eq 0) {
                            '@()'
                        } else {
                            "@($($items -join ', '))"
                        }
                    } else {
                        # Handle strings and other simple types
                        "'$($value.ToString() -replace "'", "''")'"
                    }
                    $PSD1Lines += "    $key = $formattedValue"
                }

                $PSD1Lines += "}"
                $PSD1Content = $PSD1Lines -join "`r`n"

                Set-Content -Path $PSD1FileName -Value $PSD1Content -ErrorAction Stop
                Update-Log -Data "Converted $($XmlFile.Name) to PSD1 format" -Class Information

                if ($RemoveLegacy) {
                    Remove-Item -Path $XmlFile.FullName -Force -ErrorAction Stop
                    Update-Log -Data "Removed legacy XML file: $($XmlFile.Name)" -Class Information
                }
            }
            catch {
                Update-Log -Data "Error converting $($XmlFile.Name): $($_.Exception.Message)" -Class Warning
            }
        }
    } else {
        Update-Log -Data 'No legacy ConfigMgr XML files found, skipping conversion' -Class Information
    }
}
