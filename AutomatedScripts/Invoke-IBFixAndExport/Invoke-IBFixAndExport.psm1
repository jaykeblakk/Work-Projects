#Requires -Modules ImportExcel

<#
.SYNOPSIS
    Processes a list of DNS names using Fix-IBRecord, tests connectivity, 
    and exports the results to a formatted Excel file.

.DESCRIPTION
    Reads DNS names from an input file, uses the Fix-IBRecord function 
    (from Fix-IBRecord.psm1) with the -TestConnectivity switch, and then 
    exports the results (DNSName, IPAddress, PingStatus) to an Excel file.
    The PingStatus column is conditionally formatted with green for SUCCESS 
    and red for FAILURE.

.PARAMETER InputFile
    The path to a text file containing one DNS name (without domain) per line.
    Default: './servers.txt'

.PARAMETER OutputExcelFile
    The path where the Excel results file (.xlsx) will be saved.
    Default: './ib_record_ping_results.xlsx'

.PARAMETER FixIBRecordModulePath
    The path to the Fix-IBRecord.psm1 module file.
    Default: Resolves relative path '../fix-ibrecord/Fix-IBRecord.psm1'

.EXAMPLE
    Invoke-IBRecordFixAndExport -InputFile ./my_servers.txt -OutputExcelFile ./results/connectivity.xlsx

.NOTES
    Requires PowerShell 7 or later recommended (though might work on 5.1 if Fix-IBRecord is compatible).
    Requires the Fix-IBRecord.psm1 module.
    Requires the Posh-IBWAPI module to be installed (dependency of Fix-IBRecord).
    Requires the ImportExcel module to be installed (`Install-Module ImportExcel`).
#>
function Invoke-IBRecordFixAndExport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$InputFile = './servers.txt',

        [Parameter(Mandatory = $false)]
        [string]$OutputExcelFile = './ib_record_ping_results.xlsx',

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$FixIBRecordModulePath = (Resolve-Path (Join-Path $PSScriptRoot '../fix-ibrecord/Fix-IBRecord.psm1'))
    )
    Import-Module ImportExcel
    # --- Script Start ---
    Write-Host "Starting Infoblox record fix, ping test, and Excel export..."

    # Read DNS Names
    Write-Host "Reading DNS names from: $InputFile"
    $dnsNamesToProcess = Get-Content -Path $InputFile

    # --- Process Infoblox Records & Ping ---
    Write-Host "Processing $($dnsNamesToProcess.Count) DNS names..."
    $allResults = [System.Collections.Generic.List[PSObject]]::new()
    foreach ($name in $dnsNamesToProcess) {
        $trimmedName = $name.Trim()
        if (-not ([string]::IsNullOrWhiteSpace($trimmedName))) {
            Write-Host " - Processing: $trimmedName"
            try {
                # Call Fix-IBRecord with connectivity test
                $result = Fix-IBRecord -DNSName $trimmedName -TestConnectivity -ErrorAction Stop -VIServer "vcenterurl.example.com"
                $allResults.Add($result)
            }
            catch {
                Write-Warning "Error processing '$trimmedName': $($_.Exception.Message)"
                # Optionally add a placeholder error object to results
                $allResults.Add([PSCustomObject]@{ 
                    DNSName     = "$trimmedName.example.com" # Assuming domain from Fix-IBRecord
                    IPAddress   = $null
                    Status      = 'Processing Error'
                    PingSuccess = $null
                })
            }
        }
        else {
            Write-Warning "Skipping blank or whitespace line in input file."
        }
    }

    Write-Host "Processing complete. $($allResults.Count) results gathered."

    if ($allResults.Count -eq 0) {
        Write-Host "No results to export. Exiting."
        return
    }

    # --- Prepare Data for Excel ---
    $exportData = $allResults | Select-Object DNSName, IPAddress, @{
        Name = 'PingStatus'
        Expression = {
            switch ($_.PingSuccess) {
                {$null -eq $_} { 'N/A' } # Handle case where ping wasn't run (e.g., A record not found)
                {$true -eq $_}  { 'SUCCESS' }
                {$false -eq $_} { 'FAILURE' }
                default         { 'Unknown' } # Should not happen
            }
        }
    }

    # --- Define Conditional Formatting Rules using ConditionalText ---
    $conditionalTextRules = @(
        @{ # Rule for Success
            Text      = 'SUCCESS' # Text to match
            FontColor = 'Green'   # Style to apply
        },
        @{ # Rule for Failure
            Text      = 'FAILURE'
            FontColor = 'Red'
        }
    )

    # Export Data using ConditionalText
    $exportData | Export-Excel -Path $OutputExcelFile -AutoSize -BoldTopRow -FreezeTopRow -ConditionalText $conditionalTextRules -ErrorAction Stop
    
    Write-Host "Results successfully exported to: $OutputExcelFile"

    Write-Host "Script finished."
}

# Export the function to make it available when the module is imported
Export-ModuleMember -Function Invoke-IBRecordFixAndExport 