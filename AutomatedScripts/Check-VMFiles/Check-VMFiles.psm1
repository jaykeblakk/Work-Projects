function Check-VMFiles()
{
    $viserver = $global:DefaultVIServer
    if ($viserver -eq $null)
    {
        Connect-ViServer vcenterurl.example.com
    }
    $exceptions = get-content "path\to\exclusions.csv"
    $vmlist = @()
    $vms = get-vm
    foreach ($vm in $vms)
    {
        if (($vm.name -like "*vmname*") -or ($vm.name -in $exceptions))
        {
            continue
        }
        $vmname = $vm.name
        $path = $vm.extensiondata.summary.config.vmpathname
        $pathname = [regex]::split($path,"_\d+")
        $pathname = $pathname.split("/")[-1]
        $pathname = $pathname -split ".vmx"
        if ($pathname -notlike $vmname)
        {
            $vmobject = New-Object -TypeName PSObject
            $vmobject | Add-Member -Name 'VM Name' -MemberType NoteProperty -Value $vmname
            $vmobject | Add-Member -Name 'Filename' -MemberType NoteProperty -Value $pathname[0]
            $vmlist += $vmobject
        }
    }
    if ($vmlist.count -eq 0)
    {
        $datetime = get-date -UFormat '%D %r'
        $log = "All server vmdk files are the same as their server names as of $datetime"
        out-file -FilePath C:\Scripts\Logs\Check-VMFiles.txt -InputObject $log
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
        $vmstable = $vmlist | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
            $emailinfo = @{
                Subject = "VMDK Mismatch"
                Body = "<p style=`"font-family:Arial; font-size: 12pt;`">These servers have names that are different from their VMDK filenames:</p>
                
                $vmstable
                
                <p style=`"font-family:Arial; font-size: 12pt;`">Check the name to make sure it is correct, and then vMotion the VM to a different datastore to resolve this issue.</p>"
                From = "email@example.com"
                To = $To
                SMTPServer = "examplesmtpaddress"
                Port = 25
                BodyAsHTML = $true 
            }
        Send-MailMessage @emailinfo
    }
}