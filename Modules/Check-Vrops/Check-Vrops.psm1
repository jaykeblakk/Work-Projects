function Check-Vrops()
{
    ################################################
    # AUTHENTICATION
    ################################################
    # Configure the variables below for vROPs
    ################################################
    $vROPsServer = "vropsurl.example.com"
    $vROPsCredentials = Get-Credential "@example.com" -Message "Enter your vROPs credentials"
    $vROPSUser = $vROPsCredentials.UserName
    $vROPsCredentials.Password | ConvertFrom-SecureString
    $vROPsPassword = $vROPsCredentials.GetNetworkCredential().password
    ################################################
    # Nothing to configure below this line 
    ################################################
    # Adding certificate exception to prevent API errors
    ################################################
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

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
        $AlertList += $AlertListRow
    }
    # Selecting the storage space alerts
    $StorageAlerts = $AlertList | Where-Object {$_.Description -like "*guest file systems are running out of disk space*"} | select Name, Description | Sort-Object Name
    cls
    Write-Host "Below are the VDI's that are low on storage space as of today:"
    if ($StorageAlerts -ne $null)
    {
        $StorageAlerts | Format-Table
        $vdis = $storagealerts.Name
        $fixchoice = Read-Host "Fix the alerts now? y/n"
        if ($fixchoice -eq 'y')
        {
            $creds = Get-Credential -Message "Please enter your DA credentials"
            Write-Host "Connecting to vSphere..."
            Connect-ViServer "vcenterurl.example.com"
            foreach ($vdi in $vdis)
            {
                $vmview = get-vm $vdi | get-view
                $totalspace = $vmview.guest.disk.capacity / 1GB
                $freespace = $vmview.guest.disk.freespace / 1GB
                $percentfree = [math]::Floor(($freespace/$totalspace)*100)
                if ($percentfree -lt 15)
                {
                    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Adding 20GB of space to $vdi..."
                    $disk = Get-VM $vdi | Get-HardDisk
                    $newcapacity = $disk.capacityGB + 20
                    Set-HardDisk -Disk $disk -CapacityGB $newcapacity -Confirm:$false
                    $session = New-PSSession $vdi -Credential $creds
                    Invoke-Command -Session $session -ScriptBlock{
                        "rescan", "select volume 0", "extend", "select volume 1", "extend", "select volume 2", "extend" | diskpart
                    }
                    Write-Host -ForegroundColor Green -BackgroundColor Black "Increased $vdi storage space by 20GB."
                }
                else 
                {
                    Write-Host -ForegroundColor Yellow -BackgroundColor Black "The VDI $vdi has already had it's disk cleaned up. It is currently at $percentfree% disk usage."    
                }
            }
        }
    }
    else 
    {
        Write-Host "There are no active storage space alerts at the moment."
    }
}