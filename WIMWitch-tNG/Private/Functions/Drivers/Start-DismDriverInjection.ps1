# REQUIRES-CRLF: PowerShell 5.1 (GPO/DSC)

Function Start-DismDriverInjection {

    <#

    .SYNOPSIS

    Injects drivers using DISM with the /Recurse flag for better performance.



    .DESCRIPTION

    Uses DISM.exe /Add-Driver with /Recurse to inject all drivers from a folder tree.

    Parses DISM log for errors and reports failed INF files to the user.

    Continues processing on failures (does not halt on error).



    .PARAMETER Folder

    The folder path containing driver INF files to inject.



    .EXAMPLE

    Start-DismDriverInjection -Folder 'C:\Drivers\Chipset'

    #>



    Param(

        [string]$Folder

    )



    # Validate folder path

    $testpath = Test-Path $Folder -PathType Container

    if ($testpath -eq $false) { return }



    if ($testpath -eq $true) {

        # Define DISM log path

        $LogPath = "$global:workdir\logging\DISM-DriverInjection.log"



        Update-Log -Data "Applying drivers from $Folder using DISM /Recurse" -Class Information



        # Build DISM arguments

        $MountPath = $WPFMISMountTextBox.Text

        $dismArgs = @(

            "/Image:`"$MountPath`"",

            "/Add-Driver",

            "/Driver:`"$Folder`"",

            "/Recurse",

            "/LogPath:`"$LogPath`"",

            "/LogLevel:3"

        )



        # Execute DISM command

        & dism.exe $dismArgs | Out-Null



        # Parse DISM log for errors

        if (Test-Path $LogPath) {

            $Errors = @(Select-String -Path $LogPath -Pattern "\[.*\]\s+Error" -ErrorAction SilentlyContinue)



            if ($Errors.Count -gt 0) {

                Update-Log -Data "Driver injection completed with errors from $Folder" -Class Warning



                # Extract failed INF filenames from error messages

                foreach ($ErrorLine in $Errors) {

                    # Pattern: extract filename from error context

                    # Example: "C:\drivers\network.inf" -> "network.inf"

                    if ($ErrorLine -match '([^\\]+\.inf)') {

                        $FailedInf = $matches[1]

                        Update-Log -Data "Failed: $FailedInf" -Class Warning

                    }

                }

            } else {

                Update-Log -Data "All drivers from $Folder injected successfully" -Class Information

            }

        }



        Update-Log -Data "Completed DISM driver injection from $Folder" -Class Information

    }

}
