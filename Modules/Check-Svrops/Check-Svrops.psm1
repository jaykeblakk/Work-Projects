<#
.SYNOPSIS
    Automated storage alert resolution script for vROPs

.DESCRIPTION
    This script automatically processes storage alerts from vROPs, expands disks to 250GB,
    removes recovery partitions, and sends email reports.

.PREREQUISITES
    Before running this script, you must create credential files:
    
    1. Create vROPs credentials file:
       Get-Credential "@example.com" | Export-Clixml -Path "C:\Scripts\vropscreds.xml"
    
    2. Create server credentials file:
       Get-Credential | Export-Clixml -Path "C:\Scripts\creds.xml"
    
    Both files must be created before running the script.

.NOTES
    Author: System Administration Team
    Last Updated: $(Get-Date -Format 'yyyy-MM-dd')
#>

function Check-Svrops()
{
    ################################################
    # AUTHENTICATION
    ################################################
    # Credentials are loaded from files for automation
    ################################################
    $vROPsServer = "vropsurl.example.com"
    $logFile = "C:\Scripts\Logs\Check-SvropsLog.txt"
    # Load vROPs credentials from file
    $vROPsCredPath = "C:\Scripts\vropscreds.xml"
    if (Test-Path $vROPsCredPath) {
        $vROPsCredentials = Import-Clixml $vROPsCredPath
        $vROPSUser = $vROPsCredentials.UserName
        $vROPsPassword = $vROPsCredentials.GetNetworkCredential().password
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] vROPs credentials loaded from file" | Out-File -FilePath $logFile -Append
    } else {
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] ERROR: vROPs credentials file not found at $vROPsCredPath" | Out-File -FilePath $logFile -Append
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Please create the credentials file using: Get-Credential | Export-Clixml -Path '$vROPsCredPath'" | Out-File -FilePath $logFile -Append
        return
    }
    ################################################
    # Nothing to configure below this line 
    ################################################
    
    # Setup logging
    $logFile = "C:\Scripts\Logs\Check-SvropsLog.txt"
    
    # Initialize log file (overwrite existing)
    "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Starting Check-Svrops script" | Out-File -FilePath $logFile
    
    # Adding certificate exception to prevent API errors
    ################################################
    # Bypass SSL certificate validation for vROPs API
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    
    # Skip certificate validation (suppress errors)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core/7+
        $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] = $true
        $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck'] = $true
    } else {
        # Windows PowerShell 5.1 and earlier
        add-type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : System.Net.ICertificatePolicy {
                public bool CheckValidationResult(
                    System.Net.ServicePoint srvPoint, System.Security.Cryptography.X509Certificates.X509Certificate certificate,
                    System.Net.WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    ################################################
    # Building vROPS API string & invoking REST API
    ################################################
    $BaseURL = "https://" + $vROPsServer + "/suite-api/api/"
    $BaseAuthURL = "https://" + $vROPsServer + "/suite-api/api/auth/token/acquire"
    $Type = "application/json"
    # Creating JSON for Auth Body
    $AuthJSON =
    "{
    ""username"": ""$vROPSUser"",
    ""password"": ""$vROPsPassword""
    }"
    # Authenticating with API
    Try 
    {
        $vROPSSessionResponse = Invoke-RestMethod -Method POST -Uri $BaseAuthURL -Body $AuthJSON -ContentType $Type
    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }
    # Extracting the session ID from the response
    $vROPSSessionHeader = @{"Authorization"="vRealizeOpsToken "+$vROPSSessionResponse.'auth-token'.token
    "Accept"="application/json"}
    ###############################################
    # SCRIPT
    ###############################################
    # Getting Resources 
    ###############################################
    $ResourcesURL = $BaseURL+"resources?pageSize=5000"
    Try 
    {
        $ResourcesJSON = Invoke-RestMethod -Method GET -Uri $ResourcesURL -Headers $vROPSSessionHeader -ContentType $Type
        $Resources = $ResourcesJSON.resourcelist
    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }
    # Building table of resources for lookup
    $ResourceList = @()
    ForEach($Resource in $Resources)
    {
        # Setting values
        $ResourceHealth = $Resource.resourceHealth
        $ResourceHealthValue = $Resource.resourceHealthValue
        $ResourceID = $Resource.identifier
        $ResourceName = $Resource.resourcekey.name
        $ResourceType = $Resource.resourcekey.resourceKindKey
        # Adding to table
        if ($resourcename -like "10.*")
        {continue}
        $ResourceListRow = new-object PSObject
        $ResourceListRow | Add-Member -MemberType NoteProperty -Name "Name" -Value "$ResourceName"
        $ResourceListRow | Add-Member -MemberType NoteProperty -Name "Type" -Value "$ResourceType"
        $ResourceListRow | Add-Member -MemberType NoteProperty -Name "Health" -Value "$ResourceHealth"
        $ResourceListRow | Add-Member -MemberType NoteProperty -Name "HealthValue" -Value "$ResourceHealthValue"
        $ResourceListRow | Add-Member -MemberType NoteProperty -Name "ID" -Value "$ResourceID"
        $ResourceList += $ResourceListRow
    }
    ###############################################
    # Getting Current Alerts
    ###############################################
    $AlertsURL = $BaseURL+"alerts?pageSize=5000"
    Try 
    {
        $AlertsJSON = Invoke-RestMethod -Method GET -Uri $AlertsURL -Headers $vROPSSessionHeader -ContentType $Type
        $Alerts = $AlertsJSON.alerts
    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }
    $ActiveAlerts = $Alerts | Where-Object {$_.status -eq "Active"}
    $ActiveAlertsCount = $ActiveAlerts.count
    # Output of result
    "ActiveAlerts:$ActiveAlertsCount"
    ###############################################
    # Building list of alerts with resource name rather than just ID
    ###############################################
    $AlertList = @()
    ForEach($ActiveAlert in $ActiveAlerts)
    {
        # Setting values
        $AlertName = $ActiveAlert.alertDefinitionId
        $AlertDescription = $ActiveAlert.alertDefinitionName
        $AlertResourceID = $ActiveAlert.resourceId
        $AlertLevel = $ActiveAlert.alertLevel
        $AlertImpact = $ActiveAlert.alertImpact
        # Converting date times from Epoch to readable format
        $AlertStartTimeUTC = $ActiveAlert.startTimeUTC
        $AlertUpdateTimeUTC = $ActiveAlert.updateTimeUTC
        $AlertStartTime = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($AlertStartTimeUTC))
        $AlertUpdateTime = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliSeconds($AlertStartTimeUTC))
        # Getting name and type of resource impacted
        $AlertResourceName = $ResourceList | Where-Object {$_.ID -eq $AlertResourceID} | Select -ExpandProperty Name
        $AlertResourceType = $ResourceList | Where-Object {$_.ID -eq $AlertResourceID} | Select -ExpandProperty Type
        # Adding to table
        $AlertListRow = new-object PSObject
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Name" -Value "$AlertResourceName"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Type" -Value "$AlertResourceType"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Level" -Value "$AlertLevel"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Impact" -Value "$AlertImpact"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Alert" -Value "$AlertName"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Description" -Value "$AlertDescription"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Start" -Value "$AlertStartTime"
        $AlertListRow | Add-Member -MemberType NoteProperty -Name "Update" -Value "$AlertUpdateTime"
        if ($AlertListRow.Name -eq "Qumulo-API")
        {continue}
        $AlertList += $AlertListRow
    }
    # Selecting the storage space alerts
    $StorageAlerts = $AlertList | Where-Object {($_.Description -like "*guest file systems are running out of disk space*")} | select Name, Description | Sort-Object Name
    
    # Load exceptions list
    $exceptionsFile = "C:\Scripts\storageexceptions.csv"
    if (Test-Path $exceptionsFile) {
        $exceptions = @(Import-Csv $exceptionsFile)
    } else {
        $exceptions = @()
    }
    
    if ($StorageAlerts -ne $null)
    {
        $StorageAlerts | Format-Table
        $servers = @($StorageAlerts.Name)
        
        # Load server credentials from file
        $serverCredPath = "C:\Scripts\scriptrunnervcentercreds.xml"
        if (Test-Path $serverCredPath) {
            $creds = Import-Clixml $serverCredPath
            "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Server credentials loaded from file" | Out-File -FilePath $logFile -Append
        } else {
            "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] ERROR: Server credentials file not found at $serverCredPath" | Out-File -FilePath $logFile -Append
            "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Please create the credentials file using: Get-Credential | Export-Clixml -Path '$serverCredPath'" | Out-File -FilePath $logFile -Append
            return
        }
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Found $($servers.Count) servers with storage alerts. Processing all servers automatically..." | Out-File -FilePath $logFile -Append
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Servers to process: $($servers -join ', ')" | Out-File -FilePath $logFile -Append
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Connecting to vSphere..." | Out-File -FilePath $logFile -Append
        Connect-ViServer "vsphere6.aruplab.net"
        
        # Initialize tracking arrays
        $fixedServers = @()
        $already250GBServers = @()
        $failedServers = @()
        
        foreach ($server in $servers)
            {
                $driveletter
                "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Pulling info for $server..." | Out-File -FilePath $logFile -Append
                $vmview = get-vm $server | get-view
                $OS = $vmview.guest.guestFullName
                if ($vmview.guest.guestFullName -notlike "*Windows*")
                {
                    "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] WARNING: $server has $OS installed, and can't be adjusted via Powershell. You must adjust the disk manually." | Out-File -FilePath $logFile -Append
                    continue
                }
                $disks = $vmview.guest.disk
                foreach ($disk in $disks) 
                {
                    $driveletter = $disk.diskpath
                    $driveletter = $driveletter[0]
                    $totalspace = $disk.capacity / 1GB
                    $freespace = $disk.freespace / 1GB
                    $percentfree = [math]::Floor(($freespace/$totalspace)*100)
                    if ($percentfree -le 10)
                    {
                        #####################
                        # Getting VM guest disk info
                        #####################
                        $vmscript = Invoke-VMScript -VM $server -ToolsWaitSecs 120 -GuestCredential $creds -ScriptText {
                        # Creating alphabet array
                        $Alphabet=@()
                        65..90|ForEach{$Alphabet+=[char]$_}
                        # Getting drive letters inside the VM where the drive letter is in the alphabet
                        $DriveLetters = Get-Partition | Where-Object {($Alphabet -match $_.DriveLetter)} | Select -ExpandProperty DriveLetter
                        # Reseting serials
                        $DiskArray = @()
                        # For each drive letter getting the serial number
                        ForEach ($DriveLetter in $DriveLetters)
                        {
                        # Getting disk info
                        $DiskInfo = Get-Partition -DriveLetter $DriveLetter | Get-Disk | Select *
                        $DiskSize = $DiskInfo.Size
                        $DiskUUID = $DiskInfo.SerialNumber
                        # Formatting serial to match in vSphere, if not null
                        IF ($DiskSerial -ne $null)
                        {
                        $DiskSerial = $DiskSerial.Replace("_","").Replace(".","")
                        }
                        # Adding to array
                        $DiskArrayLine = New-Object PSObject
                        $DiskArrayLine | Add-Member -MemberType NoteProperty -Name "DriveLetter" -Value "$DriveLetter"
                        $DiskArrayLine | Add-Member -MemberType NoteProperty -Name "SizeInBytes" -Value "$DiskSize"
                        $DiskArrayLine | Add-Member -MemberType NoteProperty -Name "UUID" -Value "$DiskUUID"
                        $DiskArray += $DiskArrayLine
                        }
                        # Converting Disk Array to CSV data format
                        $DiskArrayData = $DiskArray | ConvertTo-Csv
                        # Returning Disk Array CSV data to main PowerShell script
                        $DiskArrayData
                        # End of invoke-vmscript below
                        }
                        # Pulling the serials from the invoke-vmscript and trimming blank spaces
                        $VMGuestDiskCSVData = $VMscript.ScriptOutput.Trim()
                        # Converting from CSV format
                        $VMGuestDiskData = $VMGuestDiskCSVData | ConvertFrom-Csv
                        # Hostoutput of VM Guest Data
                        $VMGuestDiskData | Format-Table -AutoSize
                        #####################
                        # Building list of VMDKs for the Customer VM
                        #####################
                        # Creating array
                        $VMDKArray = @()
                        # Getting VMDKs for the VM
                        $VMDKs = Get-VM $server | Get-HardDisk
                        # For Each VMDK building table array
                        ForEach($VMDK in $VMDKs)
                        {
                        # Getting VMDK info
                        $VMDKFile = $VMDK.Filename
                        $VMDKName = $VMDK.Name
                        $VMDKControllerKey = $VMDK.ExtensionData.ControllerKey
                        $VMDKUnitNumber = $VMDK.ExtensionData.UnitNumber
                        $VMDKDiskDiskSizeInGB = $VMDK.CapacityGB
                        $VMDKDiskDiskSizeInBytes = $VMDK.ExtensionData.CapacityInBytes
                        # Getting UUID
                        $VMDKUUID = $VMDK.extensiondata.backing.uuid.replace("-","")
                        # Using Controller key to get SCSI bus number
                        $VMDKBus = $VMDK.Parent.Extensiondata.Config.Hardware.Device | Where {$_.Key -eq $VMDKControllerKey}
                        $VMDKBusNumber = $VMDKBus.BusNumber
                        # Creating SCSI ID
                        $VMDKSCSIID = "scsi:"+ $VMDKBusNumber + ":" + $VMDKUnitNumber
                        # Matching VMDK to drive letter based on UUID first, if no serial UUID matching on size in bytes
                        $VMDKDriveLetter = $VMGuestDiskData | Where-Object {$_.UUID -eq $VMDKUUID} | Select -ExpandProperty DriveLetter
                        $VMDKMatchOn = "UUID"
                        IF ($VMDKDriveLetter -eq $null)
                        {
                        $VMDKDriveLetter = $VMGuestDiskData | Where-Object {$_.SizeInBytes -eq $VMDKDiskDiskSizeInBytes} | Select -ExpandProperty DriveLetter
                        $VMDKMatchOn = "Size"
                        }
                        # Matching drive letter for marking SWAP disk
                        IF ($SWAPDriveLetters -match $VMDKDriveLetter)
                        {
                        $VMDKSwap = "true"
                        }
                        ELSE
                        {
                        $VMDKSwap = "false"
                        }
                        # Creating array of VMDKs
                        $VMDKArrayLine = New-Object PSObject
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "VM" -Value $Server
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DiskName" -Value $VMDKName
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DriveLetter" -Value $VMDKDriveLetter
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "MatchedOn" -Value $VMDKMatchOn
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DiskSizeGB" -Value $VMDKDiskDiskSizeInGB
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "SCSIBus" -Value $VMDKBusNumber
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "SCSIUnit" -Value $VMDKUnitNumber
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "SCSIID" -Value $VMDKSCSIID
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DiskUUID" -Value $VMDKUUID
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DiskSizeBytes" -Value $VMDKDiskDiskSizeInBytes
                        $VMDKArrayLine | Add-Member -MemberType NoteProperty -Name "DiskFile" -Value $VMDKFile
                        $VMDKArray += $VMDKArrayLine
                        }
                        $Diskname = $vmdkarray | where driveletter -eq $driveletter | select Diskname
                        $DiskToAdjust = $diskname.diskname
                        $disk = Get-VM $server | Get-HardDisk | where name -eq $DiskToAdjust
                        $currentCapacity = $disk.CapacityGB
                        $targetCapacity = 250
                        
                        if ($currentCapacity -lt $targetCapacity) {
                            "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Expanding $server disk from $currentCapacity GB to $targetCapacity GB..." | Out-File -FilePath $logFile -Append
                            Set-HardDisk -Disk $disk -CapacityGB $targetCapacity -Confirm:$false
                            $expansionNeeded = $true
                        } else {
                            "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] INFO: $server disk is already $currentCapacity GB (>= $targetCapacity GB target). Skipping expansion." | Out-File -FilePath $logFile -Append
                            $expansionNeeded = $false
                        }
                        if ($expansionNeeded) {
                            try {
                                $session = New-PSSession $server -Credential $creds
                                
                                # Check for recovery partition and delete if found
                                "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Checking for recovery partition on $server..." | Out-File -FilePath $logFile -Append
                                Invoke-Command -Session $session -ScriptBlock{
                                    $diskpartScript = @"
list disk
select disk 0
list partition
"@
                                    $diskpartOutput = $diskpartScript | diskpart
                                    
                                    # Find recovery partition number dynamically
                                    $recoveryPartitionLine = $diskpartOutput | Where-Object { $_ -like "*Recovery*" -or $_ -like "*Recovery*" }
                                    
                                    if ($recoveryPartitionLine) {
                                        "Recovery partition found: $recoveryPartitionLine"
                                        
                                        # Extract partition number from the line (usually the first number)
                                        $partitionNumber = ($recoveryPartitionLine -split '\s+')[1]
                                        
                                        if ($partitionNumber -match '^\d+$') {
                                            "Deleting recovery partition $partitionNumber..."
                                            $deleteScript = @"
list disk
select disk 0
list partition
select partition $partitionNumber
delete partition override
"@
                                            $deleteScript | diskpart
                                            "Recovery partition $partitionNumber deleted successfully."
                                        } else {
                                            "Could not determine recovery partition number. Skipping deletion."
                                        }
                                    } else {
                                        "No recovery partition found."
                                    }
                                }
                                
                                # Extend the disk
                                Invoke-Command -Session $session -ScriptBlock{
                                    "rescan", "select volume $Using:driveletter", "extend" | diskpart
                                }   
                                "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] SUCCESS: Successfully expanded $server disk to $targetCapacity GB." | Out-File -FilePath $logFile -Append
                                
                                # Add to fixed servers list
                                $fixedServers += $server
                                
                                Remove-PSSession $session
                            }
                            catch {
                                "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] ERROR: Failed to expand $server disk: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
                                $failedServers += $server
                            }
                        } else {
                            # Server was already 250GB or larger
                            # Check if this is the first time we've seen this server at 250GB+
                            $exceptionExists = $exceptions | Where-Object { $_.ServerName -eq $server }
                            
                            if (-not $exceptionExists) {
                                # First time seeing this server at 250GB+ - include in report and add to exceptions
                                $already250GBServers += $server
                                $exceptions += [PSCustomObject]@{
                                    ServerName = $server
                                    DateAdded = (Get-Date).ToString('yyyy-MM-dd')
                                }
                            }
                            # If already in exceptions, don't add to report (suppressed)
                        }
                    }
                    else 
                    {
                        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] INFO: The $Driveletter drive on $server has $percentfree% free space left" | Out-File -FilePath $logFile -Append    
                    }
            }
        }
        
        # Clean up exceptions list - remove servers no longer in alerts
        $currentAlertServers = $servers
        $updatedExceptions = @()
        foreach ($exception in $exceptions) {
            if ($currentAlertServers -contains $exception.ServerName) {
                $updatedExceptions += $exception
            }
        }
        $exceptions = $updatedExceptions
        
        # Save updated exceptions list
        if ($exceptions.Count -gt 0) {
            $exceptions | Export-Csv -Path $exceptionsFile -NoTypeInformation
        } else {
            if (Test-Path $exceptionsFile) {
                Remove-Item $exceptionsFile
            }
        }
        
        # Determine if email should be sent
        $shouldSendEmail = $false
        if ($fixedServers.Count -gt 0 -or $failedServers.Count -gt 0 -or $already250GBServers.Count -gt 0) {
            $shouldSendEmail = $true
        }
        
        # Send email report
        if ($shouldSendEmail) {
            $style = "<style>
            TABLE {
                border-width 1px; 
                border-style: solid; 
                border-color: black; 
                border-collapse: collapse; 
                font-family: calibri;}
            TD {
                border-width: 1px; 
                padding: 5px; 
                border-style: solid; 
                border-color: black; 
                font-family: calibri}
            TH {
                border-width: 1px; 
                border-style: solid; 
                border-color: black; 
                padding: 5px; 
                background-color: deepskyblue; 
                font-family: calibri;}</style>"
            
            # Create report objects
            $reportData = @()
            
            # Add fixed servers
            foreach ($server in $fixedServers) {
                $reportData += [PSCustomObject]@{
                    Server = $server
                    Status = "Fixed - Expanded to 250GB"
                    Action = "Disk expanded and recovery partition removed"
                }
            }
            
            # Add already 250GB servers
            foreach ($server in $already250GBServers) {
                $reportData += [PSCustomObject]@{
                    Server = $server
                    Status = "Already 250GB+"
                    Action = "No action taken (added to exceptions list)"
                }
            }
            
            # Add failed servers
            foreach ($server in $failedServers) {
                $reportData += [PSCustomObject]@{
                    Server = $server
                    Status = "Failed"
                    Action = "Manual intervention required"
                }
            }
            
            if ($reportData.Count -gt 0) {
                $table = $reportData | ConvertTo-Html -As Table -Head $style
                $recipients = "email@example.com"
                [string[]]$To = $recipients.Split(',')
                $emailinfo = @{
                    Subject = "Storage Alert Resolution Report - $(Get-Date -Format 'yyyy-MM-dd')"
                    Body = "                   
                    $table
                    
                    <p style=`"font-family:Arial; font-size: 12pt;`">Any servers that have a 250GB disk need to be investigated.</p>
                    
                    <p style=`"font-family:Arial; font-size: 12pt;`">There are currently $($exceptions.Count) servers in the exceptions list.</p>"
                    To = $To
                    From = "email@example.com"
                    SMTPServer = "examplesmtpaddress"
                    Port = 25
                    BodyAsHTML = $true
                }
                Send-MailMessage @emailinfo
                "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Email report sent successfully." | Out-File -FilePath $logFile -Append
            }
        }
    }
    else 
    {
        "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] There are no active storage space alerts at the moment." | Out-File -FilePath $logFile -Append
    }
    
    "[$((Get-Date).ToString('yyyy-MM-dd hh:mm:ss tt'))] Check-Svrops script completed" | Out-File -FilePath $logFile -Append
}