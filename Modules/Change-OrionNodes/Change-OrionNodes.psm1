function Change-OrionNodes()
{
    Import-Module SwisPowershell
    Import-Module PowerOrion
    Connect-VIServer vcenterurl.example.com
    $swis = Connect-Swis -hostname orionurl.example.com -Credential (get-credential -Message "Please log in to Orion")
    $servers = get-cluster Example Cluster Name 1 | get-vm | select *
    foreach($server in $servers)
    {
        $IP = $server.extensiondata.guest.ipaddress
        $name = $server.name
        try {
            $node = get-orionnode -SwisConnection $swis -IPAddress $IP -ErrorAction Stop
            $properties = @{
                ObjectSubType="Example Object Subtype"
            }
            Set-SwisObject $swis -uri $node.uri -Properties $properties
        }
        catch {
            "$name not in Orion"
        }
    }
}