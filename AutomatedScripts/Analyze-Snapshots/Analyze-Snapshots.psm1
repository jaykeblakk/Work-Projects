function Analyze-Snapshots()
{
    $creds = Import-clixml -Path C:\Scripts\credentials.xml
    Connect-VIServer vcenter1.example.com -Credential $creds
    Connect-VIServer vcenter2.example.com -Credential $creds
    $snapshots = get-vm | get-snapshot | where {($_.description -notlike "*BACKUP*") -and ($_.VM -notlike "*template*") -and 
    ($_.description -notlike "*base-snapshot*") -and ($_.VM -notlike "*GOLD*") -and ($_.VM -notlike "test-*") -and ($_.VM -notlike "*TEMPLATE*")} | 
    sort-object created | select VM, Created, Description
    $oldsnapshots = @()
    $oldsnapshots = foreach ($snapshot in $snapshots)
    {
        $snapshotdate = $snapshot.created
        $today = get-date
        $timepassed = $today - $snapshotdate
        if ($timepassed.days -ge 3)
        {
            $snapshot
        }
    }
    if ($snapshots -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $runtime = "No snapshots found as of $datetime."
        out-file -FilePath C:\Scripts\Logs\Analyze-Snapshots.txt -InputObject $runtime
        exit
    }
    elseif ($oldsnapshots -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $runtime = "There were snapshots found on $datetime, but none older than 7 days."
        out-file -FilePath C:\Scripts\Logs\Analyze-Snapshots.txt -InputObject $runtime
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
        $snapshotstable = $oldsnapshots | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Server Snapshots"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">Below is a list of all snapshots currently found in vCenter that are 3 days old or older:</p>
            $snapshotstable
            <p style=`"font-family:Arial; font-size: 12pt;`">It is recommended to delete the snapshots as soon as possible to clear up resources.</p>
            <p style=`"font-family:Arial; font-size: 12pt;`">Contact the owners of the servers to verify that the snapshots are still needed.</p>"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true 
        }
        Send-MailMessage @emailinfo
    }
}