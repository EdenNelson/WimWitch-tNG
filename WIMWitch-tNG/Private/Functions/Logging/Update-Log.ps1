Function Update-Log {
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Data,

        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]$Solution = $Solution,

        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [validateset('Information', 'Warning', 'Error', 'Comment')]
        [string]$Class = 'Information'

    )

    $global:ScriptLogFilePath = $Log
    $LogString = "$(Get-Date) $Class  -  $Data"
    $HostString = "$(Get-Date) $Class  -  $Data"


    # Only write to log file if $Log path is set
    if ($Log) {
        Add-Content -Path $Log -Value $LogString
    }

    switch ($Class) {
        'Information' {
            Write-Host $HostString -ForegroundColor Gray
        }
        'Warning' {
            Write-Host $HostString -ForegroundColor Yellow
        }
        'Error' {
            Write-Host $HostString -ForegroundColor Red
        }
        'Comment' {
            Write-Host $HostString -ForegroundColor Green
        }

        Default { }
    }
    #The below line is for a logging tab that was removed. If it gets put back in, reenable the line
    #  $WPFLoggingTextBox.text = Get-Content -Path $Log -Delimiter "\n"
}
