function Check-ServerLocations()
{
    $creds = Import-clixml -Path C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds 
    $devhosts = Get-VM | where VMHost -like "*devhost*"
    $prodhosts = Get-VM | where {$_.VMhost -like "*prodhost*" -and $_.Folder.name -ne "DecommissionedVMs"}
    $exceptions = Import-CSV -Path "path\to\exceptions.csv" -Header "Servers"
    $exceptions = $exceptions.servers
    $devarray = @()
    $prodarray = @()
    foreach ($vm in $devhosts)
    {
        $networkname = Get-NetworkAdapter -VM $vm | select networkname
        $networkname = $networkname.networkname
        # The reason we exclude these subnets is because we are only looking for servers that are sitting on PROD-7. PROD-1,2, and 3 are all unknown as to what is production or not.
        if ($networkname -like "*PROD*" -and $networkname -notlike "*PROD-1*" -and $networkname -notlike "*PROD-2*" -and $networkname -notlike "*PROD-3*")
        {
            if ($vm.name -in $exceptions)
            {
                continue
            }
            $vmname = $vm.name
            $row = "" | select VMName, NetworkName
            $row.VMname = $vmname
            $row.NetworkName = $networkname
            $devarray += $row
        }
    }  
    foreach ($prodhost in $prodhosts)
    {
        if ($prodhost -in $devnames)
        {
            $devname = $prodhost.name
            $row = "" | select Name, Host
            $row.Name = $devname
            $row.Host = $prodhost.VMhost
            $prodarray += $row
        }
    }
    if ($prodarray.count -eq 0 -and $devarray.count -eq 0)
    {
        $datetime = get-date -UFormat '%D %r'
        $log = "All servers are running in the proper place as of $datetime"
        out-file -FilePath C:\Scripts\Logs\Check-ServerLocations.txt -InputObject $log
        exit
    }
    elseif ($prodarray.count -eq 0 -and $devarray.count -ne 0)
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
        $devtable = $devarray | ConvertTo-Html -As Table -Head $style
        $emailinfo = @{
            Subject = "Misplaced Servers"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers are on prod networks but hosted on development resources:</p>
            
            $devtable
    
            <p style=`"font-family:Arial; font-size: 12pt;`">Note: System.Object[] means that the server has multiple NICs installed, and at least one of them is on a production subnet.</p>
            
            <p style=`"font-family:Arial; font-size: 12pt;`">There are no servers currently in the Non Prod OU that are running on Production hardware.</p>"
            To = "coby.c.carter@aruplab.com"
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
    }
    elseif ($prodarray.count -ne 0 -and $devarray.count -eq 0)
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
        $prodtable = $prodarray | convertTo-Html -As Table -Head $style
        $emailinfo = @{
            Subject = "Misplaced Servers"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers are in the Non Prod OU but hosted on production hardware:</p>
            
            $prodtable
            
            <p style=`"font-family:Arial; font-size: 12pt;`">There are no servers currently on production networks but running on development hardware.</p>"
            To = "email@example.com"
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
    }
    elseif ($prodarray.count -ne 0 -and $devarray.count -ne 0)
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
        $devtable = $devarray | ConvertTo-Html -As Table -Head $style
        $prodtable = $prodarray | convertTo-Html -As Table -Head $style
        $emailinfo = @{
            Subject = "Misplaced Servers"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The following servers are on prod networks but hosted on development hardware:</p>
            
            $devtable

            <p style=`"font-family:Arial; font-size: 12pt;`">Note: System.Object[] means that the server has multiple NICs installed, and at least one of them is on a production subnet.</p>
            
            <p style=`"font-family:Arial; font-size: 12pt;`">The following servers are in the Non Prod OU but hosted on Production hardware:</p>

    $prodtable
    "
            To = "email@example.com"
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true
        }
    }
    Send-MailMessage @emailinfo
}