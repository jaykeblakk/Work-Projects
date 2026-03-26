function Check-RubrikSLA()
{
    Connect-VIServer -Server vcenterurl.example.com
    $rubriktoken = get-content C:\Scripts\rubriktoken.txt
    Connect-Rubrik -Server rubrikurl.example.com -Credential $rubriktoken
    $SLAArray = @()
    $rubrikvms = get-rubrikvm | select Name, @{Name = "SLA"; e= "effectiveSlaDomainName"}
    $exclusions = get-content "path\to\exclusions.csv"
    foreach ($vm in $rubrikvms)
    {
        if(($vm.SLA -eq "Unprotected") -and ($vm.name -notin $exclusions))
        {
            $decommed = Get-VM -Location "DecommissionedVMs"
            if ($vm.name -in $decommed.name)
            {
                continue
            }
            else 
            {
                $SLAArray += $vm
            }
        }
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
    $SLATable = $SLAArray | ConvertTo-Html -As Table -Head $style
    $recipients = "email@example.com"
    [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "Servers without SLA"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">There are servers that do not have an SLA assigned in Rubrik and are not scheduled to be decommed.</p>
            <p style=`"font-family:Arial; font-size: 12pt;`">Please review the VM's below and assign them the proper SLA in Rubrik to ensure proper backups.</p>
            
            $SLATable"
            To = $To
            From = "email@example.com"
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true 
        }
Send-MailMessage @emailinfo
}