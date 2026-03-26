function Check-VMwareTools()
{
    $creds = Import-clixml -Path C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $excludelist = Import-Csv "path\to\exclusions.csv" -Header Servers
    $excludelist = $excludelist.servers
    $vms = Get-VM
    $vmsarray = @()
    foreach ($vm in $vms)
    {
        if ($vm.extensiondata.guest.toolsstatus -like "*notinstalled*" -and $vm.folder.name -ne "DecommissionedVMs" -and $vm.powerstate -eq "PoweredOn" -and $vm.Name -notin $excludelist -and $vm.Name -notlike "excludevmname*")
        {
            $vmname = $vm | select Name
            $row = "" | select "VMName"
            $row.VMName = $vmname.Name
            $vmsarray += $row
        }
    }
    if ($vmsarray.count -eq 0)
    {
        $datetime = get-date -UFormat '%D %r'
        $log = "All servers are running VMware Tools as of $datetime"
        out-file -FilePath C:\Scripts\Logs\Check-VMwareTools.txt -InputObject $log
        exit
    }
    else 
    {
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
        $vmstable = $vmsarray | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
            $emailinfo = @{
                Subject = "VMware Tools Failures"
                Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers are reporting that VMware Tools is not currently installed on them:</p>
                
                $vmstable
                
                <p style=`"font-family:Arial; font-size: 12pt;`">It is recommended to install VMware Tools as soon as possible so that vSphere can communicate with the servers properly.</p>
                <p style=`"font-family:Arial; font-size: 12pt;`">If a server on this list doesn't need VMware Tools installed on it, then remember to add it to the exclusions list for future checks.</p>"
                From = "email@example.com"
                To = $To
                SMTPServer = "examplesmtpaddress"
                Port = 25
                BodyAsHTML = $true 
            }
        Send-MailMessage @emailinfo
    }
}