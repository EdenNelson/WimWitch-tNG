Function Invoke-OSDCheck {

    Get-OSDBInstallation #Sets OSDUpate version info
    Get-OSDBCurrentVer #Discovers current version of OSDUpdate
    Compare-OSDBuilderVer #determines if an update of OSDUpdate can be applied
    get-osdsusinstallation #Sets OSDSUS version info
    Get-OSDSUSCurrentVer #Discovers current version of OSDSUS
    Compare-OSDSUSVer #determines if an update of OSDSUS can be applied
}
