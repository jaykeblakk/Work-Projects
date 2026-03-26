<#
.SYNOPSIS
    Retrieves network configuration details for SQL cluster servers and their cluster objects.

.DESCRIPTION
    This script collects comprehensive network information for both SQL servers and their associated 
    cluster objects. It gathers IP addresses, gateway information, subnet masks, and DNS settings 
    from vSphere for servers, while pulling network details from Infoblox for cluster objects.

.NOTES
    Author: Coby Carter
    Last Updated: 11/22/2024
    Change History:
    11/22/2024 - Initial script creation

.PARAMETER servers
    Array of SQL server names to check.

.PARAMETER clusterobjects
    Array of cluster object names to verify.

.EXAMPLE
    Check-SQLCluster -servers "SQL01","SQL02" -clusterobjects "SQLCLU01","SQLCLU02"

    Retrieves and displays network configuration details for the specified SQL servers and their 
    associated cluster objects, including IP addresses, gateways, subnet masks, and DNS settings.
#>
function Check-SQLCluster()
{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false)]
    [string[]]$servers,
    
    [Parameter(Mandatory=$false)]
    [string[]]$clusterobjects
    )
    Connect-ViServer vcenterurl.example.com
    if ($servers -eq $null)
    {
        $servers = @()
        $servers = Read-Host -Prompt "Server Names"
    }
    if ($clusterobjects -eq $null)
    {
        $clusterobjects = @()
        $clusterobjects = Read-Host -Prompt "Cluster Object Names"
    }
    $servers = $servers.replace(' ','')
    $servers = $servers.split(',')
    $clusterobjects = $clusterobjects.replace(' ','')
    $clusterobjects = $clusterobjects.split(',')
    foreach ($server in $servers)
    {
        $vm = Get-VM -Name "$server"
        $subnetmask = @()
        $row = "" | Select Name,IP,Gateway,Subnetmask,DNS
        $row.Name = $vm.Name
        $row.IP = [string]::Join(',',$vm.Guest.IPAddress[0])
        $row.Gateway = $vm.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute.Gateway.IpAddress | where {$_ -ne $null}
        $subnetip = $vm.Guest.IPAddress[0] -replace "[0-9]$|[1-9][0-9]$|1[0-9][0-9]$|2[0-4][0-9]$|25[0-5]$", "0" | select -uniq
        foreach ($iproute in $vm.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute) {
            if ($subnetip -like $iproute.Network) {
                $subnetmask += $iproute.Network + "/" + $iproute.PrefixLength
            }
        }
        $row.Subnetmask = [string]::Join(',',($subnetmask))
        $row.DNS = [string]::Join(',',($vm.ExtensionData.Guest.IpStack.DnsConfig.IpAddress))
        $row
    }
    foreach ($object in $clusterobjects)
    {
        $objectrow = "" | Select Name, IP, Subnetmask
        $object = $object.toLower()
        $filter = ('name=' + $object + '.example.com')
        $ibinfo = Get-IBObject 'record:a' -Filters $filter -returnallfields
        $objectrow.name = $ibinfo.name
        $objectrow.IP = $ibinfo.ipv4addr
        $network = get-IBObject -type network -Filters 'network=0.0.0.0'
        $objectrow.Subnetmask = $network.network
        $objectrow
    }
}