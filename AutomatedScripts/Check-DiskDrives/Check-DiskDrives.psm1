function Check-DiskDrives()
{
    $creds = Import-clixml -Path C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $machines = get-cluster cluster1, cluster2 | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"} | Get-CDDrive | where {($_.isopath -ne $null)} | select Parent, IsoPath
    if ($machines -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $runtime = "Script run on $datetime. No servers were scheduled to be removed."
        out-file -FilePath C:\Scripts\Logs\Check-DiskDrives.txt -InputObject $runtime
        exit
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
        $table = $machines | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Servers with ISO connections"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers still have active disk drive connections that must be removed:</p>
            
            $table
            
            <p style=`"font-family:Arial; font-size: 12pt;`">Please ensure that the disk drive is not still connected, and change the type of media from Datstore ISO to Client Device</p>
            <p style=`"font-family:Arial; font-size: 12pt;`">Note: for Linux machines, you must SSH into the machine and then run the eject cdrom command before disconnecting the drive</p>
            <p style=`"font-family:Arial; font-size: 12pt;`">For Windows machines, log in to the machine, eject the DVD drive, and then disconnect it from the machine.</p>"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
        Send-MailMessage @emailinfo
}