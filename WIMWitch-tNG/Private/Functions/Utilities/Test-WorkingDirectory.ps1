Function Test-WorkingDirectory {

    $subfolders = @(
        'CompletedWIMs'
        'Configs'
        'drivers'
        'jobs'
        'logging'
        'Mount'
        'Staging'
        'updates'
        'imports'
        'imports\WIM'
        'imports\DotNet'
        'Autopilot'
        'backup'
    )

    $count = $null
    Set-Location -Path $global:workdir
    Write-Output "WIMWitch-tNG working directory selected: $global:workdir"
    Write-Output 'Checking working directory for required folders...'
    foreach ($subfolder in $subfolders) {
        if ((Test-Path -Path .\$subfolder) -eq $true) { $count = $count + 1 }
    }

    if ($null -eq $count) {
        Write-Output 'Creating missing folders...'
        foreach ($subfolder in $subfolders) {
            if ((Test-Path -Path "$subfolder") -eq $false) {
                New-Item -Path $subfolder -ItemType Directory | Out-Null
                Write-Output "Created folder: $subfolder"
            }
        }
    }
    if ($null -ne $count) {
        Write-Output 'Creating missing folders...'
        foreach ($subfolder in $subfolders) {
            if ((Test-Path -Path "$subfolder") -eq $false) {
                New-Item -Path $subfolder -ItemType Directory | Out-Null
                Write-Output "Created folder: $subfolder"
            }
        }
        Write-Output 'Preflight complete. Starting WIM Witch'
    }

}
