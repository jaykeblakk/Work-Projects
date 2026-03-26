function Check-VMwareTools()
{
    $creds = Import-clixml -Path C:\Scripts\vspherecreds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $excludelist = Import-Csv '\\path\to\excludelist.csv' -Header Servers
    $excludelist = $excludelist.servers
    $vms = Get-VM
    $vmlist = foreach ($vm in $vms)
    {
        if ($vm.extensiondata.guest.toolsstatus -like "*notinstalled*" -and $vm.folder.name -ne "DecommissionedVMs" -and $vm.powerstate -eq "PoweredOn" -and $vm.Name -notin $excludelist -and $vm.Name -notlike "Example VM Name*")
        {
            $vm | select Name
        }
    }
    if ($vmlist -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $log = "All servers are running VMware Tools as of $datetime"
        out-file -FilePath C:\Scripts\Logs\Check-VMwareTools.txt -InputObject $log
        exit
    }
    else 
    {
        $servernames = $vmlist.name
        $servernamelist
        foreach ($servername in $servernames)
        {
            $servernamelist += "$servername`r`t"
        }
        $emailinfo = @{
            Subject = "VMware Tools Failures"
            Body = "The following servers are reporting that VMware Tools is not currently installed on them:
            
            $servernamelist

            It is recommended to install VMware Tools as soon as possible so that vCenter can communicate with the servers properly.

            If a server on this list doesn't need VMware Tools installed on it, then remember to add it to the exclusions list for future checks."
            To = "email@example.com"
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
        }
        Send-MailMessage @emailinfo
    }
}