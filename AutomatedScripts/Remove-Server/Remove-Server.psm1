function Remove-Server()
{
    $creds = Import-clixml -Path C:\Scripts\scriptercreds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $date = get-date -Format MM/dd/yyyy
    $decommedvms = get-vm -Location "DecommissionedVMs" | where notes -like "*$date*"
    $vms = $decommedvms | select Name, @{Name="Operating System";Expression={$_.extensiondata.guest.guestfullname}}
    if ($decommedvms -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $runtime = "Script run on $datetime. No servers were scheduled to be removed."
        out-file -FilePath C:\Scripts\Logs\Remove-Server.txt -InputObject $runtime
        exit
    }
    else 
    {
        foreach ($vm in $decommedvms)
        {
            Stop-VM -VM $vm -RunAsync -Confirm:$false
            $power = $null
            while ($power -ne 'PoweredOff')
            {
                $power = get-vm $vm.name | select powerstate
                $power = $power.powerstate
            }
            $vmname = $vm.name
            Remove-VM -VM $vm -DeletePermanently -RunAsync -Confirm:$false
            $swis = Connect-Swis -Hostname orion.aruplab.net -Credential $creds
            $nodeID = Get-OrionNodeID -Node $vmname -SwisConnection $swis
            Remove-OrionNode -SwisConnection $swis -NodeID $nodeID -Confirm:$false
            $vmname = $vmname.toLower()
            $filter = ('name=' + $vmname + '.example.com')
            $HostEntry = Get-IBObject 'record:host' -Filters $filter -ReturnAllFields
            $AEntry = Get-IBObject 'record:a' -Filters $filter -ReturnAllFields
            $ptrfilter = ('ptrdname=' + $vmname + '.example.com')
            $PTREntry = Get-IBObject 'record:ptr' -Filters $ptrfilter
            Remove-IBObject $HostEntry._ref -Confirm:$false
            Remove-IBObject $PTREntry._ref -Confirm:$false
            Remove-IBObject $AEntry._ref -Confirm:$false
        }
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
        $table = $vms | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Deleted Servers"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">These were the servers scheduled to be deleted today:</p>
            
            $table
            
            <p style=`"font-family:Arial; font-size: 12pt;`">They have been deleted from vSphere, and their entries in Orion and Infoblox have been deleted.</p>
            
            <p style=`"font-family:Arial; font-size: 12pt;`">IMPORTANT NOTE: You will need to delete their computer objects from AD.</p>

            <p>If any of these servers are needed, their backups can be located in Rubrik.</p>"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
        Send-MailMessage @emailinfo   
    }
}