function Stage-Remediations()
{
    $creds = Import-clixml -Path C:\Scripts\creds.xml
    Connect-VIServer vcenterurl.example.com -Credential $creds
    Connect-VIServer horizonurl.example.com -Credential $creds
    $hosts = Get-VMHost
    foreach ($vmhost in $hosts)
    {
        try 
        {
        $vmhost | Copy-Patch
        }
        catch
        {
            $errorstring = "$vmhost was unable to successfully stage the patches`n"
            $errorstring | write-output | Out-File C:\Scripts\Logs\hoststaging\$vmhost.txt
        }
    }
    $recipients = "email@example.com"
    [string[]]$To = $recipients.Split(',')
        $emailinfo = @{
            Subject = "ESXi Host Remediation Staged"
            Body = "<p style=`"font-family:Arial; font-size: 12pt;`">The monthly staging of ESXi host remediation patches has finished. Please perform the upgrades as soon as possible.</p>"
            From = "email@example.com"
            To = $To
            SMTPServer = "examplesmtpaddress"
            Port = 25
            BodyAsHTML = $true 
        }
    Send-MailMessage @emailinfo
}