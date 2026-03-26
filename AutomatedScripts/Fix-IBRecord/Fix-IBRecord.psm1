#Requires -Modules Posh-IBWAPI, VMware.VimAutomation.Core, ImportExcel

function Fix-IBRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFilePath, # Changed from DNSName

        # VIServer connection is now handled inside based on previous edits

        [Parameter(Mandatory = $false)]
        [switch]$TestConnectivity,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "C:\Temp\PingResults.xlsx" # Added default value
    )

    # --- Prerequisite Checks ---
    if ($PSBoundParameters.ContainsKey('OutputPath') -and (-not (Get-Module -Name ImportExcel -ListAvailable))) {
        Write-Error "Module ImportExcel is required for exporting results but not found. Please install it (`Install-Module ImportExcel`)."
        return
    }
    if (-not (Get-Module -Name VMware.VimAutomation.Core -ListAvailable)) {
        Write-Error "Module VMware.VimAutomation.Core is required but not found. Please install VMware.PowerCLI."
        return
    }
    if (-not (Test-Path -Path $InputFilePath -PathType Leaf)) {
        Write-Error "Input file not found: $InputFilePath"
        return
    }

    # --- Read Input File --- 
    try {
        $DnsNames = Get-Content -Path $InputFilePath -ErrorAction Stop | Where-Object { $_ -ne '' } # Read non-empty lines
    } catch {
        Write-Error "Failed to read input file '$InputFilePath'. Error: $($_.Exception.Message)"
        return
    }

    if ($DnsNames.Count -eq 0) {
        Write-Warning "Input file '$InputFilePath' is empty or contains only empty lines."
        return
    }

    # --- Establish vCenter Connection (Once) ---
    $VIServer = "vcenterurl.example.com" # Using hardcoded server from previous edit
    Write-Host "Connecting to vCenter server '$VIServer'..."
    $vCenterConnection = $null
    try {
        $vCenterConnection = Connect-VIServer -Server $VIServer -ErrorAction Stop
    } catch {
        Write-Error "Failed to connect to vCenter '$VIServer'. Cannot proceed. Error: $($_.Exception.Message)"
        return
    }

    # --- Batch Processing --- 
    $BatchSize = 10
    $TotalNames = $DnsNames.Count
    $ProcessedCount = 0

    try {
        for ($i = 0; $i -lt $TotalNames; $i += $BatchSize) {
            $CurrentBatch = $DnsNames[$i..([math]::Min($i + $BatchSize - 1, $TotalNames - 1))]
            $BatchStartIndex = $i + 1
            $BatchEndIndex = $i + $CurrentBatch.Count

            Write-Host "`nProcessing batch $($BatchStartIndex)-$($BatchEndIndex) of $TotalNames..." -ForegroundColor Cyan

            # --- Process Each Name in the Batch --- 
            foreach ($SingleDnsName in $CurrentBatch) {
                $ProcessedCount++
                Write-Host "`n--- Processing name $ProcessedCount/${TotalNames}: '$SingleDnsName' ---"

                # --- Core Logic (Adapted for one name) ---
                $Hostname = $SingleDnsName 
                $FQDN = "$SingleDnsName" + ".example.com"

                $resultObject = [PSCustomObject]@{ 
                    DNSName     = $FQDN
                    IPAddress   = $null
                    Status      = $null
                    PingSuccess = $null 
                    VMExists    = $null 
                }

                # Use original casing for most operations, but lowercase for Infoblox search
                $SearchFQDN = $FQDN.ToLowerInvariant() # Use ToLowerInvariant for culture-neutral comparison
                Write-Host "Searching for A record (case-insensitive using: $SearchFQDN)"
                $aRecord = Get-IBObject -ObjectType "record:a" -Filters @("name=$SearchFQDN") -ErrorAction SilentlyContinue

                if ($aRecord) {
                    $resultObject.IPAddress = $aRecord.ipv4addr
                    Write-Host "Found A record for $FQDN with IP: $($resultObject.IPAddress)"
                    
                    Write-Host "Checking for VM '$Hostname' in vCenter '$VIServer'..."
                    try {
                        # Use the established connection object if available
                        $vm = Get-VM -Name $Hostname -Server $vCenterConnection -ErrorAction Stop 
                        if ($vm) {
                            Write-Host "VM '$Hostname' found in vCenter."
                            $resultObject.VMExists = $true
                            
                            Write-Host "Checking for existing host record: $FQDN"
                            $hostRecord = Get-IBObject -ObjectType "record:host" -Filters @("name=$SearchFQDN") -ErrorAction SilentlyContinue
                            if ($hostRecord) {
                                Write-Host "Host record already exists for $FQDN"
                                $resultObject.Status = 'Host Record Existed'
                            }
                            else {
                                Write-Host "Creating host record for $FQDN with IP: $($resultObject.IPAddress)"
                                try {
                                    $newHostRecord = @{
                                        name = $FQDN
                                        ipv4addrs = @(
                                            @{
                                                ipv4addr = $resultObject.IPAddress
                                            }
                                        )
                                    }
                                    $newHost = New-IBObject -ObjectType "record:host" -IBObject $newHostRecord -ErrorAction Stop
                                    Write-Host "Successfully created host record for $FQDN"
                                    $resultObject.Status = 'Host Record Created'
                                    # A record removal logic is already removed
                                } catch {
                                    Write-Error "Failed to create host record for $FQDN. Error: $($_.Exception.Message)"
                                    $resultObject.Status = 'Host Record Creation Failed'
                                }
                            }
                        } else {
                             # Should not happen with ErrorAction Stop unless Get-VM behaves unexpectedly
                             Write-Host "VM '$Hostname' check completed but VM not returned (unexpected with -ErrorAction Stop). Treating as not found."
                             $resultObject.VMExists = $false
                             $resultObject.Status = 'A Record Found, No VM in vCenter'
                        }
                    }
                    catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException] {
                         Write-Error "Lost connection to vCenter '$VIServer' during VM check. Error: $($_.Exception.Message)"
                         $resultObject.Status = 'vCenter Connection Error During Check'
                         # Consider stopping the entire script here? For now, just mark the record.
                    } 
                    catch {
                        # Handle Get-VM errors, specifically VM Not Found if ErrorAction Stop is used
                         if ($_.CategoryInfo.Reason -eq 'VMNotFoundException' -or $_.Exception.Message -like '*Could not find VM*') {
                             Write-Warning "VM '$Hostname' NOT found in vCenter '$VIServer'. Leaving A record only."
                             $resultObject.VMExists = $false
                             $resultObject.Status = 'A Record Found, No VM in vCenter'
                         } else {
                             Write-Warning "An error occurred checking for VM '$Hostname' in vCenter '$VIServer'. Leaving A record only. Error: $($_.Exception.Message)" 
                             $resultObject.VMExists = $false # Or $null to indicate uncertainty
                             $resultObject.Status = 'A Record Found, vCenter VM Check Error'
                         }
                    }

                    # --- Perform ping test (if requested and applicable) ---
                    if ($TestConnectivity.IsPresent -and $resultObject.IPAddress) {
                        Write-Host "Testing connectivity to $($FQDN)..."
                        # Using Test-Connection for boolean result
                        $pingSuccess = Test-Connection -ComputerName $FQDN -Count 1 -Quiet -ErrorAction SilentlyContinue
                        $resultObject.PingSuccess = $pingSuccess
                        if ($pingSuccess) {
                            Write-Host "Ping successful."
                        } else {
                            Write-Host "Ping failed."
                        }
                    }

                } else { # if ($aRecord)
                    Write-Host "No A record found for DNS name: $FQDN"
                    $resultObject.Status = 'A Record Not Found'
                }

                # --- Log to Excel if OutputPath is specified (Consolidated position) ---
                if ($PSBoundParameters.ContainsKey('OutputPath')) {
                    try {
                        $exportData = [PSCustomObject]@{
                            Timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                            DNSName     = $resultObject.DNSName
                            IPAddress   = $resultObject.IPAddress
                            Status      = $resultObject.Status
                            VMExists    = $resultObject.VMExists
                            PingSuccess = $resultObject.PingSuccess # This will be $null if ping/A record didn't happen
                        }
                        # Create conditional formatting rules (needs ImportExcel module)
                        $successRule = New-ConditionalText -Text 'TRUE' -BackgroundColor LightGreen
                        $failureRule = New-ConditionalText -Text 'FALSE' -BackgroundColor LightCoral 
                        $conditionalTextRules = @($successRule, $failureRule)

                        Write-Host "Exporting result for $FQDN to $OutputPath..."
                        Export-Excel -Path $OutputPath -WorksheetName 'PingResults' -Append -InputObject $exportData -AutoSize -ConditionalText $conditionalTextRules -ErrorAction Stop
                        Write-Host "Successfully exported result."
                    } catch {
                        Write-Warning "Failed to export result for $FQDN to Excel file '$OutputPath'. Error: $($_.Exception.Message)"
                    }
                }

                # --- Output Result for Current Name --- 
                Write-Output $resultObject

            } # End foreach ($SingleDnsName in $CurrentBatch)

            # --- Pause Logic ---
            if ($ProcessedCount -lt $TotalNames) {
                $RemainingCount = $TotalNames - $ProcessedCount
                $NextBatchSize = [math]::Min($BatchSize, $RemainingCount)
            } else {
                Write-Host "`nAll $TotalNames names processed." -ForegroundColor Green
            }

        } # End for loop ($i)
    } finally {
        # --- Disconnect vCenter --- 
        if ($vCenterConnection) {
             Write-Host "`nDisconnecting from vCenter server '$VIServer'..."
             Disconnect-VIServer -Server $vCenterConnection -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Script finished." 
}