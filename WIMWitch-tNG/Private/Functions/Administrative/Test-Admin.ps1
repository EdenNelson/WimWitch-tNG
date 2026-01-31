Function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    if ($currentUser.IsInRole($adminRole)) {
        Update-Log -Data 'User has admin privileges' -Class Information
    } else {
        Update-Log -Data 'This script requires administrative privileges. Please run it as an administrator.' -Class Error
        Exit
    }
}
