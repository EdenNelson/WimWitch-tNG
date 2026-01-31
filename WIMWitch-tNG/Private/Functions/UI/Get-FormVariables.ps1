Function Get-FormVariables {
    if ($global:ReadmeDisplay -ne $true) { Write-Host 'If you need to reference this display again, run Get-FormVariables' -ForegroundColor Yellow; $global:ReadmeDisplay = $true }
    #write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    Get-Variable WPF*
}
