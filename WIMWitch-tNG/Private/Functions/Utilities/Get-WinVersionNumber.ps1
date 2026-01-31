Function Get-WinVersionNumber {
    $buildnum = $null
    $wimBuild = $WPFSourceWimVerTextBox.text

    # Windows 10 and 11 version detection
    switch -Regex ($wimBuild) {
        # Windows 10 - Only 22H2 supported (all 1904*.* builds)
        '10\.0\.1904\d\.\d+' {
            $buildnum = '22H2'
            Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimBuild. Note: Only Windows 10 22H2 is supported. ISO build numbers from Microsoft are inconsistent across 2004/20H2/21H1/21H2/22H2 releases, so all 10.0.1904*.* builds will be treated as 22H2." -Class Information
        }

        # Windows 11 version checks (23H2 has build variance like Windows 10 22H2)
        '10\.0\.2262\d\.\d+' {
            $buildnum = '23H2'
            Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimBuild. Note: ISO build numbers from Microsoft are inconsistent - some 23H2 releases use build 10.0.22621.* instead of the expected 10.0.22631.*. All 10.0.2262*.* builds will be treated as 23H2." -Class Information
        }
        '10\.0\.26100\.\d+' { $buildnum = '24H2' }
        '10\.0\.26200\.\d+' { $buildnum = '25H2' }

        # Unsupported Windows 10 builds
        '10\.0\.10\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported. Please use an older version of WIMWitch for legacy Windows 10 builds." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.14393\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimBuild. Only Windows 10 22H2 is supported." -Class Error
            $buildnum = 'Unsupported'
        }
        '10\.0\.1[5-8]\d{3}\.\d+' {
            Update-Log -Data "Unsupported Windows 10 build detected: $wimBuild. Only Windows 10 22H2 (build 19045) is supported." -Class Error
            $buildnum = 'Unsupported'
        }

        Default {
            Update-Log -Data "Unknown Windows version: $wimBuild" -Class Warning
            $buildnum = 'Unknown Version'
        }
    }

    return $buildnum
}
