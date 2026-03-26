function Check-RubrikMounts()
{
    $rubriktoken = get-content C:\Scripts\rubriktoken.txt
    Connect-Rubrik -Server rubrikurl.example.com -Credential $rubriktoken
    $mounts = Get-RubrikMount
    if ($mounts.datastorename -eq $null)
    {
        $datetime = get-date -UFormat '%D %r'
        $log = "No live mounts found in Rubrik as of $datetime"
        out-file -FilePath C:\Scripts\Logs\Check-RubrikMounts.txt -InputObject $log
        exit
    }
    foreach ($mount in $mounts)
    {
            $dsname = $mount.datastorename
            $dsid = $mount.id
            $row = "" | select DataStoreName, DatastoreID
            $row.DatastoreName = $dsname
            $row.DataStoreID = $dsid
            $mountsarray += $row
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
        $mountstable = $mountsarray | ConvertTo-Html -As Table -Head $style
        $recipients = "email@example.com"
        [string[]]$To = $recipients.Split(',')
            $emailinfo = @{
                Subject = "Rubrik Mounts"
                Body = "<p style=`"font-family:Arial; font-size: 12pt;`">Some Rubrik Live Mounts have not been cleaned up from when they were created.</p>
                <p style=`"font-family:Arial; font-size: 12pt;`">Below is the list of mounts. Please migrate VM's if they are on the mounts and then delete the mounts ASAP.</p>
                
                $mountstable"
                To = $To
                From = "email@example.com"
                SMTPServer = "examplesmtpaddress"
                Port = 25
                BodyAsHTML = $true 
            }
    Send-MailMessage @emailinfo
}