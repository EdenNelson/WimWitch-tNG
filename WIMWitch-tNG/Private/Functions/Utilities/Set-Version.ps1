Function Set-Version($wimversion) {
    # Windows 11 versions (23H2 has build variance like Windows 10 22H2)
    if ($wimversion -like '10.0.2262*.*') {
        $version = '23H2'
        Update-Log -Data "Auto-detected Windows 11 23H2 from build $wimversion. Note: ISO build numbers from Microsoft are inconsistent - some 23H2 releases use build 10.0.22621.* instead of the expected 10.0.22631.*. All 10.0.2262*.* builds will be treated as 23H2." -Class Information
    }
    elseif ($wimversion -like '10.0.26100.*') { $version = '24H2' }
    elseif ($wimversion -like '10.0.26200.*') { $version = '25H2' }

    # Windows 10 - Only 22H2 supported (all 1904*.* builds)
    elseif ($wimversion -like '10.0.1904*.*') {
        $version = '22H2'
        Update-Log -Data "Auto-detected Windows 10 22H2 from build $wimversion. Note: Only Windows 10 22H2 is supported. ISO build numbers are inconsistent, assuming 22H2." -Class Information
    }

    # Unsupported Windows 10 builds
    elseif ($wimversion -like '10.0.16299.*') {
        Update-Log -Data "Unsupported Windows 10 build 1709 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17134.*') {
        Update-Log -Data "Unsupported Windows 10 build 1803 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.17763.*') {
        Update-Log -Data "Unsupported Windows 10 build 1809 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.18362.*') {
        Update-Log -Data "Unsupported Windows 10 build 1909 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.14393.*') {
        Update-Log -Data "Unsupported Windows 10 build 1607 detected: $wimversion. Only Windows 10 22H2 is supported." -Class Error
        $version = 'Unsupported'
    }
    elseif ($wimversion -like '10.0.20348.*') { $version = '21H2' }
    else {
        Update-Log -Data "Unknown Windows version: $wimversion" -Class Warning
        $version = 'Unknown'
    }
    return $version
}
