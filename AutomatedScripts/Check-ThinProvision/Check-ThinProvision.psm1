function Check-ThinProvision()
{
    $creds = Import-clixml -Path C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    $exceptions = get-content "path\to\exclusions.csv"
    $vms = get-vm | where name -notlike "*excludevmname*" | get-view
    $vmlist = @()
    foreach ($vm in $vms)
    {
        if ($vm.name -in $exceptions)
        {
            continue
        }
        $number = 1
        $thinprovision = $null
        $drivestates = $vm.config.hardware.device.backing.thinprovisioned # This particular property is a true/false boolean of whether or not a disk is thin provisioned.
        foreach ($drive in $drivestates)
        {
            if ($drive -eq $False)
            {
                $thinprovision += "Drive $number, "
                $number++
            }
            else 
            {
                $number++
                continue
            }
        }
        if ($thinprovision -ne $null)
        {
            $thinprovision = $thinprovision -replace ".{2}$" # This line removes the last 2 characters of the string. Basically removes the comma and space at the end so that the list looks nicer
            $vmname = $vm.name
            $vmobject = New-Object -TypeName PSObject
            $vmobject | Add-Member -Name 'VM Name' -MemberType NoteProperty -Value $vmname
            $vmobject | Add-Member -Name 'Thick Provisioned Disks' -MemberType NoteProperty -Value $thinprovision
            $vmlist += $vmobject
        }
    }
    if ($vmlist -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $runtime = "Script run on $datetime. No servers found with thin disks."
        out-file -FilePath C:\Scripts\Logs\Check-ThinProvision.txt -InputObject $runtime
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
        $table = $vmlist | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Servers with Thick Disks"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers have disks that are not Thin Provisioned:</p>
            
            $table
            
            <p style=`"font-family:Arial; font-size: 12pt;`">Check the drive to see if it is full. If so, add extra space. Then migrate the VM and set the disks to be Thin Provisioned.</p>"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
        Send-MailMessage @emailinfo
}