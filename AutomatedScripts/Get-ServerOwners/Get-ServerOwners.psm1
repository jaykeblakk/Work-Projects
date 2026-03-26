function Get-ServerOwners()
{
    $vropscreds = import-clixml C:\scripts\vropscreds.xml
    $creds = import-clixml C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $u = $vropscreds.username
    $x = $vropscreds.getnetworkcredential().password
    $json = @{
    "username" = "$u"
    "authSource" = "example.com"
    "password" = "$x"} | convertto-json
    $token = Invoke-RestMethod -Method POST -Uri "https://vropsurl.example.com/suite-api/api/auth/token/acquire" -body $json -contenttype application/json
    $token = $token.'auth-token'.token
    $header = @{
        "Authorization" = "vRealizeOpsToken $token"
        "Accept" = "application/json"
    }
    $alertquery = @{
        "alert-query" = @{
            "alertdefinitionname" = "AlertDefinition-VMWARE-GuestOutOfDiskSpace"
        }
    } | convertto-json
    $alerts = invoke-restmethod -Method POST -Uri "https://vropsurl.example.com/suite-api/api/alerts/query" -Headers $header -Body $alertquery -ContentType application/json
    $alertsobjects = $alerts.alerts
    $resources = $alertsobjects | where {($_.alertdefinitionname -like "*guest file systems are running out of disk space*") -and ($_.status -eq "ACTIVE")} | select resourceID
    $resources = $resources.resourceID
    $vmlist = @()
    foreach ($resource in $resources)
    {
        $vm = invoke-restmethod -Method GET -uri "https://vropsurl.example.com/suite-api/api/resources/$resource" -Headers $header
        $vmlist += $vm.resourceKey.name
    }
    $ownerlist = foreach ($vm in $vmlist) {get-annotation $vm | where Name -eq "System Owner"}
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
        $table = $ownerlist | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Full Disk Server Owners"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers have disks that are full:</p>
            
            $table
            
            <p style=`"font-family:Arial; font-size: 12pt;`">Check which disk is full. If it is the C drive, make sure to reach out to the server owner and request that they move the data to a different drive.</p>"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
        Send-MailMessage @emailinfo
}